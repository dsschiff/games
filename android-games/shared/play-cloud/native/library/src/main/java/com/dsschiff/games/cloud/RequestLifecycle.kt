package com.dsschiff.games.cloud

/** A callback belongs to one request and one plugin lifetime, even if IDs repeat. */
internal class RequestLifecycle {
    class Ticket(val id: String, val generation: Long)
    private var generation = 0L
    private var destroyed = false
    private var active: Ticket? = null
    private var cancellation: Ticket? = null
    private var cancelFailed = false
    @Synchronized fun begin(id: String): Ticket? {
        if (destroyed || active != null || cancellation != null) return null
        return Ticket(id, ++generation).also { active = it }
    }
    @Synchronized fun current(ticket: Ticket) = !destroyed && active === ticket
    @Synchronized fun finish(ticket: Ticket): Boolean {
        if (!current(ticket)) return false
        active = null
        return true
    }
    @Synchronized fun beginCancellation(id: String): Ticket? {
        if (destroyed || (cancellation != null && !cancelFailed)) return null
        active = null
        cancelFailed = false
        return Ticket(id, ++generation).also { cancellation = it }
    }
    @Synchronized fun sameCancellation(id: String) = !destroyed && cancellation?.id == id
    @Synchronized fun currentCancellation(ticket: Ticket) = !destroyed && cancellation === ticket
    @Synchronized fun failCancellation(ticket: Ticket) {
        if (currentCancellation(ticket)) cancelFailed = true
    }
    @Synchronized fun finishCancellation(ticket: Ticket): Boolean {
        if (!currentCancellation(ticket)) return false
        cancellation = null
        cancelFailed = false
        return true
    }
    @Synchronized fun destroy() { destroyed = true; generation++; active = null; cancellation = null }
    fun accountMatches(ticket: Ticket, expected: String, actual: String) = current(ticket) && expected == actual
}

internal fun <H> identityDistinct(values: List<H>): List<H> {
    val seen = java.util.Collections.newSetFromMap(java.util.IdentityHashMap<H, Boolean>())
    return values.filter { seen.add(it) }
}

/** Each close action captures its opening client; failed closes remain retryable. */
internal class CloseRegistry<H> {
    private inner class Lease(val action: ((Boolean) -> Unit) -> Unit) {
        private var closed = false
        private var closing = false
        private var inUse = false
        private var attempt = 0L
        private val waiters = mutableListOf<(Boolean) -> Unit>()
        @Synchronized fun use() { check(!closed && !closing && !inUse); inUse = true }
        fun release(consumed: Boolean) {
            val callbacks = synchronized(this) {
                inUse = false
                if (consumed) {
                    closed = true
                    waiters.toList().also { waiters.clear() }
                } else emptyList()
            }
            callbacks.forEach { try { it(true) } catch (_: Exception) { } }
            if (!consumed) drain()
        }
        fun close(done: (Boolean) -> Unit) {
            synchronized(this) {
                if (closed) { done(true); return }
                waiters.add(done)
            }
            drain()
        }
        private fun drain() {
            val serial = synchronized(this) {
                if (closed || closing || inUse || waiters.isEmpty()) return
                closing = true
                ++attempt
            }
            fun complete(okay: Boolean) {
                val callbacks = synchronized(this) {
                    if (!closing || attempt != serial) return
                    closed = okay
                    closing = false
                    waiters.toList().also { waiters.clear() }
                }
                callbacks.forEach { try { it(okay) } catch (_: Exception) { } }
            }
            try { action { complete(it) } } catch (_: Exception) { complete(false) }
        }
    }
    private val leases = java.util.IdentityHashMap<H, Lease>()
    @Synchronized fun track(handle: H, close: ((Boolean) -> Unit) -> Unit) { if (!leases.containsKey(handle)) leases[handle] = Lease(close) }
    @Synchronized fun handles(): List<H> = leases.keys.toList()
    fun use(handle: H) {
        val lease = synchronized(this) { checkNotNull(leases[handle]) }
        lease.use()
    }
    fun available(handle: H) { synchronized(this) { leases[handle] }?.release(false) }
    fun consumed(handle: H) { synchronized(this) { leases.remove(handle) }?.release(true) }
    fun resolved(originals: List<H>, selected: H, returned: List<H>, selectedClosed: Boolean): List<H> {
        // resolveConflict can consume/close selected contents and return a NEW open handle.
        if (selectedClosed) consumed(selected)
        originals.forEach { available(it) }
        return identityDistinct(originals).filter { old -> returned.none { it === old } }
    }
    fun close(handles: List<H> = handles(), done: (Boolean) -> Unit) {
        val pending = synchronized(this) { identityDistinct(handles).mapNotNull { h -> leases[h]?.let { h to it } } }
        if (pending.isEmpty()) { done(true); return }
        var remaining = pending.size
        var okay = true
        val barrier = Any()
        pending.forEach { (handle, lease) -> lease.close { success ->
            if (success) synchronized(this) { if (leases[handle] === lease) leases.remove(handle) }
            val finished = synchronized(barrier) { okay = okay && success; --remaining == 0 }
            if (finished) done(okay)
        } }
    }
}

internal object RequestBounds {
    const val BYTE_LIMIT = 2_900_000
    const val BASE64_LIMIT = ((BYTE_LIMIT + 2) / 3) * 4
    const val ARGUMENT_LIMIT = BASE64_LIMIT + 16_384
    fun arguments(text: String): Boolean {
        if (text.length > ARGUMENT_LIMIT) return false
        var depth = 0
        var quoted = false
        var escaped = false
        var strings = 0
        for (c in text) {
            if (quoted) {
                if (escaped) escaped = false
                else if (c == '\\') escaped = true
                else if (c == '"') quoted = false
            } else when (c) {
                '"' -> { quoted = true; if (++strings > 32) return false }
                '{' -> if (++depth > 1) return false
                '}' -> if (--depth < 0) return false
                '[', ']' -> return false
            }
        }
        return depth == 0 && !quoted && text.trimStart().startsWith("{")
    }
    fun encoded(text: String) = text.length <= BASE64_LIMIT && text.length % 4 == 0 && text.matches(Regex("[A-Za-z0-9+/]*={0,2}"))
    fun expectedHash(text: String) = text.isEmpty() || text.matches(Regex("[a-f0-9]{64}"))
}

/** Already consumed SDK contents are released, including a close/failure race. */
internal object SnapshotRelease {
    fun close(isClosed: () -> Boolean, discard: ((Boolean) -> Unit) -> Unit, done: (Boolean) -> Unit) {
        try {
            if (isClosed()) done(true)
            else discard { success ->
                val closed = try { isClosed() } catch (_: Exception) { false }
                done(success || closed)
            }
        } catch (_: Exception) { done(false) }
    }
}
