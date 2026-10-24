package com.dsschiff.games.cloud

import android.app.Activity
import android.util.Base64
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import com.google.android.gms.games.SnapshotsClient
import com.google.android.gms.games.snapshot.Snapshot
import com.google.android.gms.games.snapshot.SnapshotMetadataChange
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject
import java.security.MessageDigest

/** Transport only. Game code validates and commits downloads through its existing store. */
class PlayCloudPlugin(godot: Godot) : GodotPlugin(godot) {
    private val lifecycle = RequestLifecycle()
    private val resources = CloseRegistry<Snapshot>()
    private val flights = SdkFlights(onError = { android.util.Log.e("PlayCloud", "SDK callback failed", it) })
    private var remoteMutationDispatched = false
    private var initialized = false
    private data class Held(val conflict: SnapshotsClient.SnapshotConflict, val player: String, val client: SnapshotsClient)
    private var held: Held? = null
    private val operations = setOf("sign_in", "status", "read", "write", "resolve", "discard_conflict")

    override fun getPluginName() = "PlayCloud"
    override fun getPluginSignals() = setOf(SignalInfo("completed", String::class.java, String::class.java))
    override fun onMainDestroy() {
        lifecycle.destroy()
        // Pending open/resolve callbacks track and close their late handles too.
        resources.close { if (it) held = null }
        super.onMainDestroy()
    }
    private fun configured(): Boolean {
        val a = activity ?: return false
        val info = a.packageManager.getApplicationInfo(a.packageName, android.content.pm.PackageManager.GET_META_DATA)
        val value = info.metaData?.get("com.google.android.gms.games.APP_ID") ?: return false
        val text = if (value is Int) runCatching { a.getString(value) }.getOrDefault("") else value.toString()
        return text.trim().matches(Regex("[1-9][0-9]+"))
    }
    @UsedByGodot
    fun is_configured(): Boolean = runCatching { configured() }.getOrDefault(false)

    @UsedByGodot
    fun cancel(id: String) {
        if (id.length !in 1..128) {
            emitSignal("completed", id.take(128), JSONObject().put("status", "invalid_request").toString()); return
        }
        val a = activity
        if (a == null) { emitSignal("completed", id, JSONObject().put("status", "unavailable").toString()); return }
        a.runOnUiThread {
            val ticket = lifecycle.beginCancellation(id)
            if (ticket == null) {
                if (!lifecycle.sameCancellation(id)) emitSignal("completed", id, JSONObject().put("status", "busy").toString())
                return@runOnUiThread
            }
            val effect = if (remoteMutationDispatched) "unknown" else "none"
            flights.whenIdle {
                resources.close { okay ->
                    if (!lifecycle.currentCancellation(ticket)) return@close
                    if (okay && resources.handles().isEmpty()) {
                        held = null
                        remoteMutationDispatched = false
                        if (lifecycle.finishCancellation(ticket)) emitSignal("completed", id,
                            JSONObject().put("status", "cancelled").put("remote_effect", effect).toString())
                    } else {
                        // Failed cleanup remains owned and rejects new work until explicit cancel retry.
                        lifecycle.failCancellation(ticket)
                        emitSignal("completed", id, JSONObject().put("status", "close_failed").put("remote_effect", effect).toString())
                    }
                }
            }
        }
    }

