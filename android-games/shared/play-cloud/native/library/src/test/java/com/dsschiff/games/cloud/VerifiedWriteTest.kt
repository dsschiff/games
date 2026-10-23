package com.dsschiff.games.cloud

import org.junit.Assert.*
import org.junit.Test

class VerifiedWriteTest {
    private val bytes = "complete earned save".toByteArray()
    @Test fun refusedWriteNeverCommits() {
        var committed = false
        assertFalse(VerifiedWrite.commit(bytes, { false }, { bytes }, { committed = true }))
        assertFalse(committed)
    }
    @Test fun truncatedReadbackNeverCommits() {
        var committed = false
        assertFalse(VerifiedWrite.commit(bytes, { true }, { bytes.copyOf(3) }, { committed = true }))
        assertFalse(committed)
    }
    @Test fun thrownReadNeverCommits() {
        var committed = false
        assertFalse(VerifiedWrite.commit(bytes, { true }, { throw IllegalStateException() }, { committed = true }))
        assertFalse(committed)
    }
    @Test fun exactReadbackCommitsOnce() {
        var commits = 0
        assertTrue(VerifiedWrite.commit(bytes, { true }, { bytes.copyOf() }, { commits++ }))
        assertEquals(1, commits)
    }
}
