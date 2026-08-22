# Ace Rally

A 3D arcade tennis game for Android. Single player against AI opponents. Assisted
positioning, swipe to aim, and a timing window that decides shot quality — closer to
Tennis Clash or Stick Tennis than to a simulation.

**Status:** Sprint 0. Project scaffold only. There is no gameplay yet — `main.tscn`
starts up, reports its runtime environment to the log, and stops there.

**Target:** Android 8.0+ (API 26), 60 fps on a mid-range device.

---

## Prerequisites

- **Godot 4.7.2 stable**, on `PATH` as `godot`. The version is pinned; do not upgrade
  it as a side effect of another task.
  ```bash
  godot --version   # must print 4.7.2.stable.official.ed1daf0bf
  ```
- **Git**, and Git Bash if you want to run the `.sh` scripts on Windows.
- No Android SDK is needed yet. See "Android export" below.

Everything else, including the GUT test addon, is committed to the repo.

---

## Running the verification suite

This is the gate for every sprint. It imports assets, parse-checks the project, then
runs the full GUT suite (which includes a test that loads every script in the project).
It stops at the first failure and exits non-zero, so it is also what CI runs.

Git Bash, macOS or Linux:

```bash
bash scripts/verify.sh
```

Windows PowerShell:

```bash
powershell -ExecutionPolicy Bypass -File scripts/verify.ps1
```

If Godot is not on `PATH`, point the scripts at it with the `GODOT` environment
variable instead of editing them.

### Running the pieces by hand

```bash
godot --headless --import --path .
```

```bash
godot --headless --quit --path .
```

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
```

> **Note:** `godot --headless --quit --path .` exits 0 *even when scripts fail to
> parse*. Read its output, or use `verify.sh`, which greps for error markers. Do not
> trust its exit code on its own.

---

## Opening it in the editor

1. Launch Godot 4.7.2.
2. **Import**, then select `C:\dev\ace-rally\project.godot`.
3. Open it. The first import populates `.godot/`, which is gitignored.
4. Press **F5** to run the main scene. Expect an empty black landscape window and four
   `[INFO][main]` lines in the Output dock.

The GUT panel lives in the bottom dock under the **GUT** tab.

If the editor reports missing GUT classes, or `gut_cmdln.gd` complains that
`Some GUT class_names have not been imported`, run `godot --headless --import --path .`
once and restart the editor. That populates the global class cache.

---

## Layout

```
res://
  assets/          models, textures, audio, fonts
  scenes/          core, court, characters, ball, ui
  scripts/
    sim/           pure logic, no nodes, fully unit testable
    gameplay/
    ai/
    ui/
    systems/       save, audio, state, logging
  resources/       .tres config files, all tunable numbers live here
  test/            GUT tests
  addons/gut/      GUT 9.7.1
```

## Autoloads

| Autoload | Script | Responsibility |
|---|---|---|
| `GameState` | `scripts/systems/game_state.gd` | Session-scoped game state |
| `SaveManager` | `scripts/systems/save_manager.gd` | Local profile read/write |
| `AudioManager` | `scripts/systems/audio_manager.gd` | Buses and sound playback |
| `EventBus` | `scripts/systems/event_bus.gd` | Cross-system signals, nothing else |
| `GameLog` | `scripts/systems/logger.gd` | Levelled logging to stdout |

`GameLog` is named that way because `Logger` is a built-in Godot 4.7 class and the
engine will not let a script or an autoload shadow it. Usage:

```gdscript
GameLog.info("ball", "bounce at %s" % position)
```

Levels are `DEBUG`, `INFO`, `WARN`, `ERROR`, output as `[LEVEL][system] message`, all
on stdout so a headless run reads as one ordered stream. The default level is `INFO`.

---

## Android export

**Sprint 12 only.** Do not install the Android SDK, add export presets, or attempt a
build before then. `build/`, `*.keystore` and `export_credentials.cfg` are already
gitignored in preparation.

---

## Conventions

See `CLAUDE.md` for the full rules. The ones that bite most often:

- The ball is a `Node3D` with manual integration, never a `RigidBody3D`.
- All gameplay runs in `_physics_process` at a fixed 60 Hz. Never `_process`.
- Every tunable number lives in a `Resource`, not in a script.
- Scoring is a pure class with no node references, and is unit tested.
- Static typing everywhere.

## Companion documents

| File | What goes in it |
|---|---|
| `NOTES.md` | What changed each sprint, what was deferred |
| `NEEDS_HUMAN_CHECK.md` | Anything needing eyes on a real screen |
| `ASSETS_NEEDED.md` | Assets the human must fetch |
| `CREDITS.md` | Source, author and licence for every third-party file |
