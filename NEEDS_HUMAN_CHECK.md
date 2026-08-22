# NEEDS HUMAN CHECK

Things Claude cannot verify because it cannot see the game window. Each item says what
to look at and what "correct" looks like. Clear the list and report back; resolved items
get deleted, not ticked.

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
