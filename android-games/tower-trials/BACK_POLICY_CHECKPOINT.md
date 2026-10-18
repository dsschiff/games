# Native Back policy fix — 0.3.1 / code4

Coordinator confirmed native Android KEYCODE_BACK from code3 Settings exited the process to the launcher. Save retention passed; navigation did not. A notification handler alone does not disable SceneTree's default Back quit policy.

This narrow amendment explicitly sets both:

```gdscript
# project.godot [application]
config/quit_on_go_back=false
# main.gd _ready()
get_tree().quit_on_go_back = false
```

Version0.3.1/APKcode4 preserves increasing update codes. Save schema3, generator1, both catalogs, both rule files and navigation semantics are unchanged.

`tests/back_policy.gd` uses real touch controls to open Settings, transfer, guide and forecast in campaign and Challenge modes. It emits the root Window Back signal (default-quit policy) and explicitly propagates WM_GO_BACK_REQUEST (navigation). All overlays close before pause/map; the process scene stays alive; complete campaign/profile/settings and the pinned Challenge run survive. This is a desktop simulated event path, **not native Android KEYCODE_BACK, predictive gesture or phone evidence**.

- Frozen code3: both policy assertions fail, then the Window signal exits before suite completion. Expected failure is preserved under `.artifacts/code4/baseline-code3.{log,json}`.
- Code4:67headless/71rendered checks,16Back requests and4rendered captures per run. Settings/transfer/guide/forecast, pause/map and Challenge return/resume are covered.
- Evidence and source delta: `evidence/code4-back.json`; ignored captures/logs/source copies under `.artifacts/code4/`.

The code3 source/evidence packet remains frozen. Full suites were not repeated for the two-line policy change; the coordinator independently verified them on code3. Next is coordinator-owned signed code4 export, install-over-code3 preservation and actual native Android Back/gesture validation. Human duration/fun and physical Fold7 checks remain open.
