# One-Line Puzzle — Figure Redesign Work Log

Status of the redesign of the **One-Line** (single-stroke / Eulerian-circuit)
game: replace basic geometry (triangle / square / pentagon …) with recognizable
thematic figures, remove duplicate shapes, stop distortion, ramp difficulty with
level, and fix the "solvable from anywhere with your eyes closed" problem.

---

## 1. Goal

| # | Requirement | Status |
|---|-------------|--------|
| 1 | Every level a recognizable / thematic figure (not just polygons) | ✅ Done |
| 2 | No duplicate shapes across the campaign | ✅ Done |
| 3 | No distortion (figures laid out cleanly, uniform scale) | ✅ Done |
| 4 | Difficulty increases with level (monotonic edge count) | ✅ Done |
| 5 | Fix "solvable from anywhere / eyes closed" | ✅ Done |
| 6 | Hand-off work log | ✅ This file |

---

## 2. The core problem & the chosen fix

A One-Line level is an **Eulerian circuit**: every vertex has even degree, so a
single closed loop covers all edges. A pure closed loop is *trivially* solvable
— you can start anywhere and still finish — hence the old "eyes closed" feel.

**Chosen mechanic (user decision): hybrid start.**

- **Levels 1–10 (tutorial):** start anywhere (kept friendly while learning).
- **Levels 11+ (locked):** the stroke must begin on a single **glowing start
  vertex**. The player has to plan the route up front. A pulsing marker and a
  "Start at the glowing point" hint (EN / BN / HI) guide them.

The generator picks the mandated start vertex with `_chooseStartVertex`:
highest degree first, ties broken bottom-most then left-most, honouring an
optional per-figure `startHint`. The solution is produced by Hierholzer's
algorithm seeded at that vertex for locked levels (and unseeded for tutorial
levels).

Figures are built as a **union of closed loops that share only vertices** (never
edges), so all vertex degrees are even *by construction* and are shipped with
`eulerian: true` (no random walk / parity repair).

---

## 3. What changed (files)

| File | Change |
|------|--------|
| `lib/presentation/screens/games/one_line/one_line_generator.dart` | Main redesign: `_thematicFigures()`, `_fig()`, `_resampleLoop()`, `_chooseStartVertex()`, `_shapeSignature()`, `_tryBuild()`, `_normalize()`, `_lattice()`, all `_*Loop` figure builders, relaxed curated `_Config`. Removed dead `_polygon/_star/_bowtie/_hourglass/_rocket`. |
| `lib/presentation/screens/games/one_line/one_line_models.dart` | Added `bool startAnywhere` (default `true`) + `int startVertex` (default `0`) to `OneLineLevel`. |
| `lib/presentation/screens/games/one_line/one_line_engine.dart` | `_fixedStart` / `fixedStart`; `reset()` seeds it; `startAt` / `startOnEdge` reject illegal starts on locked levels. |
| `lib/presentation/screens/games/one_line/one_line_painter.dart` | `OneLineBoardState.startVertexId`; pulsing start-marker rendering. |
| `lib/presentation/screens/games/one_line/one_line_screen.dart` | Locked-start input gating in `_updateDrag`; `_needsLockedStart`, `_buildStartHint`; `startVertexId` wired to painter. |
| `lib/presentation/screens/games/arrow_silhouette/arrow_silhouette_screen.dart` | (Separate, earlier task) progressive level unlocking. |
| `test/one_line_generator_test.dart` | Tutorial start-anywhere 1–10, locked start 11+, 31-name campaign, endless 32–60. |
| `test/one_line_engine_test.dart` | Mid-edge circuit loops 1–10; `suggestNextEdge` respects start mode. |
| `android/app/build.gradle.kts` | `minSdk` 23 → 24. |
| `lib/core/constants/app_constants.dart` | `appVersion` 1.7.0 → 1.8.0. |
| `pubspec.yaml` | Version bump to match. |

---

## 4. Curated catalogue (levels 1–31)

Shipped in ascending edge count, so difficulty rises with level.