    private fun reply(ticket: RequestLifecycle.Ticket, body: JSONObject) {
        if (lifecycle.finish(ticket)) emitSignal("completed", ticket.id, body.toString())
    }
    private fun fail(ticket: RequestLifecycle.Ticket, code: String) {
        if (!lifecycle.current(ticket)) return
        resources.close { okay ->
            if (okay) held = null
            reply(ticket, JSONObject().put("status", if (okay) code else "close_failed"))
        }
    }
    private fun hash(data: ByteArray) = MessageDigest.getInstance("SHA-256").digest(data).joinToString("") { "%02x".format(it) }
    private fun packet(snapshot: Snapshot): JSONObject {
        val data = snapshot.snapshotContents.readFully()
        require(data.size <= RequestBounds.BYTE_LIMIT)
        return JSONObject().put("data", Base64.encodeToString(data, Base64.NO_WRAP)).put("sha256", hash(data))
    }
    private fun track(snapshot: Snapshot, client: SnapshotsClient) {
        resources.track(snapshot) { done ->
            SnapshotRelease.close({ snapshot.snapshotContents.isClosed },
                { complete -> client.discardAndClose(snapshot).addOnCompleteListener { complete(it.isSuccessful) } }, done)
        }
    }
    private fun acquired(result: SnapshotsClient.DataOrConflict<Snapshot>, client: SnapshotsClient): List<Snapshot> {
        val handles = if (result.isConflict) listOf(result.conflict!!.snapshot, result.conflict!!.conflictingSnapshot) else listOf(result.data!!)
        handles.forEach { track(it, client) }
        return handles
    }
    private fun guard(ticket: RequestLifecycle.Ticket) = lifecycle.current(ticket)
    private fun account(ticket: RequestLifecycle.Ticket, a: Activity, owner: String, next: () -> Unit) {
        if (!guard(ticket)) return
        flights.observe({ PlayGames.getGamesSignInClient(a).isAuthenticated }, authDone@ { task ->
            if (!guard(ticket)) return@authDone
            if (!task.result.isAuthenticated) { fail(ticket, "signed_out"); return@authDone }
            flights.observe({ PlayGames.getPlayersClient(a).currentPlayer }, playerDone@ { playerTask ->
                if (!guard(ticket)) return@playerDone
                if (!lifecycle.accountMatches(ticket, owner, playerTask.result.playerId)) fail(ticket, "account_changed")
                else try { next() } catch (_: Exception) { fail(ticket, "invalid_snapshot") }
            }, { fail(ticket, "account_unavailable") })
        }, { fail(ticket, "authentication_unavailable") })
    }
    @UsedByGodot
    fun request(id: String, operation: String, arguments: String) {
        if (id.length !in 1..128 || operation !in operations || !RequestBounds.arguments(arguments)) {
            emitSignal("completed", id.take(128), JSONObject().put("status", "invalid_request").toString()); return
        }
        val a = activity
        if (a == null) { emitSignal("completed", id, JSONObject().put("status", "unavailable").toString()); return }
        // Admission, cancellation and SDK dispatch share the same UI dispatcher.
        a.runOnUiThread {
            val ticket = lifecycle.begin(id)
            if (ticket == null) { emitSignal("completed", id, JSONObject().put("status", "busy").toString()); return@runOnUiThread }
            try {
                if (!configured()) { fail(ticket, "not_configured"); return@runOnUiThread }
                if (!initialized) { PlayGamesSdk.initialize(a); initialized = true }
                val args = JSONObject(arguments)
                // Validate all write inputs before decode and before any open/create.
                var bytes = ByteArray(0)
                if (operation == "write") {
                    val data = args.getString("data")
                    require(RequestBounds.encoded(data) && RequestBounds.expectedHash(args.getString("expected_sha256")))
                    bytes = Base64.decode(data, Base64.NO_WRAP)
                    require(bytes.size <= RequestBounds.BYTE_LIMIT)
                }
                if (operation in setOf("read", "write")) require(args.getString("slot").matches(Regex("[a-z0-9_-]{1,80}")))
                val signIn = PlayGames.getGamesSignInClient(a)
                if (operation == "sign_in") {
                    resources.close { okay ->
                        if (!guard(ticket)) return@close
                        if (!okay) { fail(ticket, "close_failed"); return@close }
                        held = null
                        flights.observe({ signIn.signIn() }, { task ->
                            if (guard(ticket)) reply(ticket, JSONObject().put("status", if (task.result.isAuthenticated) "authenticated" else "signed_out"))
                        }, { fail(ticket, "sign_in_failed") })
                    }
                    return@runOnUiThread
                }
                flights.observe({ signIn.isAuthenticated }, authDone@ { task ->
                    if (!guard(ticket)) return@authDone
                    if (!task.result.isAuthenticated) { fail(ticket, "signed_out"); return@authDone }
                    flights.observe({ PlayGames.getPlayersClient(a).currentPlayer }, playerDone@ { playerTask ->
                        if (!guard(ticket)) return@playerDone
                        val owner = playerTask.result.playerId
                        if (operation == "status") {
                            if (held != null && held!!.player != owner) fail(ticket, "account_changed")
                            else reply(ticket, JSONObject().put("status", "authenticated").put("player", owner))
                        } else if (args.optString("player") != owner) fail(ticket, "account_changed")
                        else try { operate(ticket, operation, args, bytes, owner, a) } catch (_: Exception) { fail(ticket, "invalid_request") }
                    }, { fail(ticket, "account_unavailable") })
                }, { fail(ticket, "authentication_unavailable") })
            } catch (_: Exception) { fail(ticket, "invalid_request") }
        }
    }
    private fun operate(ticket: RequestLifecycle.Ticket, op: String, args: JSONObject, bytes: ByteArray, owner: String, a: Activity) {
        if (op == "resolve") {
            val current = held
            if (current == null || current.player != owner || args.optString("conflict") != current.conflict.conflictId) {
                fail(ticket, "conflict_expired"); return
            }
            val choice = args.getInt("choice")
            require(choice == 0 || choice == 1)
            val selected = if (choice == 0) current.conflict.snapshot else current.conflict.conflictingSnapshot
            account(ticket, a, owner) {
                val originals = identityDistinct(listOf(current.conflict.snapshot, current.conflict.conflictingSnapshot))
                originals.forEach { resources.use(it) }
                flights.observe({
                    remoteMutationDispatched = true
                    current.client.resolveConflict(current.conflict.conflictId, selected)
                }, resolved@ { task ->
                    try {
                        val result = task.result
                        val returned = acquired(result, current.client)
                        val old = resources.resolved(originals, selected, returned, selected.snapshotContents.isClosed)
                        if (!guard(ticket)) { resources.close(returned + old) { }; return@resolved }
                        resources.close(old) { okay ->
                            if (!guard(ticket)) return@close
                            if (!okay) { fail(ticket, "close_failed"); return@close }
                            held = null
                            account(ticket, a, owner) { deliver(ticket, result, owner, current.client) }
                        }
                    } catch (_: Exception) { originals.forEach { resources.available(it) }; fail(ticket, "invalid_snapshot") }
                }, { originals.forEach { resources.available(it) }; fail(ticket, "resolve_failed") })
            }
            return
        }
        // Keep busy and old conflict handles until every original-client close settles.
        resources.close { okay ->
            if (!guard(ticket)) return@close
            if (!okay) { reply(ticket, JSONObject().put("status", "close_failed")); return@close }
            held = null
            if (op == "discard_conflict") { reply(ticket, JSONObject().put("status", "discarded")); return@close }
            account(ticket, a, owner) {
                val client = PlayGames.getSnapshotsClient(a)
                flights.observe({ client.open(args.getString("slot"), op == "write", SnapshotsClient.RESOLUTION_POLICY_MANUAL) }, opened@ { task ->
                    try {
                        val result = task.result
                        val handles = acquired(result, client)
                        if (!guard(ticket)) { resources.close(handles) { }; return@opened }
                        account(ticket, a, owner) {
                            if (result.isConflict || op == "read") deliver(ticket, result, owner, client)
                            else write(ticket, result.data!!, args.getString("expected_sha256"), bytes, owner, client)
                        }
                    } catch (_: Exception) { fail(ticket, "invalid_snapshot") }
                }, { fail(ticket, "snapshot_unavailable") })
            }
        }
    }
    private fun write(ticket: RequestLifecycle.Ticket, snapshot: Snapshot, expected: String, bytes: ByteArray, owner: String, client: SnapshotsClient) {
        if (!guard(ticket)) return
        val existing = snapshot.snapshotContents.readFully()
        require(existing.size <= RequestBounds.BYTE_LIMIT)
        // This compares the opened snapshot; it is not an atomic server CAS.
        val actual = if (existing.isEmpty()) "" else hash(existing)
        if (expected != actual) {
            val remote = packet(snapshot)
            resources.close(listOf(snapshot)) { okay ->
                if (okay) reply(ticket, JSONObject().put("status", "remote_changed").put("player", owner).put("remote", remote))
                else fail(ticket, "close_failed")
            }
        } else {
            val staged = VerifiedWrite.commit(bytes,
                { snapshot.snapshotContents.writeBytes(it) }, { snapshot.snapshotContents.readFully() }, {
                    check(guard(ticket))
                    resources.use(snapshot)
                    flights.observe({
                        remoteMutationDispatched = true
                        client.commitAndClose(snapshot, SnapshotMetadataChange.Builder().build())
                    }, {
                        resources.consumed(snapshot)
                        if (guard(ticket)) reply(ticket, JSONObject().put("status", "submitted").put("player", owner).put("sha256", hash(bytes)))
                    }, { resources.available(snapshot); fail(ticket, "write_failed") })
                })
            if (!staged) fail(ticket, "write_failed")
        }
    }
    private fun deliver(ticket: RequestLifecycle.Ticket, result: SnapshotsClient.DataOrConflict<Snapshot>, owner: String, client: SnapshotsClient) {
        if (!guard(ticket)) return
        if (result.isConflict) {
            val conflict = result.conflict!!
            val body = JSONObject().put("status", "conflict").put("player", owner).put("conflict", conflict.conflictId)
                .put("first", packet(conflict.snapshot)).put("second", packet(conflict.conflictingSnapshot))
            held = Held(conflict, owner, client)
            reply(ticket, body)
        } else {
            val body = packet(result.data!!)
            resources.close(listOf(result.data!!)) { okay ->
                if (okay) reply(ticket, JSONObject().put("status", "loaded").put("player", owner).put("snapshot", body))
                else fail(ticket, "close_failed")
            }
        }
    }
}
