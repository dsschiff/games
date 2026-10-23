package com.dsschiff.games.cloud

/** Never submit a snapshot whose local staging failed or read back different bytes. */
internal object VerifiedWrite {
    fun commit(bytes: ByteArray, write: (ByteArray) -> Boolean, read: () -> ByteArray, commit: () -> Unit): Boolean {
        return try {
            if (!write(bytes) || !read().contentEquals(bytes)) false
            else { commit(); true }
        } catch (_: Exception) { false }
    }
}