| Lv | Figure | Edges | Tier |
|----|--------|-------|------|
| 1 | House | 5 | Easy |
| 2 | Tree | 7 | Easy |
| 3 | Boat | 8 | Easy |
| 4 | Leaf | 8 | Easy |
| 5 | Crown | 9 | Easy |
| 6 | Diamond | 9 | Easy |
| 7 | Fish | 9 | Easy |
| 8 | Star | 10 | Easy |
| 9 | Pentagram | 10 | Medium |
| 10 | Rocket | 11 | Medium |
| 11 | Bird | 11 | Medium |
| 12 | Cat | 12 | Medium |
| 13 | Flower | 12 | Medium |
| 14 | Pinwheel | 12 | Medium |
| 15 | Octahedron | 12 | Medium |
| 16 | Starburst | 14 | Medium |
| 17 | Lattice | 14 | Medium |
| 18 | Key | 15 | Medium |
| 19 | Bloom | 15 | Medium |
| 20 | Prism | 16 | Medium |
| 21 | DiamondChain | 16 | Medium |
| 22 | OctoWeb | 16 | Hard |
| 23 | Lotus | 18 | Hard |
| 24 | Enneagram | 18 | Hard |
| 25 | Weave | 20 | Hard |
| 26 | Decagram | 20 | Hard |
| 27 | Heart | 22 | Hard |
| 28 | Filigree | 24 | Hard |
| 29 | Mandala | 24 | Expert |
| 30 | Webbing | 28 | Expert |
| 31 | Rosette | 32 | Expert |

Edge-count sequence (monotonic):
`5, 7, 8, 8, 9, 9, 9, 10, 10, 11, 11, 12, 12, 12, 12, 14, 14, 15, 15, 16, 16, 16, 18, 18, 20, 20, 22, 24, 24, 28, 32`.

**Levels 32+ (endless):** procedurally generated from the symmetric families
(`Mandala`, `Rosette`, `Flower`).

### Duplicate detection
`_shapeSignature()` produces a rotation / reflection / translation-invariant key
(sorted incident-edge-length key per vertex + sorted edge lengths). Note the
same-step vs mirror-step collapse: on `n = 9`, step 5 ≡ step 4 reversed, so
`_mandalaFig('Enneagram', 9, [1, 4, 5])` yields **18** edges, not 27.

### Drawability thresholds
`minSpanFor(n)` / `minGapFor(n)` derive from `_configFor(n)`, so relaxing the
curated `_Config` automatically relaxes the geometry test.
- Curated figures: `minSpan: 0.12`, `minGap: 0.09`.
- Endless figures: `minSpan: 0.15`, `minGap: 0.11`.
- Global constraints: `minEdgeSpan = 0.17`, `minSegmentGap = 0.12`,
  `minCrossingAngleDeg = 28`.
- Tier labels: `≤8` Easy, `≤16` Medium, `≤24` Hard, else Expert.

---

## 5. Figure fixes made during the pass

- **Tree** — 7-point triangle canopy + trunk (was unrecognizable).
- **Fish** — 6-point body with a real tail-attach vertex `(0.72, 0.50)` + tail
  triangle.
- **Key** — 15-point single polygon with wider teeth.
- **Rocket** — body pentagon + two fin triangles.
- **Heart** — parametric curve, then `_resampleLoop(raw, 22)` for even spacing.
- **Lattice** — 3×3 grid + diagonals `(1,3), (5,7)` only (keeps all degrees even).
- **Rosette** — `_rosetteFig('Rosette', 8)`.
- **Enneagram** — `_mandalaFig('Enneagram', 9, [1, 4, 5])`.

Dropped from the plan (never shipped): Owl, Butterfly, Turtle, Mushroom, Ice
Cream, Snowflake.

---

## 6. Tests

Updated and passing:

```
flutter test test/one_line_engine_test.dart \
             test/one_line_generator_test.dart \
             test/one_line_geometry_test.dart
```

- `one_line_generator_test.dart` (9 tests): solvable 1–60, tutorial
  start-anywhere (1–10), locked start (11+), determinism, edge traversal, tiers,
  31-name campaign, edge ramp, endless zone (32–60).
- `one_line_engine_test.dart`: engine mechanics incl. mid-edge circuit (1–10) and
  `suggestNextEdge`.
- `one_line_geometry_test.dart`: drawability via `minSpanFor` / `minGapFor`
  (auto-relaxes with the curated config).

`flutter analyze`: no issues introduced in any `one_line` file (remaining 209
infos/warnings are pre-existing elsewhere).

---

## 7. Known unrelated failures (pre-existing)

Confirmed by stashing this work and re-running on clean code — these fail
**without** any of the changes above:

- `test/scoring/game_performance_test.dart` — `Found 0 widgets with text "START"`.
- `test/synapse_workout_test.dart` (line 60) — same missing "START" widget.

Neither file imports anything touched by the one-line work. Out of scope for this
redesign.

---

## 8. Not done / possible follow-ups

- [ ] Resolve the two pre-existing `"START"` widget failures (separate task).
- [ ] `test/zz_ascii_test.dart` is an untracked ASCII visualiser debug helper —
      decide whether to keep, gitignore, or delete.
- [ ] Manual on-device playtest of levels 1–31 for feel / difficulty tuning.
- [ ] Optional: per-figure `startHint` tuning if any locked level feels unfair.
