# NOTES

Running log of what changed each sprint, what was deferred, and any tuning value
that still needs a human eye. Newest sprint at the top.

---

## Sprint 0 — Project scaffold

### What changed
- `project.godot` written by hand: mobile renderer, 60 physics ticks, 60 max fps,
  1920x1080 viewport, `canvas_items` / `expand` stretch, landscape, ETC2/ASTC on.
- Folder structure per CLAUDE.md section 4, `.gitkeep` in every empty folder.
- GUT 9.7.1 installed to `addons/gut/`, plugin enabled in `project.godot`.
- Five autoloads registered in order: `GameState`, `SaveManager`, `AudioManager`,
  `EventBus`, `GameLog`.
- `scenes/core/main.tscn` set as the main scene, reports the runtime environment on ready.
- `test/test_smoke.gd`, `scripts/verify.sh`, `scripts/verify.ps1`, CI workflow.

### Deviations from the sprint brief, and why

1. **The `Logger` autoload is registered as `GameLog`.**
   `Logger` is a built-in class in Godot 4.7 (`ClassDB.class_exists("Logger") == true`,
   extends `RefCounted`). The engine refuses `class_name Logger` with
   `Parse Error: Class "Logger" hides a native class`, and worse, the bare identifier
   `Logger` in any script resolves to the *native* class rather than to the autoload,
   which failed with `Static function "info()" not found in base "GDScriptNativeClass"`.
   The file stays at the specified path `scripts/systems/logger.gd`.
   Call it as `GameLog.info("system", "message")`.

2. **Autoload scripts use a `...Singleton` suffix for `class_name`.**
   Godot 4 rejects a `class_name` that matches an autoload name
   (`Parse Error: Class "GameState" hides an autoload singleton`). The autoload names
   are unchanged, so gameplay code still writes `EventBus.ball_hit.connect(...)`.
   The class names exist only so the singletons can be statically typed:
   `GameStateSingleton`, `SaveManagerSingleton`, `AudioManagerSingleton`,
   `EventBusSingleton`, `GameLogSingleton`.

3. **`verify.sh` greps the parse-check output instead of trusting its exit code.**
   Measured on 4.7.2: `godot --headless --quit --path .` **exits 0 even when scripts
   fail to parse**. An early run here returned exit 0 while printing five parse errors.
   The exit code alone is not a gate, so the script also scans for
   `SCRIPT ERROR:` / `ERROR:` / `FATAL:` line prefixes.

4. **`verify.sh` runs `--headless --import` before anything else.** On a fresh clone
   GUT's global class names are not in `.godot/global_script_class_cache` and
   `gut_cmdln.gd` aborts with `Some GUT class_names have not been imported`. Without
   this step CI cannot pass on a clean checkout.

5. **Project-wide parse checking is a test, not a verify.sh step.**
   `godot --headless --quit --path .` only loads scripts reachable from the main scene
   and the autoloads, so a broken file that nothing references yet slips through
   (measured). The obvious fix, running `--check-only -s` per file from outside, does
   **not** work: autoload identifiers are not registered in that mode, so
   `scripts/systems/main.gd` failed with `Identifier not found: GameLog` even though it
   is fine. `test/test_all_scripts_parse.gd` loads every `.gd` under `res://scripts` and
   `res://test` from inside the running project instead, where the autoloads exist.
   Verified to fail correctly: an unreferenced broken script makes `verify.sh` exit 1.

6. **A third smoke test was added.** `test_main_reports_its_runtime_environment`.
   Since the game window is not observable, this is the only proof that the entry
   point's log line is actually populated with the four required facts.

### Needs a human eye
- `display/window/handheld/orientation` is set to the string `"landscape"` as specified.
  Godot 4.7's own default for that setting is the **int enum** `0` (= Landscape).
  The string is accepted at runtime and reads back correctly, but the editor will
  probably normalise it to `0` the first time Project Settings is saved, and the
  Android exporter reads this key when writing `android:screenOrientation`.
  Same intent either way. Revisit at Sprint 12.

### Deferred
- `assets/`, `resources/`, and the `scenes/` and `scripts/` subfolders are empty
  placeholders. No gameplay code, no 3D scenes, per the sprint brief.
- GUT's editor panel is enabled but untested, as it needs the editor UI.
