# Frontline sortie and record feedback

Unreleased presentation increment from `64cd050331613604fb3489468dd758264e1bfe15`.
Only campaign presentation and its pure feedback helper change. Store, decoder,
private Import journal, campaign rules, catalog, save schema/meaning, legacy
presentation, versions, export presets, art and controls remain unchanged.

The recap separates **This sortie** from the retained campaign record. A record's
own medal is paired with its own time, separately from cumulative earned stars in
Journey. Existing validation permits those medals to differ. Skirmishes show
**Latest clear** for the exact seed/style: losses do not overwrite that clear and
it is not labelled best. Reload never claims newly earned medals.

Journey explains existing victory criteria in priority order: three stars for no
escapes and commander HP at least60%; otherwise two for HQ at least50%; otherwise
one for victory. The three-star branch does not require half HQ. Campaign rows
name cumulative earned stars and their separate retained record. Readonly
skirmish rows are reachable by the existing scroll, with unchanged Close.

Recap contribution comes from saved recruit damage and support ledgers. Relay's
line describes its existing effect rather than inventing attributed damage.
Canonical objective failures are compacted only when the entire stored cause
matches the owning rules' objective text. They still name relays, relays plus
Storm Engine, all caches, every mortar crew, siege boss, or minimum stop target.
Commander/HQ failures retain the actual threat. Unusual long retained causes use
an explicit ellipsis; their optional support row yields space to the failure.
Full stored cause and all state remain untouched.

## Evidence

`RECORD_FEEDBACK_CHECKPOINT.json` binds exact source, base comparisons, runner,
cache, retained input provenance, failed attempts and final packet artifacts.
All runs are headless Godot4.7.2 with Dummy audio and isolated user data; no import,
renderer, GPU, native app, system clipboard, build or publication was used.

- Final actual-input route: **423/0**,3468 events,26 snapshots. Exact retained
  genuine input-earned slots first bootstrap the shipping owner; loading those
  fixtures is not new earned progression. New ScreenTouch/joystick play then
  replays Last Supply with Ward (207.12s), fails rifle-only (HQ breach,37.17s),
  Retrys and refits Relay, then wins at206.50s. Retained record stays206.50s.
  Existing input policy runs at8x simulation speed; this is not human pacing.
- Actual font/wrapping queries across720x1680,1153x1280,2276x1280 cover the
  effective570x230/font24 recap, unchanged Retry/Next rectangles and Journey
  rows/criteria. Maximum tested cell height219px. Typed extremes are labelled,
  never adopted or saved: time10000,seed999999,large contributions, all rule-
  emitted objective categories, unknown cause, lower record/cumulative medal.
  Typed text is protected from ordinary refresh and verified before measuring.
- Final unchanged rules **416/0** and Import recovery **870/0**. Recovery uses
  labelled full contexts including parked legacy/profile/settings, separate
  from genuine earned-route provenance. Raw logs are strict clean (no ERROR,
  WARNING or ObjectDB markers) and executed source maps remain unchanged.
- Readonly refresh/resize/Journey checks preserve the exact entire live context
  and all raw slots. Pause navigation's existing save is admitted: raw baseline
  is taken afterward. Fresh shipping-owner cold comparison serializes BOTH
  complete contexts through owning Store.encode/decode at export revision0,
  then compares exact decoded dictionaries, without epsilon or dropped fields.
  Binary floating point representation can change on JSON roundtrip; complete
  serialized saved meaning remains exact. Normal bootstrap slot revision writes
  are admitted separately.

## Preserved failures and qualifications

The initial actual earned-B baseline **5/2** proves the missing current/record
separation. The **181/4** route remains: three raw-slot expectations incorrectly
included the admitted Pause save, and direct in-memory binary float equality
failed after JSON cold roundtrip. The subsequent240/0 route corrected those but
its typed font stress was overwritten by ordinary refresh, so it does not prove
extreme-string layout. Later protected typed runs and final423/0 do. Parse-error
packets remain, including the initial objective test's wrong API names. Earlier
277/0+416/0+870/0 packets predate the final objective wording correction; they are
historical, not current-source substitutes.

Existing imported cache was reused only after binding118 unchanged asset/import
inputs and118 imported artifacts. No asset substitution or editor import occurred.
The one new test UID was allocated by a direct headless ResourceUID call, with a
small receipt. Session-leftovers scan reported an empty list. Retained test files
and raw slots are necessary evidence, not disposable copies of a native build.

Font-cell bounds do not prove raster legibility, Fold7 usability, normal-speed
comprehension, performance, motivation or fun. Same-process fresh-owner bootstrap
is not OS-kill/power-loss proof. Root still owns independent source review,
integration, rendered/native acceptance, any candidate version/build and release.
