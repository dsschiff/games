"""Run one Windows command and its descendants inside a task-owned Job Object."""
from __future__ import annotations

import ctypes
from ctypes import wintypes
import json
import os
import subprocess
import sys
import time

_GATE = """
import json, subprocess, sys
argv = json.loads(sys.stdin.buffer.readline())
raise SystemExit(subprocess.run(argv, stdin=subprocess.DEVNULL,
                               creationflags=subprocess.CREATE_NO_WINDOW).returncode)
"""


class _Limits(ctypes.Structure):
    _fields_ = [("per_process_time", ctypes.c_longlong), ("per_job_time", ctypes.c_longlong),
                ("flags", wintypes.DWORD), ("minimum_working", ctypes.c_size_t),
                ("maximum_working", ctypes.c_size_t), ("active_limit", wintypes.DWORD),
                ("affinity", ctypes.c_size_t), ("priority", wintypes.DWORD),
                ("scheduling", wintypes.DWORD)]


class _Io(ctypes.Structure):
    _fields_ = [(name, ctypes.c_ulonglong) for name in
                ("read_ops", "write_ops", "other_ops", "read_bytes", "write_bytes", "other_bytes")]


class _ExtendedLimits(ctypes.Structure):
    _fields_ = [("basic", _Limits), ("io", _Io), ("process_memory", ctypes.c_size_t),
                ("job_memory", ctypes.c_size_t), ("peak_process_memory", ctypes.c_size_t),
                ("peak_job_memory", ctypes.c_size_t)]


class _Accounting(ctypes.Structure):
    _fields_ = [(name, ctypes.c_longlong) for name in
                ("user_time", "kernel_time", "period_user_time", "period_kernel_time")]
    _fields_ += [(name, wintypes.DWORD) for name in
                 ("page_faults", "total_processes", "active_processes", "terminated_processes")]


class _Job:
    def __init__(self):
        self.api = ctypes.WinDLL("kernel32", use_last_error=True)
        self.api.CreateJobObjectW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR]
        self.api.CreateJobObjectW.restype = wintypes.HANDLE
        self.api.SetInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int,
                                                     ctypes.c_void_p, wintypes.DWORD]
        self.api.SetInformationJobObject.restype = wintypes.BOOL
        self.api.AssignProcessToJobObject.argtypes = [wintypes.HANDLE, wintypes.HANDLE]
        self.api.AssignProcessToJobObject.restype = wintypes.BOOL
        self.api.QueryInformationJobObject.argtypes = [wintypes.HANDLE, ctypes.c_int,
                                                       ctypes.c_void_p, wintypes.DWORD,
                                                       ctypes.c_void_p]
        self.api.QueryInformationJobObject.restype = wintypes.BOOL
        self.api.TerminateJobObject.argtypes = [wintypes.HANDLE, wintypes.UINT]
        self.api.TerminateJobObject.restype = wintypes.BOOL
        self.api.CloseHandle.argtypes = [wintypes.HANDLE]
        self.api.CloseHandle.restype = wintypes.BOOL
        self.handle = self.api.CreateJobObjectW(None, None)
        if not self.handle:
            raise ctypes.WinError(ctypes.get_last_error())
        limits = _ExtendedLimits()
        limits.basic.flags = 0x2000  # Kill on last Job-handle close; no breakaway.
        if not self.api.SetInformationJobObject(self.handle, 9, ctypes.byref(limits),
                                                ctypes.sizeof(limits)):
            error = ctypes.WinError(ctypes.get_last_error())
            self.close()
            raise error

    def assign(self, process):
        # The exact CPython-owned process handle avoids resolving a recycled PID.
        if not self.api.AssignProcessToJobObject(self.handle, int(process._handle)):
            raise ctypes.WinError(ctypes.get_last_error())

    def accounting(self):
        value = _Accounting()
        if not self.api.QueryInformationJobObject(self.handle, 1, ctypes.byref(value),
                                                  ctypes.sizeof(value), None):
            raise ctypes.WinError(ctypes.get_last_error())
        return {"total_processes": int(value.total_processes),
                "active_processes": int(value.active_processes)}

    def terminate(self):
        if not self.api.TerminateJobObject(self.handle, 124):
            raise ctypes.WinError(ctypes.get_last_error())

    def close(self):
        if self.handle:
            self.api.CloseHandle(self.handle)
            self.handle = None


def run_owned(argv, *, env, log, stderr_log=None, timeout=900, cleanup_timeout=30):
    """Drain the owned tree or explicitly report uncertainty before cleanup.

    Isolated Python blocks on stdin before spawning anything. No argv is sent
    before Job assignment. No process-name search or unrelated kill is used.
    """
    if os.name != "nt":
        raise ValueError("Owned Gradle process containment currently requires Windows")
    outcome = {"exit_code": None, "timed_out": False, "process_tree_stopped": True,
               "target_admitted": False}
    job = None
    process = None
    assigned = False
    try:
        job = _Job()
        process = subprocess.Popen([sys.executable, "-I", "-S", "-u", "-c", _GATE],
                                   stdin=subprocess.PIPE, stdout=log,
                                   stderr=stderr_log if stderr_log is not None else subprocess.STDOUT,
                                   env=env, creationflags=subprocess.CREATE_NO_WINDOW)
        outcome.update(wrapper_pid=process.pid, process_tree_stopped=False)
        job.assign(process)
        assigned = True
        process.stdin.write((json.dumps(argv) + "\n").encode("utf-8"))
        process.stdin.flush()
        process.stdin.close()
        outcome["target_admitted"] = True
        try:
            outcome["exit_code"] = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            outcome["timed_out"] = True
    except (OSError, ValueError) as error:
        outcome["process_error"] = str(error)
    finally:
        try:
            if assigned:
                before = job.accounting()
                outcome["before_cleanup"] = before
                if before["active_processes"]:
                    job.terminate()
                deadline = time.monotonic() + cleanup_timeout
                while True:
                    after = job.accounting()
                    if not after["active_processes"] or time.monotonic() >= deadline:
                        break
                    time.sleep(.05)
                outcome["after_cleanup"] = after
                outcome["process_tree_stopped"] = after["active_processes"] == 0
            elif process is not None:
                # No command was sent, so this blocked wrapper has no target children.
                process.kill()
            if process is not None:
                process.wait(timeout=cleanup_timeout)
                if not assigned:
                    outcome["process_tree_stopped"] = True
        except (OSError, subprocess.SubprocessError) as error:
            outcome["process_tree_stopped"] = False
            outcome["cleanup_error"] = str(error)
        finally:
            if process is not None and process.stdin and not process.stdin.closed:
                process.stdin.close()
            if job is not None:
                job.close()
            log.flush()
            if stderr_log is not None:
                stderr_log.flush()
    return outcome
