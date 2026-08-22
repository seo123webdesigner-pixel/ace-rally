# NOTES

Running log of what changed each sprint, what was deferred, and any tuning value
that still needs a human eye. Newest sprint at the top.

---

## Sprint 1 — Ball simulation and court geometry

### What changed

- `scripts/sim/` now holds the whole physics layer, with zero node references:
  `BallPhysicsConfig`, `CourtSurfaceConfig`, `CourtDimensions`, `BallState`,
  `BounceEvent`, `LandingPrediction`, `BallSimulator`.
- `resources/ball_physics_default.tres` and four surfaces in `resources/surfaces/`.
- `scenes/court/court.tscn` (18 draw calls, all primitives), `scenes/ball/ball.tscn`,
  `scenes/core/physics_lab.tscn` with a free-look camera and a tuning panel.
- 58 new tests across `test_ball_simulator.gd`, `test_court.gd`,
  `test_physics_resources.gd`, `test_scenes.gd`, `test_sim_performance.gd`.
- `project.godot`: restored the explicit `common/physics_ticks_per_second=60` that the
  working tree had dropped.

### Deviations from the sprint brief, and why

1. **`delta_scale` in the bounce kick was undefined; it is now the ball radius.**
   The brief's `horizontal += spin.cross(UP) * bounce_spin_transfer * delta_scale` never
   defines `delta_scale`. Unscaled it is catastrophic: 314 rad/s of topspin gives a
   **120 m/s** kick. If it meant the timestep, the kick would be twice as large at 1/60
   as at 1/120 and prediction could never match the sim.
   Now `spin.cross(UP) * bounce_spin_transfer * radius`, which is the contact patch's
   surface velocity, so `bounce_spin_transfer` means the fraction of it that becomes
   travel. Timestep-free. **Measured: at 314 rad/s on hard, outgoing horizontal is
   17.63 m/s where friction alone gives 13.50 — a 4.13 m/s kick.** See tuning below.

2. **Sim and prediction both run fixed 1/120 substeps.**
   The brief has the sim at 1/60 and prediction at 1/120. Semi-implicit Euler has O(dt)
   error, so that mismatch costs roughly 0.1 m over a 20 m shot — twice the 0.05 m the
   brief asks for, and visible as a ring that never quite sits under the ball.
   `BallSimulator` now owns `SIM_DT = 1/120`; `step()` accumulates whatever delta it is
   given and runs whole substeps, and prediction runs the identical loop on a copy.
   **Measured landing error: 0.000000000 m on every surface, at every point in the
   flight, including mid-flight re-prediction.** The accumulator stays at exactly 0.0
   because 1/120 is exactly half of 1/60 and halving is exact in binary floating point.

3. **A bounce is resolved at the exact crossing, not at the end of the substep.**
   The brief checks `position.y <= radius` after the position update and snaps. That
   reports every landing up to `v_x * dt` long — 0.25 m at 30 m/s — and that point is
   what a line call is judged against. The substep is now rewound to the moment `y`
   crossed the radius, the bounce resolved there, and the remainder re-advanced.

4. **Bounces scrub spin, and `is_live` is gated on vertical speed too.**
   As specified, a spinning ball never dies. Bounce intervals shrink geometrically so
   total remaining flight time converges, meaning spin never fully decays; the residual
   kick then re-feeds horizontal speed against friction and converges to a ~5.5 m/s ball
   that is permanently above `min_bounce_speed`. `test_ball_goes_dead_after_repeated_bounces`
   would have hung. Fixed by taking `bounce_spin_transfer` off the spin at each bounce
   (that energy left the rotation) and by testing the post-bounce **vertical** speed,
   which decays geometrically whatever the spin does. **Measured: settles in 9–12
   bounces and under 4.2 s on all three surfaces with 400 rad/s of topspin.**

5. **`CourtDimensions.LINE_CALL_EPSILON` exists because `Vector3` is 32-bit.**
   Godot stores `Vector3` components as float32 while GDScript constants are float64.
   `Vector3(0, 0, 11.885).z` reads back as **11.88500022**, i.e. past the baseline, so
   "a ball exactly on the line" was being called out by a rounding error. Boundary
   comparisons now absorb 0.1 mm, which is far below anything meaningful on a tennis
   court and makes a ball on the line reliably in, as the real rule says.

6. **`BallState` was added, and it is load-bearing.**
   Not in the brief. It exists so `_substep()` can be one static function that the live
   ball and a throwaway prediction copy both go through. There is deliberately exactly
   one copy of the integrator in this project; that is what makes prediction exact.
   Never add a second "just for prediction".

