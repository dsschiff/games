package com.dsschiff.games.cloud

import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.OnCompleteListener
import java.util.concurrent.Executor

/** Counts callback ownership work, not just SDK task completion. UI-serialized by its owner. */
internal class SdkFlights(private val executor: Executor? = null, private val onError: (Exception) -> Unit = {}) {
    private var pending = 0
    private val waiters = mutableListOf<() -> Unit>()

    private fun report(error: Exception) { try { onError(error) } catch (_: Exception) { } }
    private fun notify(done: () -> Unit) { try { done() } catch (error: Exception) { report(error) } }

    fun whenIdle(done: () -> Unit) {
        val idle = synchronized(this) {
            if (pending == 0) true else { waiters.add(done); false }
        }
        if (idle) notify(done)
    }

    fun <T> observe(start: () -> Task<T>, success: (Task<T>) -> Unit, failure: () -> Unit) {
        synchronized(this) { pending++ }
        var settled = false
        var claimed = false
        fun claim(): Boolean = synchronized(this) {
            if (claimed) false else { claimed = true; true }
        }
        fun finish() {
            val callbacks = synchronized(this) {
                if (settled) return
                settled = true
                pending--
                if (pending == 0) waiters.toList().also { waiters.clear() } else emptyList()
            }
            callbacks.forEach { notify(it) }
        }
        fun failOnce() { try { failure() } catch (error: Exception) { report(error) } }
        try {
            val listener = OnCompleteListener<T> { task ->
                if (claim()) {
                    try {
                        if (task.isSuccessful) {
                            try { success(task) } catch (error: Exception) { report(error); failOnce() }
                        } else failOnce()
                    } finally { finish() }
                }
            }
            // Admission happens before start(): a synchronous throw must settle too.
            val task = start()
            if (executor == null) task.addOnCompleteListener(listener)
            else task.addOnCompleteListener(executor, listener)
        } catch (error: Exception) {
            report(error)
            if (claim()) { try { failOnce() } finally { finish() } }
        }
    }
}
