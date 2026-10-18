# Dead Run — first playable

An original offline rescue-crew road shooter for Godot **4.7.2**. This checkpoint
proves one 50-second bridge run, not the intended 30–60-minute full game.
Only this directory belongs to this builder. Android exports, devices, shared
records and independent review belong to the portfolio coordinator.

## Play

Start Rescue, then drag one finger sideways anywhere on the road. The crew moves
proportionally to the drag and fires automatically. Mouse drag works on desktop.
The gold footprint is the full collision width, including a growing formation.
Overlap an approaching gate to apply its displayed signed value once. Infected
contact removes two crew; one escaping elsewhere through the rescue line removes
one. An approaching warning explains the costs. Clear the centre evacuation
barricade before it reaches the line and survive the bridge to win. Retry starts
the same pinned encounter immediately with three crew.

The left Spore crane takes sustained fire **during ordinary road pressure** and
awards three riggers. Shooting it leaves forward infected unsuppressed. Steering
away pauses unfinished crane damage. This is a timing/targeting choice, not an
end-boss-only encounter. No joystick, shelter timers, paid revival or energy.

Pause opens sound/reduced-effects settings and portable save transfer. Export
directly copies and checks clipboard readback, or reports clipboard unavailability.
Paste fills the text field; Import validates the pinned encounter and checked
envelope, then durably promotes it before replacing memory. Back closes transfer
before toggling pause; native autoquit is disabled. Active cold loads start paused.
Two alternating versioned local slots and eligible interrupted ordinary-write
temps are checked. Failed imported temps never displace the previous rescue.
Save failures are displayed. There is no remote service or account.

## Source boundary

Reference: Last Human: Final Stand, **com.avenue.zombie.gp**, selected L2 recording
<https://www.youtube.com/shorts/xhW1r3ZVJ2Q>. The complete source observations are in
`../references/last-human.md`. Last Z is only a comparison.

The source corroborates positive formation growth, a separate harmful crossing,
sustained large-side-target fire during road action and defeat with a Retry
affordance. Its precise shot/gate/recruit arithmetic and actual drag causality
remain unverified. **Our original deterministic rules:** each projectile adds one
to a gate, capped at +6; a crossing applies the signed value once. Gates start at
−6 and −12. Initial crew 3, formation cap 12, each crew member fires one projectile
every 30 ticks, each infected takes 3 hits, crane 120 hits/+3 riggers, final
barricade 40 hits. Simulation is 60Hz. Run `canal-bridge-v1` and seed `61723` pin
the two gates and 24 infected. Numbers are implementation decisions, not measured
reference equations. Art, meshes, names, icon and synthesized tone are original.

## Reproduce desktop evidence

From this assigned worktree, with the pinned toolchain installed:

```powershell
python android-games/dead-run/tests/run_desktop.py rules --label review
python android-games/dead-run/tests/run_desktop.py headless --label review
python android-games/dead-run/tests/run_desktop.py rendered --label review
python android-games/dead-run/tests/run_desktop.py movie --label review
```

Every run has its own ignored `.artifacts/` directory and isolated APPDATA and
LOCALAPPDATA. The runner freezes raw and LF-normalized source files and hashes,
logs command/PID/exit, fully decodes every PNG, and hashes the artifact files.
Rendered Windows clipboard testing requires the interactive Windows session;
restricted clipboard denial is retained separately and is not a game defect.
Headless clipboard unavailability has explicit feedback without invoking it.

Input policies only read state and send engine touch/drag/key events. Normal
simulation produces loss, Retry, gate changes/growth/harm, crane damage/paused
damage/claim, final objective and victory. No gameplay handler is called by the
playthrough and no earned progress is injected. Code-box text assignment and an
in-memory storage fault adapter are explicitly labelled fixtures. Raw events,
app-written slot bytes and state snapshots accompany decoded PNGs. Float values
are compared within 1e-9 when JSON parsing changes the last binary bit; integer
counters are normalized after checked decoding. The continuous movie omits the
platform test detour and retains natural loss → actual Retry → successful bridge.

## Delivery limits

The credential-free preset requests com.dsschiff.deadrun, 0.1.0/code1, arm64-v8a
and x86_64, min24/target36, no permissions. No APK/export or ADB was operated by
this builder. UID/icon import metadata is generated using a private copied
portable editor, with `shutdown_adb_on_exit=false`; global settings are untouched.

Independent rules/input testing, full-movie Astra reference comparison and root
native Android first-loop checks are next. Physical Fold7 touch/IME/folding/safe
areas, audible sound, measured FPS, human pacing and fun remain untested. The
provisional 24-stage/four-district arc, weapon/enemy breadth and finale wait for
first-loop review. No campaign-completion or phone-tested claim is made.
