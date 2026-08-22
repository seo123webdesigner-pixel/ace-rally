# ASSETS NEEDED

Assets the human needs to fetch and drop in. Claude does not download assets; it
generates placeholder primitives at the correct dimensions and lists the real thing here.
Each entry: what it is, where to get it, the licence, and where it goes in the repo.

---

## Sprint 1 — court and ball

Everything this sprint added is a primitive at the correct real-world dimension, so a
real asset can be dropped in without moving any geometry. Nothing here blocks gameplay;
the placeholders are functional.

| What | Currently | Wanted | Source | Notes |
|---|---|---|---|---|
| Court surface texture | Flat blue `StandardMaterial3D` on a box | 2048x2048 hard-court atlas, ETC2/ASTC | Kenney.nl (CC0) or a photo-sourced CC0 texture | Must keep the painted lines as separate geometry; they are measured, not textured |
| Tennis ball texture | Flat yellow, no seam | 256x256 ball albedo with the seam | Poly Pizza / Quaternius | Needed before spin reads visually — the ball currently does not rotate, so topspin is invisible until it bounces |
| Net mesh | Three solid boxes | Net with an alpha-cut mesh weave and a white top band | Kenney.nl (CC0) or Poly Pizza (CC-BY) | Real net height is 1.07 m at the posts, 0.914 m at centre; posts sit at x = +/-6.399 |
| Net posts | Two boxes, 0.10 m square | Cylindrical posts, 1.07 m | Quaternius (CC0) | |
| Ball bounce audio | None | Four one-shots, one per surface | freesound.org, licence checked per file | `EventBus.ball_bounced` already emits position and `surface_type`, and `BounceEvent.impact_speed()` is there to drive volume |
| Ball trail | `GPUParticles3D` of tiny spheres | A soft additive streak texture | Kenney.nl (CC0) | Pool is already fixed-size; only the draw pass needs replacing |
| Shadow blob | Flat black quad | Soft-edged radial alpha texture | Kenney.nl (CC0) | |

**Dimensions to build against** are in `CLAUDE.md` section 6 and mirrored as constants in
`scripts/sim/court_dimensions.gd`. Do not re-measure from the placeholder meshes.

Nothing has been downloaded. Add each file to `CREDITS.md` on the day it lands.
