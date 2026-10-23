package com.dsschiff.games.cloud

import org.junit.Assert.*
import org.junit.Test

class RequestLifecycleTest {
    @Test fun staleCompletionCannotUnlockASecondRequestEvenWithSameId() {
        val gate = RequestLifecycle()
        val first = gate.begin("same")!!
        assertNull(gate.begin("blocked"))
        assertTrue(gate.finish(first))
        val second = gate.begin("same")!!
        assertFalse(gate.finish(first))
        assertTrue(gate.current(second))
        assertNull(gate.begin("still-blocked"))
    }
    @Test fun destructionRejectsLateAccountAndOperationCallbacks() {
        val gate = RequestLifecycle()
        val ticket = gate.begin("open")!!
        assertTrue(gate.accountMatches(ticket, "old", "old"))
        assertFalse(gate.accountMatches(ticket, "old", "new"))
        gate.destroy()
        assertFalse(gate.accountMatches(ticket, "old", "old"))
        assertFalse(gate.finish(ticket))
        assertNull(gate.begin("resurrect"))
    }
    @Test fun pendingClosesKeepRequestSerializedAndOriginalClients() {
        val gate = RequestLifecycle()
        val ticket = gate.begin("discard")!!
        val resources = CloseRegistry<String>()
        val completions = mutableListOf<(Boolean) -> Unit>()
        val originalClients = mutableListOf<String>()
        for (client in listOf("account-A:first", "account-A:second")) {
            resources.track(client) { done -> originalClients.add(client); completions.add(done) }
        }
        // A later account/client must never replace the closures already owned.
        resources.track("account-A:first") { error("wrong account client") }
        resources.close { okay -> assertTrue(okay); gate.finish(ticket) }
        assertEquals(setOf("account-A:first", "account-A:second"), originalClients.toSet())
        assertNull(gate.begin("read"))
        completions[1](true)
        assertEquals(1, resources.handles().size)
        assertNull(gate.begin("read"))
        completions[0](true)
        assertTrue(resources.handles().isEmpty())
        assertNotNull(gate.begin("read"))
    }
    @Test fun failedCloseRemainsOwnedAndCanBeRetried() {
        val resources = CloseRegistry<String>()
        val callbacks = mutableListOf<(Boolean) -> Unit>()
        resources.track("snapshot") { callbacks.add(it) }
        var result: Boolean? = null
        resources.close { result = it }
        callbacks[0](false)
        assertEquals(false, result)
        assertEquals(listOf("snapshot"), resources.handles())
        resources.close { result = it }
        callbacks[1](true)
        assertEquals(true, result)
        assertTrue(resources.handles().isEmpty())
    }
    @Test fun simultaneousCleanupSharesOneCloseAndAwaitsItsCompletion() {
        val resources = CloseRegistry<String>()
        var callback: ((Boolean) -> Unit)? = null
        var calls = 0
        var finished = 0
        resources.track("snapshot") { calls++; callback = it }
        resources.close { finished++ }
        resources.close { finished++ }
        assertEquals(1, calls)
        assertEquals(0, finished)
        callback!!(true)
        assertEquals(2, finished)
        callback!!(true)
        assertEquals(2, finished)
    }
    @Test fun destructionDuringCommitWaitsInsteadOfDiscardingInFlightHandle() {
        val resources = CloseRegistry<String>()
        var discards = 0
        resources.track("committing") { discards++; it(true) }
        resources.use("committing")
        var destroyedCleanup = false
        resources.close { destroyedCleanup = it }
        assertFalse(destroyedCleanup)
        assertEquals(0, discards)
        resources.consumed("committing")
        assertTrue(destroyedCleanup)
        assertEquals(0, discards)
        assertTrue(resources.handles().isEmpty())
    }
    @Test fun resolveFailureReleasesBothHandlesThenAwaitsBothDiscards() {
        val resources = CloseRegistry<String>()
        val callbacks = mutableListOf<(Boolean) -> Unit>()
        for (handle in listOf("selected", "other")) {
            resources.track(handle) { callbacks.add(it) }
            resources.use(handle)
        }
        var completed = false
        resources.close { completed = it }
        assertTrue(callbacks.isEmpty())
        resources.available("selected")
        resources.available("other")
        assertEquals(2, callbacks.size)
        callbacks[0](true)
        assertFalse(completed)
        callbacks[1](true)
        assertTrue(completed)
    }
    @Test fun handleArrivingAfterDestructionStillClosesWithoutAReply() {
        val resources = CloseRegistry<String>()
        val gate = RequestLifecycle()
        val ticket = gate.begin("open")!!
        gate.destroy()
        var closed = false
        resources.track("late") { closed = true; it(true) }
        if (!gate.current(ticket)) resources.close(listOf("late")) { }
        assertTrue(closed)
        assertFalse(gate.finish(ticket))
    }
    @Test fun thrownCloseDoesNotSkipOtherHandlesOrReleaseBarrierEarly() {
        val resources = CloseRegistry<String>()
        var callback: ((Boolean) -> Unit)? = null
        resources.track("broken") { throw IllegalStateException() }
        resources.track("pending") { callback = it }
        var result: Boolean? = null
        resources.close { result = it }
        assertNull(result)
        callback!!(true)
        assertEquals(false, result)
        assertEquals(listOf("broken"), resources.handles())
    }
    @Test fun argumentBoundsRejectHugeNestedAndOversizedBase64BeforeParsing() {
        assertFalse(RequestBounds.arguments("x".repeat(RequestBounds.ARGUMENT_LIMIT + 1)))
        assertFalse(RequestBounds.arguments("{\"nested\":{} }"))
        assertFalse(RequestBounds.arguments("{\"nested\":[1]}"))
        assertTrue(RequestBounds.arguments("{\"slot\":\"name\",\"data\":\"e30=\"}"))
        assertTrue(RequestBounds.arguments("{\"text\":\"{not nesting}\"}"))
        assertFalse(RequestBounds.encoded("A".repeat(RequestBounds.BASE64_LIMIT + 4)))
        assertFalse(RequestBounds.encoded("bad%"))
        assertTrue(RequestBounds.encoded("e30="))
    }
    @Test fun expectedHashIsValidatedBeforeAnySnapshotOpen() {
        assertTrue(RequestBounds.expectedHash(""))
        assertTrue(RequestBounds.expectedHash("a".repeat(64)))
        assertFalse(RequestBounds.expectedHash("a".repeat(63)))
        assertFalse(RequestBounds.expectedHash("Z".repeat(64)))
    }
    @Test fun distinctHandlesWithEqualMetadataBothClose() {
        data class Handle(val slot: String)
        val first = Handle("same-snapshot-id")
        val second = Handle("same-snapshot-id")
        val resources = CloseRegistry<Handle>()
        var closes = 0
        resources.track(first) { closes++; it(true) }
        resources.track(second) { closes++; it(true) }
        assertEquals(2, resources.handles().size)
        resources.close { assertTrue(it) }
        assertEquals(2, closes)
    }
    @Test fun realGoogleTasksMustBothFinishBeforeTheCloseBarrierUnlocks() {
        val first = com.google.android.gms.tasks.TaskCompletionSource<Void>()
        val second = com.google.android.gms.tasks.TaskCompletionSource<Void>()
        val direct = java.util.concurrent.Executor { it.run() }
        val gate = RequestLifecycle()
        val ticket = gate.begin("discard")!!
        val resources = CloseRegistry<String>()
        resources.track("first") { done -> first.task.addOnCompleteListener(direct) { done(it.isSuccessful) } }
        resources.track("second") { done -> second.task.addOnCompleteListener(direct) { done(it.isSuccessful) } }
        resources.close { assertTrue(it); gate.finish(ticket) }
        first.setResult(null)
        assertNull(gate.begin("too-early"))
        second.setResult(null)
        assertNotNull(gate.begin("after-both"))
        assertTrue(resources.handles().isEmpty())
    }

