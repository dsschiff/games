package com.dsschiff.games.cloud

import com.google.android.gms.tasks.TaskCompletionSource
import com.google.android.gms.tasks.Tasks
import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.Executor

class SdkFlightsTest {
    private val direct = Executor { it.run() }

    @Test fun cancellationWaitsForLateOpenOwnershipAndOriginalClientClose() {
        val gate = RequestLifecycle()
        val flight = SdkFlights(direct)
        val resources = CloseRegistry<String>()
        val opened = TaskCompletionSource<String>()
        val ticket = gate.begin("read")!!
        var close: ((Boolean) -> Unit)? = null
        var replied = false
        flight.observe({ opened.task }, { task ->
            resources.track(task.result) { done -> close = done }
            if (!gate.current(ticket)) resources.close { }
            else replied = gate.finish(ticket)
        }, { fail("open should succeed") })
        val cancellation = gate.beginCancellation("cancel")!!
        var acknowledged = false
        flight.whenIdle { resources.close { okay -> if (okay) acknowledged = gate.finishCancellation(cancellation) } }
        assertFalse(acknowledged)
        assertNull(gate.begin("new"))
        opened.setResult("account-A:late")
        assertNotNull(close)
        assertFalse(replied)
        assertFalse(acknowledged)
        assertNull(gate.begin("before-close"))
        close!!(true)
        assertTrue(acknowledged)
        assertTrue(resources.handles().isEmpty())
        assertNotNull(gate.begin("after-close"))
    }

    @Test fun resolveRegistersReplacementAndReleasesOriginalsBeforeCancellationAcknowledges() {
        val gate = RequestLifecycle()
        val flights = SdkFlights(direct)
        val resources = CloseRegistry<String>()
        val callbacks = mutableMapOf<String, (Boolean) -> Unit>()
        resources.track("selected") { error("selection already consumed") }
        resources.track("other") { callbacks["other"] = it }
        resources.use("selected"); resources.use("other")
        gate.begin("resolve")!!
        val task = TaskCompletionSource<String>()
        flights.observe({ task.task }, { result ->
            resources.track(result.result) { callbacks["replacement"] = it }
            val old = resources.resolved(listOf("selected", "other"), "selected", listOf(result.result), true)
            resources.close(old + result.result) { }
        }, { resources.available("selected"); resources.available("other") })
        val cancel = gate.beginCancellation("close")!!
        var acknowledged = false
        flights.whenIdle { resources.close { if (it) acknowledged = gate.finishCancellation(cancel) } }
        task.setResult("replacement")
        assertFalse(acknowledged)
        callbacks.getValue("replacement")(true)
        assertFalse(acknowledged)
        callbacks.getValue("other")(true)
        assertTrue(acknowledged)
        assertTrue(resources.handles().isEmpty())
    }

    @Test fun commitCompletesConsumptionBeforeDrainAndDoesNotDiscardConsumedContents() {
        val gate = RequestLifecycle()
        val flights = SdkFlights(direct)
        val resources = CloseRegistry<String>()
        resources.track("committing") { error("must not discard during commit") }
        resources.use("committing")
        val old = gate.begin("write")!!
        val task = TaskCompletionSource<Void>()
        flights.observe({ task.task }, { resources.consumed("committing"); assertFalse(gate.finish(old)) }, { resources.available("committing") })
        val cancel = gate.beginCancellation("cancel")!!
        var acknowledged = false
        flights.whenIdle { resources.close { if (it) acknowledged = gate.finishCancellation(cancel) } }
        assertFalse(acknowledged)
        task.setResult(null)
        assertTrue(acknowledged)
        assertTrue(resources.handles().isEmpty())
    }

    @Test fun failedCleanupRejectsNewWorkUntilExplicitRetryWithFreshGeneration() {
        val gate = RequestLifecycle()
        val resources = CloseRegistry<String>()
        var close: ((Boolean) -> Unit)? = null
        resources.track("old-account") { close = it }
        val first = gate.beginCancellation("first")!!
        resources.close { if (!it) gate.failCancellation(first) }
        assertNull(gate.beginCancellation("duplicate-during-close"))
        assertTrue(gate.sameCancellation("first"))
        close!!(false)
        assertNull(gate.begin("cannot-open"))
        val retry = gate.beginCancellation("retry")!!
        assertFalse(gate.finishCancellation(first))
        resources.close { if (it) gate.finishCancellation(retry) }
        assertNull(gate.begin("still-closing"))
        close!!(true)
        assertNotNull(gate.begin("safe"))
    }

