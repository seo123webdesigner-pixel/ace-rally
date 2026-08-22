# CLAUDE.md

Project context and standing rules for Claude Code. Read this file before every task.

---

## 1. What we are building

**Working title:** Ace Rally (rename later)

A 3D mobile tennis game for Android. Single player against AI opponents. Arcade feel, not simulation. The reference points are Tennis Clash, Ultimate Tennis 3D and Stick Tennis: assisted player positioning, swipe to aim, timing window decides shot quality.

**Target:** Android 8.0+ (API 26), 60 fps on a mid-range device (Snapdragon 6-series, 4 GB RAM).

**v1 scope:** playable match, serve, rally, full tennis scoring, 5 AI opponents across 3 difficulty tiers, 4 unlockable courts, racket stats, local save. No multiplayer. No IAP. No ads. No backend.

**Explicitly out of scope for v1:** online play, doubles, tournaments with brackets, character customisation, cloud save, analytics SDKs.

---

## 2. Stack and versions

| Thing | Choice |
|---|---|
| Engine | Godot 4.4 stable |
| Language | GDScript only. No C#, no GDExtension unless a sprint says otherwise |
| Renderer | Mobile |
| Physics | Custom deterministic integration for the ball. Godot physics only for coarse collision queries |
| Tests | GUT (Godot Unit Test) 4.x in `res://test/` |
| Version control | Git, conventional commits |

---

## 3. Non-negotiable architecture rules

1. **The ball is not a RigidBody3D.** It is a `Node3D` with manual integration in `_physics_process`. The AI must be able to predict the landing point by re-running the same integrator forward. Godot's rigid body solver is not deterministic enough for that.
2. **Simulation and presentation are separate.** Gameplay logic lives in plain GDScript classes with no node dependencies wherever possible. Nodes read from the simulation, never the other way round.
3. **Scoring is a pure class.** `Scoreboard` takes point events in and emits state out. It has zero references to nodes, scenes or the tree. It is fully unit tested.
4. **All tunable numbers live in Resources**, not in code. `BallPhysicsConfig`, `ShotConfig`, `AIDifficultyConfig`, `CourtSurfaceConfig`. Designers tune in the inspector. Never hardcode a magic number in a script.
5. **One autoload maximum per concern.** Current allowed autoloads: `GameState`, `SaveManager`, `AudioManager`, `EventBus`. Do not add more without asking.
6. **Signals go through `EventBus`** for cross-system events (point scored, game won, ball bounced). Direct signals are fine for parent-child within one scene.
7. **Fixed timestep.** `physics_ticks_per_second = 60`. All gameplay runs in `_physics_process`. Never use `_process` for anything that affects the simulation.

---

## 4. Code standards

- Static typing everywhere. `var speed: float = 0.0`, `func hit(power: float) -> void:`
- `class_name` on every reusable class.
- `@export` for anything a designer touches. `@onready` for node refs.
- snake_case for files, variables and functions. PascalCase for classes and node names.
- One class per file. File name matches the class name in snake_case.
- No `get_node("../../Something")`. Use `@export var target: Node3D` or a group lookup.
- Comment the *why*, not the *what*. Do not write a comment that restates the line below it.
- Guard clauses over nested ifs.

**Folder layout:**

```
res://
  assets/          # models, textures, audio, fonts (imported)
  scenes/
    core/          # main, game, match
    court/
    characters/
    ball/
    ui/
  scripts/
    sim/           # pure logic, no nodes
    gameplay/
    ai/
    ui/
    systems/       # save, audio, state
  resources/       # .tres config files
  test/            # GUT tests
  addons/
```

---

## 5. How I want you to work

- **Do the sprint that was given, nothing more.** If you spot something out of scope, write it into `NOTES.md` under "Deferred" and move on.
- **State assumptions before you code.** If a spec is ambiguous, list your interpretation in one or two lines, pick the most reasonable option and proceed. Do not stop and ask unless it is genuinely blocking.
- **Verify before you claim done.** Run the verification command in the sprint. Paste real output. Never say a thing works if you did not run it.
- **Small commits.** One logical change per commit. Message format: `feat(ball): add magnus force to integrator`.
- **When a file gets past ~300 lines, split it.**
- **Never delete or rewrite a passing test to make your code pass.** Fix the code.
- **No placeholder stubs left behind.** If you cannot finish something, say so plainly in the summary.

---

## 6. Real court dimensions (use these exactly)

| Measurement | Value |
|---|---|
| Court length (baseline to baseline) | 23.77 m |
| Singles width | 8.23 m |
| Doubles width | 10.97 m |
| Service line from net | 6.40 m |
| Net height at post | 1.07 m |
| Net height at centre | 0.914 m |
| Ball mass | 0.057 kg |
| Ball radius | 0.0335 m |

World origin sits at the centre of the net. +Z runs toward the player's baseline. +Y is up. +X is court right from the player's view.

---

## 7. Asset rules

All assets must be free and commercially usable. Sources approved:

- **Mixamo** (character models and animations, free with Adobe account, royalty free)
- **Kenney.nl** (CC0, UI and props)
- **Poly Pizza** (mostly CC-BY, attribution required)
- **Quaternius** (CC0, low-poly characters)
- **freesound.org** (check each licence individually)

Every asset goes in `CREDITS.md` on the day it is added: file, source, author, licence, URL. If you cannot confirm the licence, do not use the asset.

Do not download assets yourself. When a sprint needs an asset, generate placeholder primitives that match the final dimensions and list exactly what I need to fetch in `ASSETS_NEEDED.md`.

---

## 8. Performance budget

- 60 fps target, 33 ms worst frame
- Under 150 draw calls per frame
- Under 80k triangles on screen
- Textures: 1024x1024 max for characters, 2048 for the court atlas, ETC2/ASTC compressed
- No dynamic lights beyond one directional. Bake the rest.
- Object pool the ball trail, hit particles and crowd sprites. No `instantiate()` during a rally.

---

## 9. Verification commands

```bash
# Parse check, catches script errors across the project
godot --headless --quit --path .

# Run the test suite
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit

# Android release build
godot --headless --path . --export-release "Android" build/acerally.apk
```

---

## 10. Definition of done for any sprint

1. Project opens with zero errors and zero warnings in the Godot console.
2. All GUT tests pass.
3. The sprint's acceptance criteria are each demonstrably met, verified by running the game.
4. `NOTES.md` updated with what changed, what was deferred and any tuning values that need a human eye.
5. Committed with a clean message.