    @Test fun alreadyClosedContentsSkipDiscardAndCloseRaceCountsAsReleased() {
        var calls = 0
        var okay = false
        SnapshotRelease.close({ true }, { calls++; it(false) }, { okay = it })
        assertTrue(okay)
        assertEquals(0, calls)
        var closed = false
        SnapshotRelease.close({ closed }, { done -> calls++; closed = true; done(false) }, { okay = it })
        assertTrue(okay)
        assertEquals(1, calls)
    }
    @Test fun resolveSuccessConsumesClosedSelectionAndOwnsNewReturnedHandle() {
        val resources = CloseRegistry<String>()
        val pending = mutableMapOf<String, (Boolean) -> Unit>()
        var selectedDiscarded = false
        resources.track("selected") { selectedDiscarded = true; it(false) }
        resources.track("other") { pending["other"] = it }
        resources.use("selected")
        resources.use("other")
        resources.track("new-open-result") { pending["new-open-result"] = it }
        val old = resources.resolved(listOf("selected", "other"), "selected", listOf("new-open-result"), true)
        var completed = false
        resources.close(old) { completed = it }
        assertFalse(completed)
        assertFalse(selectedDiscarded)
        pending["other"]!!(true)
        assertTrue(completed)
        assertEquals(listOf("new-open-result"), resources.handles())
        resources.close { completed = it }
        pending["new-open-result"]!!(true)
        assertTrue(resources.handles().isEmpty())
    }
    @Test fun repeatedConflictRetainsOnlyNewPairUntilAnExplicitNextChoice() {
        val resources = CloseRegistry<String>()
        var discarded = 0
        fun add(handle: String) { resources.track(handle) { discarded++; it(true) } }
        add("first"); add("second")
        resources.use("first"); resources.use("second")
        add("third"); add("fourth")
        val old = resources.resolved(listOf("first", "second"), "first", listOf("third", "fourth"), true)
        resources.close(old) { assertTrue(it) }
        assertEquals(1, discarded)
        assertEquals(setOf("third", "fourth"), resources.handles().toSet())
        // No auto-merge or second resolution; the next choice is explicit.
        resources.use("third"); resources.use("fourth")
        add("final")
        val obsolete = resources.resolved(listOf("third", "fourth"), "fourth", listOf("final"), true)
        resources.close(obsolete) { assertTrue(it) }
        assertEquals(2, discarded)
        assertEquals(listOf("final"), resources.handles())
    }
    @Test fun destructionDuringSuccessfulResolveClosesLateNewResultWithoutDiscardingConsumedSelection() {
        val resources = CloseRegistry<String>()
        val gate = RequestLifecycle()
        val ticket = gate.begin("resolve")!!
        val pending = mutableMapOf<String, (Boolean) -> Unit>()
        resources.track("selected") { error("SDK already consumed selection") }
        resources.track("other") { pending["other"] = it }
        resources.use("selected"); resources.use("other")
        gate.destroy()
        var originalCleanup = false
        resources.close { originalCleanup = it }
        assertTrue(pending.isEmpty())
        resources.track("late-open-result") { pending["late-open-result"] = it }
        val old = resources.resolved(listOf("selected", "other"), "selected", listOf("late-open-result"), true)
        assertFalse(originalCleanup)
        if (!gate.current(ticket)) resources.close(old + listOf("late-open-result")) { }
        pending["late-open-result"]!!(true)
        assertFalse(originalCleanup)
        pending["other"]!!(true)
        assertTrue(originalCleanup)
        assertFalse(gate.finish(ticket))
        assertTrue(resources.handles().isEmpty())
    }

}