7. **Magnus and spin decay kept as specified, though both are unphysical.**
   Magnus is `C * (spin x v) / mass`, which is linear in speed where real Magnus is
   quadratic, so it bites proportionally harder at low ball speeds. At the reference
   point it is about right (7.1 m/s² of dip at 314 rad/s and 30 m/s, against a real
   8.4). Spin decay of 0.85/s is roughly 10x reality, but flights are ~1 s so the
   in-flight effect is small and it helps the ball settle. Both are arcade choices;
   flagging them so nobody later reads them as bugs.

8. **`CourtDimensions` was added rather than putting the numbers on the `Court` node.**
   `predict_landing` has to answer "is that in?" without a scene tree. The measurements
   live once, in the sim layer, and `Court` delegates every query to them.
   `EventBus.ball_bounced` was left untouched: `CourtSurfaceConfig` gained a
   `SurfaceType` enum so the existing `(Vector3, int)` signature still fits.

9. **`verify.sh` and `verify.ps1` now read the GUT output, not just its exit code.**
   Hit for real this sprint: a parse error in `test_scenes.gd` made GUT print a warning,
   skip the entire file, report **"All tests passed!"** and exit 0 — costing 10 tests
   silently. Both scripts now fail on `Ignoring script` / `Parse Error:` / `SCRIPT ERROR:`
   in the GUT output and additionally require the success line to be present. Verified
   by breaking a test file on purpose: `verify.sh` exits 1.

### Tuning: what the numbers actually do

Measured at the shipped defaults, 30 m/s at 12 degrees from the baseline at 1.0 m:

| Quantity | Value |
|---|---|
| Range | 22.75 m, landing 1.02 m inside the far baseline |
| Flight time | 0.995 s |
| Apex | 2.20 m, reached just past the net |
| Height crossing the net | 2.17 m |
| Same shot in vacuum | 31.08 m, so drag costs 8.3 m |
| 314 rad/s topspin | 17.74 m |
| 314 rad/s backspin | 30.73 m |

**These are the numbers the twenty-minute lab session should move.** Nothing in the test
suite will fight a retune: `test_ball_simulator.gd` builds its own pinned config, so it
tests the integrator rather than the feel. `test_physics_resources.gd` is the one file a
tune is expected to break — update the expected values there and this table together.

Starting opinions, to be confirmed by eye:

- **`bounce_spin_transfer = 0.4` is probably about twice too strong.** It was written
  against a `delta_scale` that appears to have meant 1/60; the radius form gives roughly
  double that. Expect to land near **0.2**.
- **`magnus_coefficient = 0.000045` is probably a little hot.** 3000 rpm of backspin
  adding 8 m of carry, taking the ball 7 m past the baseline, is a lot; the apex also
  climbs from 2.20 m to 3.00 m. If backspin feels floaty, this is the knob.
- **`gravity = 13.5` and `drag_coefficient = 0.55` look right** and are worth leaving
  alone first. The 2.20 m apex on a drive reads as a tennis arc rather than a golf one.
  If the ball feels floaty, raise gravity before touching drag; drag is already doing
  physically correct work (18.5 m/s² of deceleration at 30 m/s, which is real).

### Cost

Measured headlessly, against a 16666 us frame at 60 fps:

- `step()` at 1/60 (two substeps): **11.4 us**, 0.07% of a frame
- `predict_landing()` over a 5 s window: **332–426 us**
- an entire flight from launch to rest (213 frames): **3019 us**, under one frame

### Deferred

- **Net collision.** `crosses_net_plane()` answers whether the segment passed through
  the net's plane, and nothing more. A ball that hits the tape currently sails through.
  `CourtDimensions.net_height_at()` is there ready for it.
- **Ball-radius tolerance on line calls.** `is_in_bounds` takes a `tolerance` and every
  caller passes 0.0, judging the contact point strictly. Passing the ball radius gives
  the real "any part touching the line" rule. A feel decision for the line-call sprint.
- **The three-segment net is a coarse sag.** Segment heights come from the parabola at
  each segment's midpoint, so the posts read 0.983 m rather than 1.07 m. Fine as a
  placeholder, wrong if anyone measures it on screen.
- **`predict_landing` judges singles only** and takes no argument for it.
- **Spin is not shown on the ball.** The mesh does not rotate, so topspin and backspin
  are invisible until the bounce. Needs a texture with a seam before it would read.
- **No net band, no court texture, no crowd.** All primitives; see `ASSETS_NEEDED.md`.
- Sprint 0's deferred items still stand: `GameLog` has no unit test, and `GameState`,
  `SaveManager` and `AudioManager` are still empty shells.

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
- `GameLog` has no unit test yet. Its level filtering and `[LEVEL][system] message`
  format were verified by a throwaway headless probe, not by a committed test.
  Worth a real test the first time a sprint depends on log output.
- `GameState`, `SaveManager` and `AudioManager` are empty shells. They declare their
  single responsibility in a doc comment and nothing else, by design for this sprint.