    @Test fun canceledSdkTaskAndSynchronousThrowBothDrainWithoutSuccessCallbacks() {
        val flights = SdkFlights(direct)
        // forCanceled exercises the real canceled Task without Android's token-listener main Looper.
        val task = Tasks.forCanceled<String>()
        var failures = 0
        var idle = false
        flights.observe({ task }, { fail("canceled task cannot succeed") }, { failures++ })
        flights.whenIdle { idle = true }
        assertTrue(idle)
        assertEquals(1, failures)
        flights.observe<String>({ throw IllegalStateException("before Task returned") }, { fail("throw cannot succeed") }, { failures++ })
        flights.whenIdle { idle = true }
        assertEquals(2, failures)
    }

    @Test fun alreadyCompleteTaskCannotDrainBeforeCallbackOwnershipWorkFinishes() {
        val flights = SdkFlights(direct)
        var idle = false
        var owned = false
        flights.observe({
            flights.whenIdle { assertTrue(owned); idle = true }
            Tasks.forResult("snapshot")
        }, { owned = true; assertFalse(idle) }, { fail("already-complete task") })
        assertTrue(idle)
    }

    @Test fun childTaskIsAdmittedBeforeParentSettlesAndInvalidatedAuthCannotDispatchChild() {
        val flights = SdkFlights(direct)
        val gate = RequestLifecycle()
        val parent = TaskCompletionSource<String>()
        val child = TaskCompletionSource<String>()
        val ticket = gate.begin("auth")!!
        var idle = false
        flights.observe({ parent.task }, {
            if (gate.current(ticket)) flights.observe({ child.task }, { }, { })
        }, { })
        flights.whenIdle { idle = true }
        parent.setResult("account")
        assertFalse(idle)
        val cancel = gate.beginCancellation("cancel")!!
        child.setException(IllegalStateException("account changed"))
        assertTrue(idle)
        assertTrue(gate.finishCancellation(cancel))
        val lateAuth = TaskCompletionSource<String>()
        val old = gate.begin("second-auth")!!
        var childDispatched = false
        flights.observe({ lateAuth.task }, { if (gate.current(old)) childDispatched = true }, { })
        gate.beginCancellation("second-cancel")!!
        lateAuth.setResult("old-account")
        assertFalse(childDispatched)
        gate.destroy()
        assertFalse(gate.finish(old))
        assertNull(gate.beginCancellation("after-destroy"))
    }
    @Test fun throwingSuccessDispatchesFailureOnceAndBalancesTheFlight() {
        val errors = mutableListOf<Exception>()
        val flights = SdkFlights(direct) { errors.add(it) }
        var failures = 0
        flights.observe({ Tasks.forResult("snapshot") }, { throw IllegalStateException("ownership callback") }, { failures++ })
        var idle = false; flights.whenIdle { idle = true }
        assertTrue(idle); assertEquals(1, failures); assertEquals(1, errors.size)
    }

    @Test fun throwingFailureIsReportedOnceWithoutADuplicateTerminalCallback() {
        val errors = mutableListOf<Exception>()
        val flights = SdkFlights(direct) { errors.add(it) }
        var failures = 0
        flights.observe({ Tasks.forException<String>(IllegalStateException("SDK failed")) }, { fail("cannot succeed") }, {
            failures++; throw IllegalStateException("failure callback")
        })
        var idle = false; flights.whenIdle { idle = true }
        assertTrue(idle); assertEquals(1, failures); assertEquals(1, errors.size)
    }

    @Test fun throwingIdleWaiterDoesNotInvokeFailureOrSkipTheOtherWaiter() {
        val errors = mutableListOf<Exception>()
        val flights = SdkFlights(direct) { errors.add(it) }
        val task = TaskCompletionSource<String>()
        var failures = 0; var success = 0; var laterWaiter = false
        flights.observe({ task.task }, { success++ }, { failures++ })
        flights.whenIdle { throw IllegalStateException("idle callback") }
        flights.whenIdle { laterWaiter = true }
        task.setResult("snapshot")
        assertTrue(laterWaiter); assertEquals(1, success); assertEquals(0, failures); assertEquals(1, errors.size)
        var idle = false; flights.whenIdle { idle = true }; assertTrue(idle)
    }

}
