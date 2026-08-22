# NEEDS HUMAN CHECK

Things Claude cannot verify because it cannot see the game window. Each item says what
to look at and what "correct" looks like. Clear the list and report back; resolved items
get deleted, not ticked.

---

## Sprint 1 — Ball simulation and court geometry

Open `scenes/core/physics_lab.tscn` and press F6. Controls: **right-mouse drag** to look,
**WASD** to fly, **Q/E** down and up, **shift** to move faster. The panel has sliders for
speed, angle, spin magnitude and spin axis, a surface dropdown and a FIRE button.

1. **The court looks like a tennis court, at the right size.**
   *Correct:* lines crisp and white with no shimmering or flickering where they meet the
   surface (they are stacked at three different heights specifically to avoid that). Net
   spans past the singles lines to posts standing outside the doubles lines. The blue
   in-play area is ringed by a darker run-off area on all four sides.

2. **No z-fighting anywhere.** Fly the camera low and along the surface, then look at the
   court from far away and at a shallow angle.
   *Correct:* the lines stay solid at every distance and angle. Any strobing or
   patchiness where a line meets the court is a failure — tell me and I will raise the
   0.002 / 0.005 m stacking offsets in `court.tscn`.

3. **The predicted landing ring sits under the ball at the moment of first bounce.**
   Fire on each of the four surfaces, with and without spin. This is the acceptance
   criterion that matters most.
   *Correct:* the ring is exactly under the ball as it lands, every single time, on
   every surface. The readout's `error` line should read **0.0000 m**. A headless test
   already asserts this is zero, so if you can see daylight between ring and ball, the
   discrepancy is in the rendering, not the physics — tell me.

4. **The ring is green when the shot is in and red when it is out.**
   Fire at 45 degrees to send one long.
   *Correct:* colour matches where it actually lands relative to the lines.

5. **A shot at 30 m/s and 12 degrees lands near the far baseline.**
   The panel's defaults. *Correct:* it clears the net comfortably and lands roughly a
   metre inside the far baseline. The readout gives the exact depth.

6. **THE BIG ONE: does the arc read as tennis, or as golf?**
   Fire hundreds of shots across the speed and angle ranges. This is the twenty minutes
   that everything downstream inherits.
   *What to look for:* a flat drive should look like a drive, not a lob; the ball should
   fall out of the sky at the end rather than sailing flat; topspin should visibly dip
   and kick forward; backspin should float and skid.
   *My starting suspicions,* with the reasoning in `NOTES.md`:
   - `bounce_spin_transfer` 0.4 is probably about twice too strong; try **0.2**.
   - `magnus_coefficient` 0.000045 is probably a little hot — 3000 rpm of backspin
     currently adds 8 m of carry.
   - `gravity` 13.5 and `drag_coefficient` 0.55 I would leave alone first.
   Edit `resources/ball_physics_default.tres` and the four files in
   `resources/surfaces/`. **Tell me the values you land on** and I will write them into
   `NOTES.md` and update `test_physics_resources.gd`, which is the one test file a tune
   is meant to break.

7. **Frame time stays under 5 ms.** Read the top-left overlay while firing.
   *Correct:* `process` and `physics` both under 5 ms, 60 fps, draw calls around 20.
   The simulation side is already proven headlessly at 11.4 us per frame, so anything
   over budget here is rendering.

8. **The ball is visible and readable at gameplay distance.**
   *Correct:* the ball reads clearly from the baseline camera. It is drawn at 5 cm
   against a real 3.35 cm; if it still looks like a dot, raise `visual_radius` on
   `ball.tscn`. The shadow blob should stay under it and shrink as it climbs.

9. **The net sag looks right.** Look down the net from one post.
   *Correct:* it dips toward the centre. Known approximation: three segments, so the
   ends read about 0.98 m rather than the true 1.07 m at the posts, and it steps rather
   than curving. Tell me if the stepping is obvious enough to need five segments.

---

## Sprint 0 — Project scaffold

1. **The project imports with no errors.**
   Open `C:\dev\ace-rally` in the Godot 4.7.2 editor.
   *Correct:* the project opens, and the Output and Errors docks are empty. No red
   entries, no "resource file not found", no missing-script warnings on `main.tscn`.

2. **The five autoloads appear in Project Settings.**
   Project > Project Settings > Globals (Autoload).
   *Correct:* exactly five rows, enabled, in this order:
   `GameState`, `SaveManager`, `AudioManager`, `EventBus`, `GameLog`.
   Note the last one is `GameLog`, not `Logger` — `Logger` is a built-in Godot 4.7
   class name and the engine rejects it. See NOTES.md, Sprint 0, deviation 1.

3. **`main.tscn` runs and prints its log line.**
   Press F5 (or open `scenes/core/main.tscn` and press F6).
   *Correct:* a 1920x1080 landscape window opens, empty and black, and the Output dock
   shows exactly these four lines:
   ```
   [INFO][main] godot version: 4.7.2-stable (official)
   [INFO][main] physics ticks per second: 60
   [INFO][main] renderer: mobile
   [INFO][main] headless: false
   ```
   `headless: false` is the expected value when run from the editor. It reads `true`
   under `--headless`.

4. **The GUT panel loads in the editor.**
   Bottom dock, "GUT" tab.
   *Correct:* the panel appears without errors and lists `res://test/test_smoke.gd`.
   The plugin is enabled in `project.godot` but has only ever been exercised headlessly.

5. **The renderer really is Mobile.**
   Project Settings > Rendering > Renderer, and the bottom-right of the editor window.
   *Correct:* "Mobile". Confirmed via `ProjectSettings.get_setting` headlessly, but the
   editor is the place to be sure nothing overrode it.

6. **`display/window/handheld/orientation` survives a settings save.**
   Open Project Settings, change anything, save, then check the key still means landscape.
   *Correct:* the project still runs landscape. It is currently the string `"landscape"`
   as specified in the brief, while Godot's native default for that key is the int `0`.
   If the editor rewrites it to `0`, that is fine and expected. See NOTES.md.
