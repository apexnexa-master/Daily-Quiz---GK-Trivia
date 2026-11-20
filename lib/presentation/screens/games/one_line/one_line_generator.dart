// lib/presentation/screens/games/one_line/one_line_generator.dart
//
// Deterministic procedural generator for One-Line puzzles.
//
// Design goal: the player may begin the stroke at ANY point along the
// outline - mid-segment included. That is guaranteed iff the figure is
// a connected graph whose vertices ALL have even degree (an Eulerian
// CIRCUIT). Splitting any edge at the touch point adds one vertex of
// degree 2 and flips no parities, so a full circuit still exists from
// exactly that spot.
//
// Solvability is therefore CONSTRUCTED, never searched for: a random
// trail walk over a skeleton graph yields an Eulerian edge set by
// definition, then a parity-repair pass forces every degree even, and
// Hierholzer's algorithm independently verifies each level.

import 'dart:math';
import 'dart:ui';

import 'one_line_models.dart';

class _Link {
  final int a;
  final int b;
  const _Link(this.a, this.b);
  int other(int v) => v == a ? b : a;
}

class _Skeleton {
  final String name;
  final List<Offset> points;
  final List<_Link> links;

  /// Symmetric figures get a per-level rotation so repeated topology
  /// still looks fresh.
  final bool rotatable;

  /// Set for generated figures that are already an Eulerian graph by
  /// construction: every vertex has even degree and the figure is
  /// connected, so the whole skeleton is shipped as-is (no random
  /// walk / parity repair that would break the symmetry).
  final bool eulerian;

  /// Preferred hidden canonical-solution start vertex (index into [points]).
  /// When null the builder picks the highest-degree / lowest vertex.
  final int? startHint;

  /// Dense topology figures keep their authored angles so shallow
  /// crossings cannot be introduced by the usual hand-drawn tilt.
  final bool lockOrientation;

  /// Ship the whole figure as an Eulerian TRAIL: exactly two odd-degree
  /// vertices joined by a literal bridge. The stroke must start at one
  /// odd endpoint and finishes at the other.
  final bool trail;

  /// Suppress traced-junction accent dots for hidden-node hard levels.
  final bool hideNodeDots;

  const _Skeleton(this.name, this.points, this.links,
      {this.rotatable = false,
      this.eulerian = false,
      this.startHint,
      this.lockOrientation = false,
      this.trail = false,
      this.hideNodeDots = false});
}

class _Config {
  final List<int> skeletonPool;
  final double minCoverage; // fraction of skeleton links used by the walk
  final int maxExtras; // parity chords added after the walk
  final int minEdges;
  final String difficulty;

  /// Drawability thresholds -- studio figures relax these a little;
  /// campaign figures use the strict class defaults.
  final double minSpan;
  final double minGap;
  final double minCrossingAngle;

  const _Config({
    required this.skeletonPool,
    required this.minCoverage,
    required this.maxExtras,
    required this.minEdges,
    required this.difficulty,
    this.minSpan = OneLineGenerator.minEdgeSpan,
    this.minGap = OneLineGenerator.minSegmentGap,
    this.minCrossingAngle = OneLineGenerator.minCrossingAngleDeg,
  });
}

class OneLineGenerator {
  static const double _margin = 0.12;

  /// Drawability guarantees (normalized board units, board side = 1):
  /// every stroke must be long enough to drag and far enough from its
  /// neighbours that the pen can follow it without snapping onto the
  /// wrong line. These are deliberately generous — a cramped figure is
  /// miserable to trace, so the generator re-rolls until it is roomy.
  static const double minEdgeSpan = 0.17;
  static const double minSegmentGap = 0.12;
  static const double minCrossingAngleDeg = 28;

  /// Effective drawability thresholds for [number] — studio figures
  /// relax the stroke/gap minimums slightly.
  static double minSpanFor(int number) => _configFor(number).minSpan;
  static double minGapFor(int number) => _configFor(number).minGap;
  static double minCrossingAngleFor(int number) =>
      _configFor(number).minCrossingAngle;

  static final List<_Skeleton> _rawSkeletons = [
    // 0 ── Triangle ring
    const _Skeleton('Triangle', [
      Offset(0.50, 0.10),
      Offset(0.13, 0.82),
      Offset(0.87, 0.82),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 0),
    ]),
    // 1 ── Square (+ diagonals as enrichment candidates)
    const _Skeleton('Square', [
      Offset(0.16, 0.16),
      Offset(0.84, 0.16),
      Offset(0.84, 0.84),
      Offset(0.16, 0.84),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 0),
      _Link(0, 2),
      _Link(1, 3),
    ]),
    // 2 ── Pentagon ring with center hub
    _Skeleton(
        'Pentagon',
        _ringPoints(5, center: const Offset(0.5, 0.52))
            .followedBy(const [Offset(0.5, 0.52)]).toList(),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 0),
          _Link(0, 5),
          _Link(1, 5),
          _Link(2, 5),
          _Link(3, 5),
          _Link(4, 5),
        ],
        rotatable: true),
    // 3 ── House
    const _Skeleton('House', [
      Offset(0.50, 0.08),
      Offset(0.14, 0.44),
      Offset(0.86, 0.44),
      Offset(0.86, 0.90),
      Offset(0.14, 0.90),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 0),
      _Link(1, 4),
      _Link(4, 3),
      _Link(3, 2),
      _Link(1, 3),
      _Link(2, 4),
    ]),
    // 4 ── Bowtie (two triangles sharing the middle)
    const _Skeleton('Bowtie', [
      Offset(0.10, 0.16),
      Offset(0.10, 0.84),
      Offset(0.90, 0.16),
      Offset(0.90, 0.84),
      Offset(0.50, 0.50),
    ], [
      _Link(0, 1),
      _Link(1, 4),
      _Link(4, 0),
      _Link(2, 3),
      _Link(3, 4),
      _Link(4, 2),
      _Link(0, 4),
      _Link(2, 4),
    ]),
    // 5 ── Envelope (rect + inner X meeting at center)
    const _Skeleton('Envelope', [
      Offset(0.15, 0.20),
      Offset(0.85, 0.20),
      Offset(0.85, 0.82),
      Offset(0.15, 0.82),
      Offset(0.50, 0.51),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 0),
      _Link(0, 4),
      _Link(1, 4),
      _Link(2, 4),
      _Link(3, 4),
    ]),
    // 6 ── Star (pentagram points + outer ring)
    // Star outline + radial web: spokes from the centre keep every
    // line far apart (pentagram chords used to nearly touch).
    _Skeleton(
        'Star',
        _starPoints(10, center: const Offset(0.5, 0.52))
            .followedBy(const [Offset(0.5, 0.52)]).toList(),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 6),
          _Link(6, 7),
          _Link(7, 8),
          _Link(8, 9),
          _Link(9, 0),
          _Link(0, 10),
          _Link(1, 10),
          _Link(2, 10),
          _Link(3, 10),
          _Link(4, 10),
          _Link(5, 10),
          _Link(6, 10),
          _Link(7, 10),
          _Link(8, 10),
          _Link(9, 10),
        ],
        rotatable: true),
    // 7 ── Fish (diamond body + tail)
    const _Skeleton('Fish', [
      Offset(0.10, 0.50),
      Offset(0.42, 0.22),
      Offset(0.74, 0.50),
      Offset(0.42, 0.78),
      Offset(0.94, 0.30),
      Offset(0.94, 0.70),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 0),
      _Link(2, 4),
      _Link(2, 5),
      _Link(4, 5),
      _Link(0, 2),
    ]),
    // 8 ── Crown
    const _Skeleton('Crown', [
      Offset(0.14, 0.30),
      Offset(0.32, 0.58),
      Offset(0.50, 0.26),
      Offset(0.68, 0.58),
      Offset(0.86, 0.30),
      Offset(0.14, 0.88),
      Offset(0.86, 0.88),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 4),
      _Link(0, 5),
      _Link(5, 6),
      _Link(6, 4),
      _Link(1, 5),
      _Link(3, 6),
      _Link(5, 1),
      _Link(6, 3),
    ]),
    // 9 ── Arrow
    const _Skeleton('Arrow', [
      Offset(0.92, 0.50),
      Offset(0.56, 0.14),
      Offset(0.56, 0.86),
      Offset(0.56, 0.36),
      Offset(0.10, 0.36),
      Offset(0.10, 0.64),
      Offset(0.56, 0.64),
    ], [
      _Link(0, 1), _Link(2, 0),
      _Link(1, 3), _Link(2, 6),
      _Link(3, 4), _Link(4, 5), _Link(5, 6),
      // (1,2) removed: it ran collinearly over vertices 3 and 6,
      // stacking strokes on top of each other.
    ]),
    // 10 ── Cube projection
    const _Skeleton('Cube', [
      Offset(0.24, 0.40),
      Offset(0.60, 0.40),
      Offset(0.60, 0.76),
      Offset(0.24, 0.76),
      Offset(0.42, 0.18),
      Offset(0.78, 0.18),
      Offset(0.78, 0.54),
      Offset(0.42, 0.54),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 0),
      _Link(4, 5),
      _Link(5, 6),
      _Link(6, 7),
      _Link(7, 4),
      _Link(0, 4),
      _Link(1, 5),
      _Link(2, 6),
      _Link(3, 7),
    ]),
    // 11 ── Hexagon ring with long diagonals
    _Skeleton(
        'Hexagon',
        _ringPoints(6, radius: 0.40),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 0),
          _Link(0, 3),
          _Link(1, 4),
          _Link(2, 5),
        ],
        rotatable: true),
    // 12 ── Wheel (hexagon + full spoke set)
    _Skeleton(
        'Wheel',
        _ringPoints(6, radius: 0.40)
            .followedBy(const [Offset(0.5, 0.5)]).toList(),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 0),
          _Link(0, 6),
          _Link(1, 6),
          _Link(2, 6),
          _Link(3, 6),
          _Link(4, 6),
          _Link(5, 6),
        ],
        rotatable: true),
    // 13 ── 3x3 grid lattice (one diagonal per edge cell keeps the
    // complete graph all-even; the old four-corner diagonal set had
    // unfixable corner odds)
    _Skeleton('Lattice', _gridPoints(3), const [
      // rows
      _Link(0, 1), _Link(1, 2), _Link(3, 4), _Link(4, 5),
      _Link(6, 7), _Link(7, 8),
      // columns
      _Link(0, 3), _Link(3, 6), _Link(1, 4), _Link(4, 7),
      _Link(2, 5), _Link(5, 8),
      // diagonals of the top, right, bottom and left cells
      _Link(1, 3), _Link(1, 5), _Link(5, 7), _Link(3, 7),
    ]),
    // 14 ── Diamond inside square (all-even degrees when complete)
    const _Skeleton(
        'Octagram',
        [
          Offset(0.15, 0.15),
          Offset(0.85, 0.15),
          Offset(0.85, 0.85),
          Offset(0.15, 0.85),
          Offset(0.50, 0.15),
          Offset(0.85, 0.50),
          Offset(0.50, 0.85),
          Offset(0.15, 0.50),
        ],
        [
          // outer ring drawn as corner-to-mid spokes: the plain side links
          // (0,1)(1,2)(2,3)(3,0) lay exactly on top of these spokes.
          _Link(0, 7), _Link(0, 4), _Link(4, 1),
          _Link(1, 5), _Link(5, 2), _Link(2, 6),
          _Link(6, 3), _Link(3, 7),
          // inner diamond
          _Link(4, 5), _Link(5, 6), _Link(6, 7), _Link(7, 4),
        ],
        rotatable: true),
    // 15 ── Double diamond
    const _Skeleton('Gem', [
      Offset(0.50, 0.08),
      Offset(0.88, 0.50),
      Offset(0.50, 0.92),
      Offset(0.12, 0.50),
      Offset(0.50, 0.32),
      Offset(0.70, 0.50),
      Offset(0.50, 0.68),
      Offset(0.30, 0.50),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 0),
      _Link(4, 5),
      _Link(5, 6),
      _Link(6, 7),
      _Link(7, 4),
      _Link(0, 4),
      _Link(1, 5),
      _Link(2, 6),
      _Link(3, 7),
    ]),
    // 16 ── Six-point star tips
    _Skeleton(
        'Snowflake',
        _starPoints(6, innerFactor: 0.62),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 0),
          _Link(0, 2),
          _Link(2, 4),
          _Link(4, 0),
          _Link(1, 3),
          _Link(3, 5),
          _Link(5, 1),
          _Link(0, 3),
          _Link(1, 4),
          _Link(2, 5),
        ],
        rotatable: true),
    // 17 ── Ladder
    const _Skeleton('Ladder', [
      Offset(0.30, 0.12),
      Offset(0.70, 0.12),
      Offset(0.30, 0.50),
      Offset(0.70, 0.50),
      Offset(0.30, 0.88),
      Offset(0.70, 0.88),
    ], [
      _Link(0, 1),
      _Link(2, 3),
      _Link(4, 5),
      _Link(0, 2),
      _Link(2, 4),
      _Link(1, 3),
      _Link(3, 5),
      _Link(0, 3),
      _Link(1, 2),
      _Link(2, 5),
      _Link(3, 4),
    ]),
    // 18 ── Pentagram complete graph K5 (every vertex degree 4)
    _Skeleton(
        'Pentagram',
        _ringPoints(5, radius: 0.42),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 0),
          _Link(0, 2),
          _Link(0, 3),
          _Link(1, 3),
          _Link(1, 4),
          _Link(2, 4),
        ],
        rotatable: true),
    // 19 ── Octahedron projection (every vertex degree 4)
    const _Skeleton('Octahedron', [
      Offset(0.50, 0.06),
      Offset(0.18, 0.36),
      Offset(0.82, 0.36),
      Offset(0.82, 0.76),
      Offset(0.18, 0.76),
      Offset(0.50, 0.97),
    ], [
      // equator square
      _Link(1, 2), _Link(2, 3), _Link(3, 4), _Link(4, 1),
      // apex spokes
      _Link(0, 1), _Link(0, 2), _Link(0, 3), _Link(0, 4),
      _Link(5, 1), _Link(5, 2), _Link(5, 3), _Link(5, 4),
    ]),
    // 20 ── Hourglass (classic one-stroke figure, all-even)
    const _Skeleton('Hourglass', [
      Offset(0.16, 0.14),
      Offset(0.84, 0.14),
      Offset(0.50, 0.52),
      Offset(0.16, 0.90),
      Offset(0.84, 0.90),
    ], [
      _Link(0, 1),
      _Link(3, 4),
      _Link(0, 2),
      _Link(1, 2),
      _Link(3, 2),
      _Link(4, 2),
    ]),
    // 21 ── Triforce: three small triangles forming one big triangle
    const _Skeleton(
        'Triforce',
        [
          Offset(0.50, 0.08),
          Offset(0.28, 0.48),
          Offset(0.72, 0.48),
          Offset(0.06, 0.88),
          Offset(0.50, 0.88),
          Offset(0.94, 0.88),
        ],
        [
          // outer rim split by midpoints + inner inverted triangle
          _Link(0, 1), _Link(1, 4), _Link(4, 2), _Link(2, 0),
          _Link(1, 3), _Link(3, 4),
          _Link(2, 4), _Link(4, 5), _Link(5, 2),
        ],
        rotatable: true),
    // 22 ── Star of David: hexagram outline + inner ring
    _Skeleton(
        'StarOfDavid',
        [
          for (var k = 0; k < 6; k++)
            Offset(
              0.5 + 0.44 * cos(-pi / 2 + k * pi / 3),
              0.5 + 0.44 * sin(-pi / 2 + k * pi / 3),
            ),
          for (var k = 0; k < 6; k++)
            Offset(
              0.5 + 0.25 * cos(-pi / 2 + pi / 6 + k * pi / 3),
              0.5 + 0.25 * sin(-pi / 2 + pi / 6 + k * pi / 3),
            ),
        ],
        const [
          // hexagram outline: every tip joins its two neighbouring valleys
          _Link(0, 6), _Link(0, 11),
          _Link(1, 6), _Link(1, 7),
          _Link(2, 7), _Link(2, 8),
          _Link(3, 8), _Link(3, 9),
          _Link(4, 9), _Link(4, 10),
          _Link(5, 10), _Link(5, 11),
          // inner hexagon
          _Link(6, 7), _Link(7, 8), _Link(8, 9),
          _Link(9, 10), _Link(10, 11), _Link(11, 6),
        ],
        rotatable: true),
    // 23 ── Diamond chain: four diamonds sharing middle corners
    const _Skeleton('DiamondChain', [
      Offset(0.08, 0.52),
      Offset(0.29, 0.52),
      Offset(0.50, 0.52),
      Offset(0.71, 0.52),
      Offset(0.92, 0.52),
      Offset(0.185, 0.18),
      Offset(0.395, 0.18),
      Offset(0.605, 0.18),
      Offset(0.815, 0.18),
      Offset(0.185, 0.86),
      Offset(0.395, 0.86),
      Offset(0.605, 0.86),
      Offset(0.815, 0.86),
    ], [
      _Link(0, 5),
      _Link(5, 1),
      _Link(0, 9),
      _Link(9, 1),
      _Link(1, 6),
      _Link(6, 2),
      _Link(1, 10),
      _Link(10, 2),
      _Link(2, 7),
      _Link(7, 3),
      _Link(2, 11),
      _Link(11, 3),
      _Link(3, 8),
      _Link(8, 4),
      _Link(3, 12),
      _Link(12, 4),
    ]),
    // 24 ── Cube in perspective with X-braced faces
    const _Skeleton('CubeX', [
      Offset(0.20, 0.42),
      Offset(0.62, 0.42),
      Offset(0.62, 0.84),
      Offset(0.20, 0.84),
      Offset(0.38, 0.22),
      Offset(0.80, 0.22),
      Offset(0.80, 0.64),
      Offset(0.38, 0.64),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 0),
      _Link(4, 5),
      _Link(5, 6),
      _Link(6, 7),
      _Link(7, 4),
      _Link(0, 4),
      _Link(1, 5),
      _Link(2, 6),
      _Link(3, 7),
      _Link(0, 2),
      _Link(4, 6),
    ]),
    // 25 ── OctoWeb mandala: octagon ring plus step-two chords
    _Skeleton(
        'OctoWeb',
        [
          for (var k = 0; k < 8; k++)
            Offset(
              0.5 + 0.44 * cos(-pi / 2 + k * pi / 4),
              0.5 + 0.44 * sin(-pi / 2 + k * pi / 4),
            ),
        ],
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 6),
          _Link(6, 7),
          _Link(7, 0),
          _Link(0, 2),
          _Link(1, 3),
          _Link(2, 4),
          _Link(3, 5),
          _Link(4, 6),
          _Link(5, 7),
          _Link(6, 0),
          _Link(7, 1),
        ],
        rotatable: true),
    // 26 ── Star outline ring (ten-point alternating radii)
    _Skeleton(
        'StarOutline',
        _starPoints(10, innerFactor: 0.55),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 6),
          _Link(6, 7),
          _Link(7, 8),
          _Link(8, 9),
          _Link(9, 0),
        ],
        rotatable: true),
    // 27 ── Lightning bolt (closed zig-zag cycle)
    const _Skeleton('Bolt', [
      Offset(0.60, 0.04),
      Offset(0.18, 0.50),
      Offset(0.42, 0.52),
      Offset(0.36, 0.96),
      Offset(0.84, 0.42),
      Offset(0.56, 0.42),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 4),
      _Link(4, 5),
      _Link(5, 0),
    ]),
    // 28 ── Rocket: nose cone, X-braced body and twin fins
    const _Skeleton('Rocket', [
      Offset(0.50, 0.06),
      Offset(0.26, 0.38),
      Offset(0.74, 0.38),
      Offset(0.26, 0.82),
      Offset(0.74, 0.82),
      Offset(0.08, 0.96),
      Offset(0.92, 0.96),
    ], [
      _Link(0, 1),
      _Link(0, 2),
      _Link(1, 2),
      _Link(1, 3),
      _Link(2, 4),
      _Link(3, 4),
      _Link(3, 5),
      _Link(5, 6),
      _Link(6, 4),
      _Link(1, 4),
      _Link(2, 3),
    ]),
    // 29 ── Prism: two nested squares laced corner-to-corner
    const _Skeleton('Prism', [
      Offset(0.10, 0.10),
      Offset(0.90, 0.10),
      Offset(0.90, 0.90),
      Offset(0.10, 0.90),
      Offset(0.34, 0.34),
      Offset(0.66, 0.34),
      Offset(0.66, 0.66),
      Offset(0.34, 0.66),
    ], [
      _Link(0, 1),
      _Link(1, 2),
      _Link(2, 3),
      _Link(3, 0),
      _Link(4, 5),
      _Link(5, 6),
      _Link(6, 7),
      _Link(7, 4),
      _Link(0, 4),
      _Link(0, 7),
      _Link(1, 5),
      _Link(1, 4),
      _Link(2, 6),
      _Link(2, 5),
      _Link(3, 7),
      _Link(3, 6),
    ]),
    // 30 ── Enneagram: a nine-point ring threaded by a single open
    // {@9/4} star so the chords stay long and well-spaced.
    _Skeleton(
        'Enneagram',
        _ringPoints(9, radius: 0.44),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 6),
          _Link(6, 7),
          _Link(7, 8),
          _Link(8, 0),
          _Link(0, 4),
          _Link(4, 8),
          _Link(8, 3),
          _Link(3, 7),
          _Link(7, 2),
          _Link(2, 6),
          _Link(6, 1),
          _Link(1, 5),
          _Link(5, 0),
        ],
        rotatable: true),
    // 31 ── Decagram: a decagon threaded by two interlocked pentagons
    // ({10/4}) — long chords, no shallow crossings.
    _Skeleton(
        'Decagram',
        _ringPoints(10, radius: 0.44),
        const [
          _Link(0, 1),
          _Link(1, 2),
          _Link(2, 3),
          _Link(3, 4),
          _Link(4, 5),
          _Link(5, 6),
          _Link(6, 7),
          _Link(7, 8),
          _Link(8, 9),
          _Link(9, 0),
          _Link(0, 4),
          _Link(4, 8),
          _Link(8, 2),
          _Link(2, 6),
          _Link(6, 0),
          _Link(1, 5),
          _Link(5, 9),
          _Link(9, 3),
          _Link(3, 7),
          _Link(7, 1),
        ],
        rotatable: true),

    // ══ THEMATIC CAMPAIGN CATALOGUE ══════════════════════════════════
    // Parametric geometric figures: rings, weaves, rosettes, gears and
    // linked trails. Each figure is built as a union of closed loops, so
    // every vertex is even-degree by construction and the whole figure
    // ships exactly as drawn. Ordered easiest -> hardest by edge count.
    ..._introFigures(),
    ..._thematicFigures(),
    ..._newStudioFigures(),
  ];

  /// Figures as actually played: duplicate-free links and every shape
  /// fitted into a centered box so all levels share a consistent size
  /// and position on the board.
  static final List<_Skeleton> _skeletons = [
    for (final s in _rawSkeletons) _normalize(s)
  ];

  static _Skeleton _normalize(_Skeleton s) {
    // Canonical links; reversed duplicates (e.g. Crown's base spokes)
    // collapse into one edge.
    final seen = <String>{};
    final links = <_Link>[];
    for (final l in s.links) {
      final key = l.a <= l.b ? '${l.a}-${l.b}' : '${l.b}-${l.a}';
      if (seen.add(key)) {
        links.add(l.a <= l.b ? l : _Link(l.b, l.a));
      }
    }

    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final p in s.points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    // Bigger boards across the board: even simple figures claim most
    // of the play area, dense webs stretch towards its edges.
    final t = ((s.links.length - 7) / 11).clamp(0.0, 1.0);
    final span = 0.88 + t * 0.08; // 0.88 .. 0.96
    final w = maxX - minX;
    final h = maxY - minY;
    final scale = span / max(w <= 0 ? 1 : w, h <= 0 ? 1 : h);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    return _Skeleton(
        s.name,
        [
          for (final p in s.points)
            Offset(0.5 + (p.dx - cx) * scale, 0.5 + (p.dy - cy) * scale),
        ],
        links,
        rotatable: s.rotatable,
        eulerian: s.eulerian,
        startHint: s.startHint,
        lockOrientation: s.lockOrientation,
        trail: s.trail,
        hideNodeDots: s.hideNodeDots);
  }

  /// Campaign: every one of these levels is a DIFFERENT hand-crafted
  /// one-stroke figure from the new catalogue (indices [_campaignStart]
  /// onward), ordered easiest to richest by edge count. No repeats —
  /// level N draws skeleton [_curatedOrder[N - 1]].
  static const int _campaignStart = 32;
  static final int _studioStart =
      _rawSkeletons.length - _newStudioFigures().length;

  static final List<int> _curatedOrder = [
    for (var i = _campaignStart; i < _studioStart; i++) i,
  ];

  static final List<int> _studioOrder = [
    for (var i = _studioStart; i < _rawSkeletons.length; i++) i,
  ];

  static final int _introCount = _introFigures().length;

  static final int _hardStart =
      _introCount + _thematicFigures().length - _hardFigures().length + 1;

  /// Number of hand-crafted campaign levels.
  static int get campaignLevelCount => _curatedOrder.length;

  /// Number of distinct hand-crafted endless studio figures.
  static int get studioLevelCount => _studioOrder.length;

  /// Levels 1-[campaignLevelCount] teach the classic outlines. After
  /// that the endless zone serves a distinct hand-crafted studio figure
  /// one by one — no edge-count reskins and no repeated shapes.
  static _Config _configFor(int number) {
    final curatedCount = _curatedOrder.length;
    if (number >= _hardStart && number <= curatedCount) {
      return _Config(
        skeletonPool: [_curatedOrder[number - 1]],
        minCoverage: 1.0,
        maxExtras: 0,
        minEdges: 6,
        difficulty: 'Master',
        minSpan: 0.005,
        minGap: 0.0,
        minCrossingAngle: 0,
      );
    }
    if (number <= curatedCount) {
      String label;
      final catalogueLevel = number - _introCount;
      if (catalogueLevel <= 0) {
        label = number <= 6 ? 'Easy' : 'Medium';
      } else if (catalogueLevel <= 8) {
        label = 'Easy';
      } else if (catalogueLevel <= 16) {
        label = 'Medium';
      } else if (catalogueLevel <= 24) {
        label = 'Hard';
      } else {
        label = 'Expert';
      }
      return _Config(
        skeletonPool: [_curatedOrder[number - 1]],
        minCoverage: 0.85,
        maxExtras: 2,
        minEdges: 3,
        difficulty: label,
        // Hand-drawn figures carry finer detail than the plain primitives
        // did, so the stroke/gap minimums relax a touch — recognisability
        // matters more than blanket spacing.
        minSpan: 0.005,
        minGap: 0.0,
        minCrossingAngle: 0,
      );
    }

    final studioIndex = (number - curatedCount - 1) % _studioOrder.length;
    final skeletonIndex = _studioOrder[studioIndex];
    final edges = _skeletons[skeletonIndex].links.length;
    String label;
    if (edges <= 14) {
      label = 'Hard';
    } else if (edges <= 21) {
      label = 'Expert';
    } else {
      label = 'Master';
    }
    return _Config(
      skeletonPool: [skeletonIndex],
      minCoverage: 1.0,
      maxExtras: 0,
      minEdges: 6,
      difficulty: label,
      minSpan: 0.005,
      minGap: 0.0,
      minCrossingAngle: 0,
    );
  }

  /// Memoised levels. Doubles as the layout-history used to keep any
  /// two levels from shipping the same figure.
  final Map<int, OneLineLevel> _memo = {};

  /// Layout signatures already shipped, so no two levels ever repeat.
  final Set<String> _seenLayouts = {};

  /// Rotation-, reflection- and translation-invariant signature of a
  /// built level. Figures that are congruent up to placement, mirroring
  /// or rotation collapse to the same key, so the endless zone can never
  /// re-serve the same shape just spun to a new angle.
  String _shapeSignature(OneLineLevel lv) {
    final p = [for (final v in lv.vertices) v.position];
    final edgeLens = <int>[];
    final incident = List<List<int>>.generate(lv.vertices.length, (_) => []);
    for (final e in lv.edges) {
      final d = ((p[e.b] - p[e.a]).distance * 1000).round();
      edgeLens.add(d);
      incident[e.a].add(d);
      incident[e.b].add(d);
    }
    edgeLens.sort();
    final vkeys = <String>[];
    for (final inc in incident) {
      inc.sort();
      vkeys.add('${inc.length}:${inc.join(',')}');
    }
    vkeys.sort();
    // Degree sequence + topology-sensitive per-vertex lengths stop two
    // different graphs with similar line lengths from collapsing into
    // one signature.
    return '${lv.edges.length}#${edgeLens.join('|')}#${vkeys.join(';')}';
  }

  /// Generates the deterministic puzzle for 1-based [number].
  /// Never throws: falls back to a plain polygon cycle if every
  /// randomized attempt somehow fails validation.
  OneLineLevel generateLevel(int number) {
    assert(number >= 1);
    final cached = _memo[number];
    if (cached != null) return cached;

    // Deterministic history: build the two previous levels first so
    // this one can avoid their layouts regardless of which index is
    // requested first (memo keeps the recursion cheap and stable).
    for (final prev in [number - 2, number - 1]) {
      if (prev >= 1 && !_memo.containsKey(prev)) generateLevel(prev);
    }

    final cfg = _configFor(number);
    final rng = Random(number * 1000003 + 7);

    // Best-of-N: every attempt re-rolls the rotation and mirror, and the
    // roomiest, best-shaped result wins — so the player always gets the
    // most traceable variant of each hand-authored figure.
    OneLineLevel? best;
    double bestScore = double.negativeInfinity;
    OneLineLevel? duplicateStash;
    for (int attempt = 0; attempt < 36; attempt++) {
      final sk = _skeletons[cfg.skeletonPool.first];
      final mirror = attempt.isOdd || rng.nextBool();
      final level = _tryBuild(sk, cfg, rng, number, mirror);
      if (level == null) continue;

      final key = _shapeSignature(level);
      if (_seenLayouts.contains(key)) {
        // Prefer re-rolling over a duplicate; if variety is exhausted
        // the least-bad repeat is shipped rather than a fallback.
        duplicateStash ??= level;
        continue;
      }
      final score = _candidateScore(level);
      if (score > bestScore) {
        bestScore = score;
        best = level;
      }
    }
    final chosen = best ?? duplicateStash ?? _fallbackCycle(number);
    _memo[number] = chosen;
    _seenLayouts.add(_shapeSignature(chosen));
    return chosen;
  }

  /// Ranks a candidate figure: breathing room first, then long strokes,
  /// then a meatier edge count (capped so density never trumps clarity).
  static double _qualityScore(OneLineLevel l) {
    final m = _metricsOf(l.vertices, l.edges);
    return m.minGap * 100 + m.minSpan * 40 + min(l.edges.length, 20) * 0.5;
  }

  /// Ranks a candidate by how much *fun* it is to plan, while still
  /// rewarding roomy strokes. Junctions (degree 4+) are where a wrong
  /// turn can strand a sub-loop, and independent cycles are exactly the
  /// traps the player has to order correctly — both are desirable.
  static double _candidateScore(OneLineLevel l) {
    var score = _qualityScore(l);
    final degree = List<int>.filled(l.vertices.length, 0);
    for (final e in l.edges) {
      degree[e.a]++;
      degree[e.b]++;
    }
    final junctions = degree.where((d) => d >= 4).length;
    final cycles = l.edges.length - l.vertices.length + 1;
    return score + junctions * 2.4 + min(cycles, 7) * 1.6;
  }

  /// Tightest non-touching line gap and shortest stroke in a figure.
  static ({double minGap, double minSpan}) _metricsOf(
      List<OneLineVertex> vertices, List<OneLineEdge> edges) {
    final p = [for (final v in vertices) v.position];
    var minSpan = double.infinity;
    for (final e in edges) {
      minSpan = min(minSpan, (p[e.b] - p[e.a]).distance);
    }
    var minGap = double.infinity;
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        final e = edges[i], f = edges[j];
        if (e.a == f.a || e.a == f.b || e.b == f.a || e.b == f.b) continue;
        final rel = _segmentRelation(p[e.a], p[e.b], p[f.a], p[f.b]);
        if (!rel.crossing) minGap = min(minGap, rel.distance);
      }
    }
    if (minGap == double.infinity) minGap = 1.0;
    return (minGap: minGap, minSpan: minSpan);
  }

  // ── Construction pipeline ─────────────────────────────────────────

  // ── Hand-crafted campaign figures ──────────────────────────────────
  // Every figure below is ALL-EVEN by construction (each vertex degree 2
  // or 4), connected, and fitted to a consistent span, so it ships
  // exactly as designed — no random walk, no parity repair, no name that
  // lies. Difficulty climbs purely by edge count.

  static List<Offset> _ellipse(
          double cx, double cy, double rx, double ry, int count,
          {double phase = -pi / 2}) =>
      [
        for (var i = 0; i < count; i++)
          Offset(cx + rx * cos(phase + i * 2 * pi / count),
              cy + ry * sin(phase + i * 2 * pi / count)),
      ];

  static List<Offset> _box(
          double left, double top, double right, double bottom) =>
      [
        Offset(left, top),
        Offset(right, top),
        Offset(right, bottom),
        Offset(left, bottom),
      ];

  static List<Offset> _diamondAt(double cx, double cy, double rx, double ry) =>
      [
        Offset(cx, cy - ry),
        Offset(cx + rx, cy),
        Offset(cx, cy + ry),
        Offset(cx - rx, cy),
      ];

  static List<List<Offset>> _fan(Offset center, List<Offset> rim) => [
        for (var i = 0; i < rim.length; i++)
          [center, rim[i], rim[(i + 1) % rim.length]],
      ];

  static _Skeleton _shape(String name, List<List<Offset>> loops,
      {List<List<Offset>> extraLinks = const []}) {
    return _fig(name, loops, lockOrientation: true, extraLinks: extraLinks);
  }

  static _Skeleton _simpleChair() => _shape('SimpleChair', [
        [
          const Offset(0.24, 0.10),
          const Offset(0.76, 0.10),
          const Offset(0.76, 0.50),
          const Offset(0.84, 0.50),
          const Offset(0.84, 0.66),
          const Offset(0.72, 0.66),
          const Offset(0.72, 0.92),
          const Offset(0.60, 0.92),
          const Offset(0.60, 0.66),
          const Offset(0.40, 0.66),
          const Offset(0.40, 0.92),
          const Offset(0.28, 0.92),
          const Offset(0.28, 0.66),
          const Offset(0.16, 0.66),
          const Offset(0.16, 0.50),
          const Offset(0.24, 0.50),
        ],
      ]);

  static _Skeleton _simpleTree() => _shape('SimpleTree', [
        [
          const Offset(0.42, 0.92),
          const Offset(0.58, 0.92),
          const Offset(0.58, 0.70),
          const Offset(0.78, 0.70),
          const Offset(0.50, 0.10),
          const Offset(0.22, 0.70),
          const Offset(0.42, 0.70),
        ],
      ]);

  static _Skeleton _simpleBoat() => _shape('SimpleBoat', [
        [
          const Offset(0.14, 0.66),
          const Offset(0.50, 0.66),
          const Offset(0.86, 0.66),
          const Offset(0.72, 0.88),
          const Offset(0.28, 0.88),
        ],
        [
          const Offset(0.50, 0.12),
          const Offset(0.50, 0.66),
          const Offset(0.82, 0.38),
        ],
      ]);

  static _Skeleton _simpleStar() => _shape('SimpleStar', [
        _starLoop(5, outer: 0.44, inner: 0.20),
      ]);

  static _Skeleton _simpleDiamond() {
    final outer = [
      const Offset(0.50, 0.06),
      const Offset(0.90, 0.50),
      const Offset(0.50, 0.94),
      const Offset(0.10, 0.50),
    ];
    final inner = [
      const Offset(0.50, 0.26),
      const Offset(0.72, 0.50),
      const Offset(0.50, 0.74),
      const Offset(0.28, 0.50),
    ];
    final extra = <List<Offset>>[
      for (var i = 0; i < 4; i++) ...[
        [outer[i], inner[i]],
        [outer[i], inner[(i + 3) % 4]],
      ],
    ];
    return _shape('SimpleDiamond', [outer, inner], extraLinks: extra);
  }

  static _Skeleton _simpleFish() => _shape('SimpleFish', [
        [
          const Offset(0.12, 0.50),
          const Offset(0.26, 0.30),
          const Offset(0.50, 0.26),
          const Offset(0.66, 0.40),
          const Offset(0.70, 0.50),
          const Offset(0.66, 0.60),
          const Offset(0.50, 0.74),
          const Offset(0.26, 0.70),
        ],
        [
          const Offset(0.66, 0.40),
          const Offset(0.90, 0.24),
          const Offset(0.90, 0.76),
          const Offset(0.66, 0.60),
        ],
      ]);

  static _Skeleton _simplePentagon() {
    final outer = _ringAt(5, 0.42, -pi / 2);
    final inner = _ringAt(5, 0.20, -pi / 2);
    final extra = <List<Offset>>[
      for (var i = 0; i < 5; i++) ...[
        [outer[i], inner[i]],
        [outer[i], inner[(i + 4) % 5]],
      ],
    ];
    return _shape('SimplePentagon', [outer, inner], extraLinks: extra);
  }

  static _Skeleton _anchor() => _shape('Anchor', [
        [
          const Offset(0.44, 0.10),
          const Offset(0.56, 0.10),
          const Offset(0.62, 0.32),
          const Offset(0.78, 0.32),
          const Offset(0.86, 0.62),
          const Offset(0.50, 0.88),
          const Offset(0.14, 0.62),
          const Offset(0.22, 0.32),
          const Offset(0.38, 0.32),
          const Offset(0.50, 0.20),
        ],
      ]);

  static _Skeleton _simpleRocket() => _shape('SimpleRocket', [
        [
          const Offset(0.50, 0.06),
          const Offset(0.62, 0.26),
          const Offset(0.62, 0.68),
          const Offset(0.80, 0.88),
          const Offset(0.62, 0.82),
          const Offset(0.62, 0.92),
          const Offset(0.38, 0.92),
          const Offset(0.38, 0.82),
          const Offset(0.20, 0.88),
          const Offset(0.38, 0.68),
          const Offset(0.38, 0.26),
        ],
      ]);

  static _Skeleton _simpleKey() => _shape('SimpleKey', [
        _ellipse(0.30, 0.34, 0.18, 0.20, 10),
        [
          const Offset(0.30, 0.54),
          const Offset(0.86, 0.54),
          const Offset(0.86, 0.66),
          const Offset(0.78, 0.66),
          const Offset(0.78, 0.80),
          const Offset(0.68, 0.80),
          const Offset(0.68, 0.66),
          const Offset(0.58, 0.66),
          const Offset(0.58, 0.80),
          const Offset(0.48, 0.80),
          const Offset(0.48, 0.66),
          const Offset(0.30, 0.66),
        ],
      ]);

  static _Skeleton _simplePrism() {
    final front = _box(0.18, 0.32, 0.58, 0.72);
    final back = _box(0.42, 0.16, 0.82, 0.56);
    final extra = <List<Offset>>[
      for (var i = 0; i < 4; i++) ...[
        [front[i], back[i]],
        [front[i], back[(i + 3) % 4]],
      ],
    ];
    return _shape('SimplePrism', [front, back], extraLinks: extra);
  }

  static _Skeleton _simpleOwl() {
    final outline = [
      const Offset(0.24, 0.22),
      const Offset(0.34, 0.10),
      const Offset(0.44, 0.22),
      const Offset(0.56, 0.22),
      const Offset(0.66, 0.10),
      const Offset(0.76, 0.22),
      const Offset(0.82, 0.46),
      const Offset(0.74, 0.72),
      const Offset(0.62, 0.88),
      const Offset(0.38, 0.88),
      const Offset(0.26, 0.72),
      const Offset(0.18, 0.46),
    ];
    final leftEye = _ellipse(0.37, 0.42, 0.08, 0.08, 8);
    final rightEye = _ellipse(0.63, 0.42, 0.08, 0.08, 8);
    final beak = [
      const Offset(0.50, 0.50),
      const Offset(0.45, 0.60),
      const Offset(0.55, 0.60),
    ];
    return _shape('SimpleOwl', [
      outline,
      leftEye,
      rightEye,
      beak
    ], extraLinks: [
      [outline[0], leftEye[0]],
      [outline[0], leftEye[4]],
      [outline[11], leftEye[0]],
      [outline[11], leftEye[4]],
      [outline[5], rightEye[0]],
      [outline[5], rightEye[4]],
      [outline[6], rightEye[0]],
      [outline[6], rightEye[4]],
      [outline[2], beak[0]],
      [outline[2], beak[2]],
      [outline[7], beak[0]],
      [outline[7], beak[2]],
    ]);
  }

  static List<_Skeleton> _introFigures() {
    return [
      _simpleChair(),
      _simpleTree(),
      _simpleBoat(),
      _simpleStar(),
      _simpleDiamond(),
      _simpleFish(),
      _simplePentagon(),
      _anchor(),
      _simpleRocket(),
      _simpleKey(),
      _simplePrism(),
      _simpleOwl(),
    ];
  }

  static _Skeleton _smallHouse() => _shape('SmallHouse', [
        [
          const Offset(0.18, 0.46),
          const Offset(0.82, 0.46),
          const Offset(0.82, 0.86),
          const Offset(0.60, 0.86),
          const Offset(0.40, 0.86),
          const Offset(0.18, 0.86),
        ],
        [
          const Offset(0.18, 0.46),
          const Offset(0.50, 0.14),
          const Offset(0.82, 0.46),
        ],
        _box(0.40, 0.62, 0.60, 0.86),
      ]);

  static _Skeleton _fivePointStar() {
    final star = _starLoop(5, outer: 0.44, inner: 0.20);
    return _shape('FivePointStar', [
      star,
      [star[1], star[3], star[5], star[7], star[9]],
    ]);
  }

  static _Skeleton _sailboat() => _shape('Sailboat', [
        [
          const Offset(0.18, 0.70),
          const Offset(0.34, 0.70),
          const Offset(0.50, 0.70),
          const Offset(0.66, 0.70),
          const Offset(0.82, 0.70),
          const Offset(0.72, 1.04),
          const Offset(0.28, 1.04),
        ],
        _box(0.34, 0.70, 0.66, 0.88),
        [
          const Offset(0.50, 0.10),
          const Offset(0.50, 0.70),
          const Offset(0.18, 0.70),
        ],
        [
          const Offset(0.50, 0.10),
          const Offset(0.82, 0.70),
          const Offset(0.50, 0.70),
        ],
        [
          const Offset(0.50, 0.10),
          const Offset(0.78, 0.16),
          const Offset(0.62, 0.34),
        ],
      ]);

  static _Skeleton _umbrella() => _shape('Umbrella', [
        [
          const Offset(0.12, 0.52),
          const Offset(0.28, 0.24),
          const Offset(0.50, 0.14),
          const Offset(0.72, 0.24),
          const Offset(0.88, 0.52),
          const Offset(0.72, 0.46),
          const Offset(0.50, 0.52),
          const Offset(0.28, 0.46),
        ],
        [
          const Offset(0.50, 0.52),
          const Offset(0.50, 0.90),
          const Offset(0.30, 0.74),
        ],
        [
          const Offset(0.50, 0.52),
          const Offset(0.28, 0.24),
          const Offset(0.12, 0.52),
        ],
        [
          const Offset(0.50, 0.52),
          const Offset(0.72, 0.24),
          const Offset(0.88, 0.52),
        ],
      ]);

  static _Skeleton _fish() => _shape('Fish', [
        [
          const Offset(0.20, 0.50),
          const Offset(0.42, 0.28),
          const Offset(0.74, 0.34),
          const Offset(0.84, 0.50),
          const Offset(0.74, 0.66),
          const Offset(0.42, 0.72),
        ],
        [
          const Offset(0.20, 0.50),
          const Offset(0.08, 0.30),
          const Offset(0.08, 0.70),
        ],
        [
          const Offset(0.42, 0.72),
          const Offset(0.36, 0.88),
          const Offset(0.60, 0.74),
        ],
        [
          const Offset(0.56, 0.34),
          const Offset(0.50, 0.50),
          const Offset(0.56, 0.66),
        ],
      ]);

  static _Skeleton _diamondCrystal() {
    final outer = [
      const Offset(0.50, 0.08),
      const Offset(0.82, 0.38),
      const Offset(0.50, 0.90),
      const Offset(0.18, 0.38),
    ];
    final inner = [
      const Offset(0.50, 0.28),
      const Offset(0.68, 0.44),
      const Offset(0.50, 0.66),
      const Offset(0.32, 0.44),
    ];
    return _shape('DiamondCrystal', [
      outer,
      inner,
      [outer[0], inner[0], outer[3]],
      [outer[0], outer[1], inner[0]],
      [outer[1], inner[1], outer[2]],
      [outer[2], inner[2], outer[3]],
      [outer[3], inner[3], outer[0]],
    ]);
  }

  static _Skeleton _rocket() => _shape('Rocket', [
        [
          const Offset(0.24, 0.78),
          const Offset(0.24, 0.34),
          const Offset(0.50, 0.08),
          const Offset(0.76, 0.34),
          const Offset(0.76, 0.78),
        ],
        [
          const Offset(0.24, 0.52),
          const Offset(0.10, 0.86),
          const Offset(0.24, 0.78),
        ],
        [
          const Offset(0.76, 0.52),
          const Offset(0.90, 0.86),
          const Offset(0.76, 0.78),
        ],
        [
          const Offset(0.50, 0.08),
          const Offset(0.40, 0.36),
          const Offset(0.60, 0.36),
        ],
        [
          const Offset(0.24, 0.78),
          const Offset(0.50, 0.96),
          const Offset(0.76, 0.78),
        ],
      ]);

  static _Skeleton _coffeeCup() => _shape('CoffeeCup', [
        [
          const Offset(0.24, 0.40),
          const Offset(0.36, 0.40),
          const Offset(0.44, 0.40),
          const Offset(0.56, 0.40),
          const Offset(0.72, 0.40),
          const Offset(0.66, 0.82),
          const Offset(0.30, 0.82),
        ],
        [
          const Offset(0.72, 0.48),
          const Offset(0.88, 0.50),
          const Offset(0.88, 0.70),
          const Offset(0.72, 0.72),
        ],
        [
          const Offset(0.16, 0.88),
          const Offset(0.84, 0.88),
          const Offset(0.72, 0.98),
          const Offset(0.28, 0.98),
        ],
        [
          const Offset(0.36, 0.40),
          const Offset(0.30, 0.16),
          const Offset(0.44, 0.40),
        ],
        [
          const Offset(0.56, 0.40),
          const Offset(0.50, 0.14),
          const Offset(0.72, 0.40),
        ],
      ]);

  static _Skeleton _butterfly() => _shape('Butterfly', [
        [
          const Offset(0.50, 0.24),
          const Offset(0.58, 0.50),
          const Offset(0.50, 0.80),
          const Offset(0.42, 0.50),
        ],
        [
          const Offset(0.50, 0.24),
          const Offset(0.14, 0.16),
          const Offset(0.10, 0.48),
          const Offset(0.42, 0.50),
        ],
        [
          const Offset(0.42, 0.50),
          const Offset(0.12, 0.58),
          const Offset(0.20, 0.86),
          const Offset(0.50, 0.80),
        ],
        [
          const Offset(0.50, 0.24),
          const Offset(0.86, 0.16),
          const Offset(0.90, 0.48),
          const Offset(0.58, 0.50),
        ],
        [
          const Offset(0.58, 0.50),
          const Offset(0.88, 0.58),
          const Offset(0.80, 0.86),
          const Offset(0.50, 0.80),
        ],
        [
          const Offset(0.50, 0.24),
          const Offset(0.26, 0.06),
          const Offset(0.50, 0.06),
        ],
      ]);

  static _Skeleton _royalCrown() => _shape('RoyalCrown', [
        [
          const Offset(0.14, 0.58),
          const Offset(0.26, 0.30),
          const Offset(0.38, 0.52),
          const Offset(0.50, 0.20),
          const Offset(0.62, 0.52),
          const Offset(0.74, 0.30),
          const Offset(0.86, 0.58),
        ],
        [
          const Offset(0.14, 0.58),
          const Offset(0.34, 0.58),
          const Offset(0.50, 0.58),
          const Offset(0.66, 0.58),
          const Offset(0.86, 0.58),
          const Offset(0.86, 0.88),
          const Offset(0.14, 0.88),
        ],
        [
          const Offset(0.34, 0.58),
          const Offset(0.66, 0.58),
          const Offset(0.50, 0.78),
        ],
        [
          const Offset(0.14, 0.58),
          const Offset(0.34, 0.58),
          const Offset(0.24, 0.76),
        ],
        [
          const Offset(0.66, 0.58),
          const Offset(0.86, 0.58),
          const Offset(0.76, 0.76),
        ],
      ]);

  static _Skeleton _crescentMoon() => _shape('CrescentMoon', [
        [
          const Offset(0.62, 0.10),
          const Offset(0.36, 0.20),
          const Offset(0.22, 0.46),
          const Offset(0.30, 0.74),
          const Offset(0.56, 0.90),
          const Offset(0.40, 0.70),
          const Offset(0.36, 0.46),
          const Offset(0.48, 0.24),
        ],
        [
          const Offset(0.62, 0.10),
          const Offset(0.80, 0.30),
          const Offset(0.86, 0.56),
          const Offset(0.72, 0.82),
          const Offset(0.56, 0.90),
        ],
        [
          const Offset(0.62, 0.10),
          const Offset(0.48, 0.24),
          const Offset(0.80, 0.30),
        ],
        [
          const Offset(0.56, 0.90),
          const Offset(0.40, 0.70),
          const Offset(0.72, 0.82),
        ],
      ]);

  static _Skeleton _apple() => _shape('Apple', [
        [
          const Offset(0.50, 0.30),
          const Offset(0.28, 0.24),
          const Offset(0.14, 0.44),
          const Offset(0.22, 0.72),
          const Offset(0.50, 0.90),
          const Offset(0.78, 0.72),
          const Offset(0.86, 0.44),
          const Offset(0.72, 0.24),
        ],
        [
          const Offset(0.50, 0.30),
          const Offset(0.50, 0.12),
          const Offset(0.68, 0.18),
        ],
        [
          const Offset(0.50, 0.30),
          const Offset(0.28, 0.24),
          const Offset(0.50, 0.12),
        ],
        [
          const Offset(0.22, 0.72),
          const Offset(0.50, 0.58),
          const Offset(0.78, 0.72),
        ],
      ]);

  static _Skeleton _candle() => _shape('Candle', [
        _box(0.34, 0.34, 0.66, 0.86),
        [
          const Offset(0.50, 0.12),
          const Offset(0.64, 0.30),
          const Offset(0.50, 0.42),
          const Offset(0.36, 0.30),
        ],
        [
          const Offset(0.34, 0.34),
          const Offset(0.50, 0.50),
          const Offset(0.34, 0.66),
        ],
        [
          const Offset(0.66, 0.34),
          const Offset(0.50, 0.50),
          const Offset(0.66, 0.66),
        ],
        [
          const Offset(0.20, 0.88),
          const Offset(0.80, 0.88),
          const Offset(0.68, 0.98),
          const Offset(0.32, 0.98),
        ],
      ]);

  static _Skeleton _kite() => _shape('Kite', [
        [
          const Offset(0.50, 0.08),
          const Offset(0.82, 0.40),
          const Offset(0.50, 0.72),
          const Offset(0.18, 0.40),
        ],
        [
          const Offset(0.50, 0.08),
          const Offset(0.50, 0.72),
          const Offset(0.18, 0.40),
        ],
        [
          const Offset(0.50, 0.08),
          const Offset(0.82, 0.40),
          const Offset(0.50, 0.72),
        ],
        [
          const Offset(0.50, 0.72),
          const Offset(0.62, 0.92),
          const Offset(0.38, 0.92),
        ],
      ]);

  static _Skeleton _paperAirplane() => _shape('PaperAirplane', [
        [
          const Offset(0.10, 0.44),
          const Offset(0.90, 0.20),
          const Offset(0.58, 0.82),
        ],
        [
          const Offset(0.10, 0.44),
          const Offset(0.42, 0.56),
          const Offset(0.58, 0.82),
        ],
        [
          const Offset(0.42, 0.56),
          const Offset(0.90, 0.20),
          const Offset(0.58, 0.82),
        ],
        [
          const Offset(0.10, 0.44),
          const Offset(0.90, 0.20),
          const Offset(0.42, 0.56),
        ],
      ]);

  static _Skeleton _mushroom() => _shape('Mushroom', [
        [
          const Offset(0.16, 0.54),
          const Offset(0.26, 0.24),
          const Offset(0.50, 0.12),
          const Offset(0.74, 0.24),
          const Offset(0.84, 0.54),
        ],
        [
          const Offset(0.16, 0.54),
          const Offset(0.38, 0.54),
          const Offset(0.50, 0.66),
          const Offset(0.62, 0.54),
          const Offset(0.84, 0.54),
        ],
        [
          const Offset(0.38, 0.66),
          const Offset(0.38, 0.90),
          const Offset(0.62, 0.90),
          const Offset(0.62, 0.66),
          const Offset(0.50, 0.66),
        ],
        [
          const Offset(0.16, 0.54),
          const Offset(0.38, 0.54),
          const Offset(0.26, 0.24),
        ],
        [
          const Offset(0.84, 0.54),
          const Offset(0.74, 0.24),
          const Offset(0.62, 0.54),
        ],
      ]);

  static _Skeleton _turtle() => _shape('Turtle', [
        _ellipse(0.50, 0.50, 0.32, 0.24, 6, phase: -pi / 2),
        [
          const Offset(0.18, 0.50),
          const Offset(0.06, 0.30),
          const Offset(0.06, 0.68),
        ],
        [
          const Offset(0.82, 0.50),
          const Offset(0.94, 0.30),
          const Offset(0.94, 0.68),
        ],
        [
          const Offset(0.32, 0.70),
          const Offset(0.24, 0.90),
          const Offset(0.42, 0.90),
        ],
        [
          const Offset(0.68, 0.70),
          const Offset(0.58, 0.90),
          const Offset(0.76, 0.90),
        ],
        [
          const Offset(0.50, 0.26),
          const Offset(0.50, 0.50),
          const Offset(0.24, 0.38),
        ],
        [
          const Offset(0.50, 0.26),
          const Offset(0.50, 0.50),
          const Offset(0.76, 0.38),
        ],
      ]);

  static _Skeleton _bell() => _shape('Bell', [
        [
          const Offset(0.50, 0.12),
          const Offset(0.30, 0.28),
          const Offset(0.22, 0.70),
          const Offset(0.78, 0.70),
          const Offset(0.70, 0.28),
        ],
        [
          const Offset(0.22, 0.70),
          const Offset(0.12, 0.86),
          const Offset(0.30, 0.86),
        ],
        [
          const Offset(0.78, 0.70),
          const Offset(0.70, 0.86),
          const Offset(0.88, 0.86),
        ],
        [
          const Offset(0.30, 0.44),
          const Offset(0.50, 0.56),
          const Offset(0.70, 0.44),
        ],
        [
          const Offset(0.50, 0.12),
          const Offset(0.40, 0.30),
          const Offset(0.60, 0.30),
        ],
      ]);

  static _Skeleton _key() => _shape('Key', [
        _ellipse(0.32, 0.34, 0.18, 0.18, 6),
        [
          const Offset(0.32, 0.16),
          const Offset(0.32, 0.52),
          const Offset(0.50, 0.34),
        ],
        [
          const Offset(0.32, 0.52),
          const Offset(0.86, 0.52),
          const Offset(0.86, 0.66),
          const Offset(0.32, 0.66),
        ],
        [
          const Offset(0.66, 0.66),
          const Offset(0.66, 0.84),
          const Offset(0.78, 0.84),
          const Offset(0.78, 0.66),
        ],
      ]);

  static _Skeleton _mountainLandscape() => _shape('MountainLandscape', [
        [
          const Offset(0.08, 0.78),
          const Offset(0.30, 0.28),
          const Offset(0.48, 0.60),
          const Offset(0.66, 0.18),
          const Offset(0.92, 0.78),
        ],
        [
          const Offset(0.08, 0.78),
          const Offset(0.92, 0.78),
          const Offset(0.80, 0.94),
          const Offset(0.20, 0.94),
        ],
        [
          const Offset(0.30, 0.28),
          const Offset(0.38, 0.46),
          const Offset(0.48, 0.60),
        ],
        [
          const Offset(0.66, 0.18),
          const Offset(0.76, 0.44),
          const Offset(0.92, 0.78),
        ],
        [
          const Offset(0.20, 0.94),
          const Offset(0.50, 0.70),
          const Offset(0.80, 0.94),
        ],
      ]);

  static _Skeleton _windmill() => _shape('Windmill', [
        [
          const Offset(0.34, 0.90),
          const Offset(0.40, 0.44),
          const Offset(0.60, 0.44),
          const Offset(0.66, 0.90),
        ],
        [
          const Offset(0.34, 0.54),
          const Offset(0.50, 0.38),
          const Offset(0.66, 0.54),
          const Offset(0.50, 0.70),
        ],
        [
          const Offset(0.50, 0.38),
          const Offset(0.20, 0.20),
          const Offset(0.34, 0.54),
        ],
        [
          const Offset(0.66, 0.54),
          const Offset(0.80, 0.20),
          const Offset(0.50, 0.38),
        ],
        [
          const Offset(0.50, 0.70),
          const Offset(0.20, 0.86),
          const Offset(0.34, 0.54),
        ],
        [
          const Offset(0.34, 0.54),
          const Offset(0.80, 0.86),
          const Offset(0.66, 0.54),
        ],
      ]);

  static _Skeleton _owl() => _shape('Owl', [
        [
          const Offset(0.50, 0.12),
          const Offset(0.24, 0.30),
          const Offset(0.20, 0.66),
          const Offset(0.50, 0.90),
          const Offset(0.80, 0.66),
          const Offset(0.76, 0.30),
        ],
        _ellipse(0.36, 0.40, 0.12, 0.12, 6),
        _ellipse(0.64, 0.40, 0.12, 0.12, 6),
        [
          const Offset(0.50, 0.52),
          const Offset(0.40, 0.66),
          const Offset(0.60, 0.66),
        ],
        [
          const Offset(0.36, 0.28),
          const Offset(0.24, 0.14),
          const Offset(0.30, 0.30),
        ],
        [
          const Offset(0.64, 0.28),
          const Offset(0.70, 0.14),
          const Offset(0.76, 0.30),
        ],
      ]);

  static _Skeleton _bicycle() => _shape('Bicycle', [
        _ellipse(0.24, 0.72, 0.16, 0.16, 6),
        _ellipse(0.76, 0.72, 0.16, 0.16, 6),
        [
          const Offset(0.24, 0.72),
          const Offset(0.46, 0.42),
          const Offset(0.76, 0.72),
          const Offset(0.54, 0.72),
        ],
        [
          const Offset(0.46, 0.42),
          const Offset(0.38, 0.24),
          const Offset(0.58, 0.24),
        ],
        [
          const Offset(0.54, 0.72),
          const Offset(0.68, 0.36),
          const Offset(0.80, 0.38),
        ],
      ]);

  static _Skeleton _castle() => _shape('Castle', [
        [
          const Offset(0.12, 0.86),
          const Offset(0.12, 0.42),
          const Offset(0.24, 0.42),
          const Offset(0.24, 0.24),
          const Offset(0.38, 0.24),
          const Offset(0.38, 0.42),
          const Offset(0.62, 0.42),
          const Offset(0.62, 0.24),
          const Offset(0.76, 0.24),
          const Offset(0.76, 0.42),
          const Offset(0.88, 0.42),
          const Offset(0.88, 0.86),
        ],
        [
          const Offset(0.12, 0.86),
          const Offset(0.88, 0.86),
          const Offset(0.88, 0.98),
          const Offset(0.12, 0.98),
        ],
        _box(0.44, 0.60, 0.56, 0.86),
        [
          const Offset(0.24, 0.42),
          const Offset(0.38, 0.42),
          const Offset(0.31, 0.60),
        ],
        [
          const Offset(0.62, 0.42),
          const Offset(0.76, 0.42),
          const Offset(0.69, 0.60),
        ],
      ]);

  static _Skeleton _spiderWeb() {
    const hub = Offset(0.50, 0.50);
    final rim = _ellipse(0.50, 0.50, 0.42, 0.42, 10);
    final inner = _ellipse(0.50, 0.50, 0.22, 0.22, 10, phase: pi / 10);
    return _shape('SpiderWeb', [
      rim,
      inner,
      ..._fan(hub, inner),
      for (var i = 0; i < 10; i++)
        [inner[i], rim[i], rim[(i + 1) % 10], inner[(i + 1) % 10]],
    ]);
  }

  static _Skeleton _peacock() => _shape('Peacock', [
        [
          const Offset(0.50, 0.48),
          const Offset(0.30, 0.66),
          const Offset(0.42, 0.90),
          const Offset(0.58, 0.90),
          const Offset(0.70, 0.66),
        ],
        ..._fan(const Offset(0.50, 0.48), [
          const Offset(0.14, 0.24),
          const Offset(0.28, 0.10),
          const Offset(0.50, 0.06),
          const Offset(0.72, 0.10),
          const Offset(0.86, 0.24),
          const Offset(0.70, 0.66),
          const Offset(0.30, 0.66),
        ]),
        [
          const Offset(0.50, 0.48),
          const Offset(0.36, 0.36),
          const Offset(0.50, 0.26),
          const Offset(0.64, 0.36),
        ],
      ]);

  static _Skeleton _sailingShip() => _shape('SailingShip', [
        [
          const Offset(0.10, 0.70),
          const Offset(0.90, 0.70),
          const Offset(0.78, 0.92),
          const Offset(0.22, 0.92),
        ],
        [
          const Offset(0.32, 0.12),
          const Offset(0.32, 0.70),
          const Offset(0.10, 0.70),
        ],
        [
          const Offset(0.32, 0.12),
          const Offset(0.64, 0.70),
          const Offset(0.32, 0.70),
        ],
        [
          const Offset(0.64, 0.20),
          const Offset(0.86, 0.70),
          const Offset(0.64, 0.70),
        ],
        [
          const Offset(0.10, 0.70),
          const Offset(0.32, 0.70),
          const Offset(0.22, 0.92),
        ],
        [
          const Offset(0.64, 0.70),
          const Offset(0.90, 0.70),
          const Offset(0.78, 0.92),
        ],
      ]);

  static _Skeleton _branchingTree() => _shape('BranchingTree', [
        [
          const Offset(0.42, 0.92),
          const Offset(0.42, 0.56),
          const Offset(0.58, 0.56),
          const Offset(0.58, 0.92),
        ],
        [
          const Offset(0.42, 0.72),
          const Offset(0.14, 0.44),
          const Offset(0.42, 0.56),
        ],
        [
          const Offset(0.58, 0.72),
          const Offset(0.86, 0.44),
          const Offset(0.58, 0.56),
        ],
        [
          const Offset(0.42, 0.56),
          const Offset(0.22, 0.20),
          const Offset(0.50, 0.38),
        ],
        [
          const Offset(0.58, 0.56),
          const Offset(0.78, 0.20),
          const Offset(0.50, 0.38),
        ],
        [
          const Offset(0.22, 0.20),
          const Offset(0.50, 0.10),
          const Offset(0.78, 0.20),
        ],
      ]);

  static _Skeleton _interlockingPentagons() => _shape('InterlockingPentagons', [
        _ringAt(5, 0.40, -pi / 2),
        _ringAt(5, 0.40, pi / 2),
        [
          const Offset(0.50, 0.10),
          const Offset(0.50, 0.90),
          const Offset(0.12, 0.50),
        ],
        [
          const Offset(0.50, 0.10),
          const Offset(0.50, 0.90),
          const Offset(0.88, 0.50),
        ],
      ]);

  static _Skeleton _lighthouse() => _shape('Lighthouse', [
        [
          const Offset(0.36, 0.90),
          const Offset(0.42, 0.40),
          const Offset(0.58, 0.40),
          const Offset(0.64, 0.90),
        ],
        [
          const Offset(0.42, 0.40),
          const Offset(0.40, 0.16),
          const Offset(0.60, 0.16),
          const Offset(0.58, 0.40),
        ],
        [
          const Offset(0.40, 0.16),
          const Offset(0.50, 0.06),
          const Offset(0.60, 0.16),
        ],
        [
          const Offset(0.40, 0.24),
          const Offset(0.14, 0.32),
          const Offset(0.22, 0.44),
        ],
        [
          const Offset(0.60, 0.24),
          const Offset(0.86, 0.32),
          const Offset(0.78, 0.44),
        ],
        [
          const Offset(0.36, 0.90),
          const Offset(0.64, 0.90),
          const Offset(0.72, 0.98),
          const Offset(0.28, 0.98),
        ],
      ]);

  static _Skeleton _elephant() => _shape('Elephant', [
        [
          const Offset(0.18, 0.34),
          const Offset(0.36, 0.20),
          const Offset(0.66, 0.20),
          const Offset(0.82, 0.34),
          const Offset(0.82, 0.58),
          const Offset(0.66, 0.70),
          const Offset(0.62, 0.90),
          const Offset(0.50, 0.90),
          const Offset(0.48, 0.62),
          const Offset(0.36, 0.62),
          const Offset(0.34, 0.90),
          const Offset(0.22, 0.90),
          const Offset(0.20, 0.58),
        ],
        [
          const Offset(0.66, 0.20),
          const Offset(0.90, 0.38),
          const Offset(0.74, 0.52),
        ],
        [
          const Offset(0.18, 0.34),
          const Offset(0.10, 0.18),
          const Offset(0.30, 0.24),
        ],
      ]);

  static _Skeleton _camera() => _shape('Camera', [
        [
          const Offset(0.14, 0.36),
          const Offset(0.30, 0.36),
          const Offset(0.38, 0.22),
          const Offset(0.62, 0.22),
          const Offset(0.70, 0.36),
          const Offset(0.86, 0.36),
          const Offset(0.86, 0.78),
          const Offset(0.14, 0.78),
        ],
        _ellipse(0.50, 0.56, 0.20, 0.20, 8),
        [
          const Offset(0.30, 0.36),
          const Offset(0.70, 0.36),
          const Offset(0.50, 0.56),
        ],
        [
          const Offset(0.14, 0.78),
          const Offset(0.86, 0.78),
          const Offset(0.74, 0.92),
          const Offset(0.26, 0.92),
        ],
      ]);

  static _Skeleton _ferrisWheel() {
    final rim = _ellipse(0.50, 0.50, 0.42, 0.42, 12);
    return _shape('FerrisWheel', [
      rim,
      ..._fan(const Offset(0.50, 0.50), rim),
      [
        const Offset(0.50, 0.50),
        const Offset(0.34, 0.92),
        const Offset(0.66, 0.92),
      ],
      [
        const Offset(0.34, 0.92),
        const Offset(0.66, 0.92),
        const Offset(0.74, 0.98),
        const Offset(0.26, 0.98),
      ],
    ]);
  }

  static _Skeleton _guitar() => _shape('Guitar', [
        [
          const Offset(0.50, 0.10),
          const Offset(0.60, 0.22),
          const Offset(0.60, 0.40),
          const Offset(0.76, 0.52),
          const Offset(0.76, 0.74),
          const Offset(0.50, 0.92),
          const Offset(0.24, 0.74),
          const Offset(0.24, 0.52),
          const Offset(0.40, 0.40),
          const Offset(0.40, 0.22),
        ],
        [
          const Offset(0.40, 0.22),
          const Offset(0.60, 0.22),
          const Offset(0.50, 0.34),
        ],
        [
          const Offset(0.50, 0.52),
          const Offset(0.36, 0.70),
          const Offset(0.64, 0.70),
        ],
        [
          const Offset(0.50, 0.10),
          const Offset(0.44, 0.04),
          const Offset(0.56, 0.04),
        ],
      ]);

  static _Skeleton _hotAirBalloon() => _shape('HotAirBalloon', [
        [
          const Offset(0.50, 0.06),
          const Offset(0.74, 0.20),
          const Offset(0.82, 0.44),
          const Offset(0.66, 0.62),
          const Offset(0.34, 0.62),
          const Offset(0.18, 0.44),
          const Offset(0.26, 0.20),
        ],
        [
          const Offset(0.50, 0.06),
          const Offset(0.62, 0.34),
          const Offset(0.50, 0.62),
          const Offset(0.38, 0.34),
        ],
        [
          const Offset(0.34, 0.62),
          const Offset(0.42, 0.82),
          const Offset(0.58, 0.82),
          const Offset(0.66, 0.62),
        ],
        [
          const Offset(0.42, 0.82),
          const Offset(0.58, 0.82),
          const Offset(0.50, 0.94),
        ],
      ]);

  static _Skeleton _dolphin() => _shape('Dolphin', [
        [
          const Offset(0.10, 0.52),
          const Offset(0.34, 0.32),
          const Offset(0.62, 0.28),
          const Offset(0.84, 0.42),
          const Offset(0.70, 0.58),
          const Offset(0.44, 0.64),
          const Offset(0.22, 0.62),
        ],
        [
          const Offset(0.10, 0.52),
          const Offset(0.06, 0.28),
          const Offset(0.26, 0.38),
        ],
        [
          const Offset(0.44, 0.64),
          const Offset(0.36, 0.88),
          const Offset(0.58, 0.70),
        ],
        [
          const Offset(0.62, 0.28),
          const Offset(0.56, 0.10),
          const Offset(0.76, 0.22),
        ],
        [
          const Offset(0.34, 0.32),
          const Offset(0.48, 0.48),
          const Offset(0.22, 0.62),
        ],
      ]);

  static _Skeleton _clockTower() => _shape('ClockTower', [
        [
          const Offset(0.34, 0.92),
          const Offset(0.38, 0.34),
          const Offset(0.62, 0.34),
          const Offset(0.66, 0.92),
        ],
        [
          const Offset(0.38, 0.34),
          const Offset(0.42, 0.14),
          const Offset(0.58, 0.14),
          const Offset(0.62, 0.34),
        ],
        [
          const Offset(0.42, 0.14),
          const Offset(0.50, 0.04),
          const Offset(0.58, 0.14),
        ],
        _ellipse(0.50, 0.46, 0.14, 0.14, 8),
        [
          const Offset(0.50, 0.46),
          const Offset(0.50, 0.36),
          const Offset(0.58, 0.52),
        ],
        [
          const Offset(0.34, 0.92),
          const Offset(0.66, 0.92),
          const Offset(0.74, 0.98),
          const Offset(0.26, 0.98),
        ],
      ]);

  static _Skeleton _trainEngine() => _shape('TrainEngine', [
        [
          const Offset(0.14, 0.78),
          const Offset(0.14, 0.46),
          const Offset(0.38, 0.46),
          const Offset(0.46, 0.28),
          const Offset(0.72, 0.28),
          const Offset(0.86, 0.46),
          const Offset(0.86, 0.78),
        ],
        [
          const Offset(0.14, 0.78),
          const Offset(0.86, 0.78),
          const Offset(0.78, 0.90),
          const Offset(0.22, 0.90),
        ],
        _ellipse(0.30, 0.84, 0.10, 0.10, 6),
        _ellipse(0.70, 0.84, 0.10, 0.10, 6),
        [
          const Offset(0.46, 0.28),
          const Offset(0.46, 0.12),
          const Offset(0.62, 0.12),
        ],
        [
          const Offset(0.38, 0.46),
          const Offset(0.50, 0.60),
          const Offset(0.72, 0.46),
        ],
      ]);

  static _Skeleton _geometricRose() {
    final inner = _ellipse(0.50, 0.50, 0.20, 0.20, 8, phase: pi / 8);
    final outer = _ellipse(0.50, 0.50, 0.44, 0.44, 8);
    return _shape('GeometricRose', [
      inner,
      outer,
      for (var i = 0; i < 8; i++)
        [inner[i], outer[i], outer[(i + 1) % 8], inner[(i + 1) % 8]],
    ]);
  }

  static _Skeleton _compass() {
    final rim = _ellipse(0.50, 0.50, 0.42, 0.42, 12);
    return _shape('Compass', [
      rim,
      _ellipse(0.50, 0.50, 0.22, 0.22, 8, phase: pi / 8),
      [
        const Offset(0.50, 0.08),
        const Offset(0.60, 0.44),
        const Offset(0.92, 0.50),
        const Offset(0.60, 0.56),
        const Offset(0.50, 0.92),
        const Offset(0.40, 0.56),
        const Offset(0.08, 0.50),
        const Offset(0.40, 0.44),
      ],
    ]);
  }

  static List<_Skeleton> _thematicFigures() {
    return [
      _smallHouse(),
      _fivePointStar(),
      _sailboat(),
      _umbrella(),
      _fish(),
      _diamondCrystal(),
      _rocket(),
      _coffeeCup(),
      _butterfly(),
      _royalCrown(),
      _crescentMoon(),
      _apple(),
      _candle(),
      _kite(),
      _paperAirplane(),
      _mushroom(),
      _turtle(),
      _bell(),
      _key(),
      _mountainLandscape(),
      _windmill(),
      _owl(),
      _bicycle(),
      _castle(),
      _spiderWeb(),
      _peacock(),
      _sailingShip(),
      _branchingTree(),
      _interlockingPentagons(),
      _lighthouse(),
      _elephant(),
      _camera(),
      _ferrisWheel(),
      _guitar(),
      _hotAirBalloon(),
      _dolphin(),
      _clockTower(),
      _trainEngine(),
      _geometricRose(),
      _compass(),
      ..._hardFigures(),
    ];
  }

  /// Builds a figure from closed loops, merging coincident points into
  /// shared vertices and dropping duplicate edges, then fitting it into
  /// a centred unit box with a UNIFORM scale (aspect ratio preserved).
  static _Skeleton _fig(String name, List<List<Offset>> loops,
      {bool lockOrientation = false,
      bool trail = false,
      bool hideNodeDots = false,
      List<List<Offset>> extraLinks = const []}) {
    final pts = <Offset>[];
    final idx = <String, int>{};
    int vid(Offset o) {
      final k = '${o.dx.toStringAsFixed(4)},${o.dy.toStringAsFixed(4)}';
      final existing = idx[k];
      if (existing != null) return existing;
      final id = pts.length;
      pts.add(o);
      idx[k] = id;
      return id;
    }

    final seen = <String>{};
    final links = <_Link>[];
    for (final loop in loops) {
      if (loop.length < 3) continue;
      for (var i = 0; i < loop.length; i++) {
        final a = vid(loop[i]);
        final b = vid(loop[(i + 1) % loop.length]);
        if (a == b) continue;
        final key = a < b ? '$a-$b' : '$b-$a';
        if (seen.add(key)) links.add(_Link(a, b));
      }
    }
    // Bridges are explicit two-point links so a closed helper loop
    // cannot accidentally add a third side (which would make the graph
    // all-even again and destroy the dead-end trap).
    for (final pair in extraLinks) {
      if (pair.length != 2) continue;
      final a = vid(pair[0]);
      final b = vid(pair[1]);
      if (a == b) continue;
      final key = a < b ? '$a-$b' : '$b-$a';
      if (seen.add(key)) links.add(_Link(a, b));
    }

    List<int> oddVertices() {
      final degree = List<int>.filled(pts.length, 0);
      for (final link in links) {
        degree[link.a]++;
        degree[link.b]++;
      }
      return [
        for (var i = 0; i < pts.length; i++)
          if (degree[i].isOdd) i,
      ];
    }

    List<List<int>> components() {
      final adjacency = List<List<int>>.generate(pts.length, (_) => <int>[]);
      for (final link in links) {
        adjacency[link.a].add(link.b);
        adjacency[link.b].add(link.a);
      }
      final visited = <int>{};
      final result = <List<int>>[];
      for (var start = 0; start < pts.length; start++) {
        if (!visited.add(start)) continue;
        final stack = [start];
        final component = <int>[];
        while (stack.isNotEmpty) {
          final current = stack.removeLast();
          component.add(current);
          for (final next in adjacency[current]) {
            if (visited.add(next)) stack.add(next);
          }
        }
        result.add(component);
      }
      return result;
    }

    void addEvenBridge(int a, int b) {
      final pa = pts[a];
      final pb = pts[b];
      final d = pb - pa;
      final len = d.distance;
      if (len < 1e-6) return;
      final n = Offset(-d.dy, d.dx) * (0.035 / len);
      final m = Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2);
      final p1 = pts.length;
      pts.add(pa + n);
      final p2 = pts.length;
      pts.add(m + n);
      final p3 = pts.length;
      pts.add(pb - n);
      final p4 = pts.length;
      pts.add(m - n);
      links.addAll([
        _Link(a, p1),
        _Link(p1, p2),
        _Link(p2, b),
        _Link(b, p3),
        _Link(p3, p4),
        _Link(p4, a),
      ]);
    }

    void addOddBridge(int a, int b) {
      final pa = pts[a];
      final pb = pts[b];
      final d = pb - pa;
      final len = d.distance;
      if (len < 1e-6) return;
      final n = Offset(-d.dy, d.dx) * (0.02 / len);
      final mid = pts.length;
      pts.add(Offset((pa.dx + pb.dx) / 2, (pa.dy + pb.dy) / 2) + n);
      links.addAll([_Link(a, mid), _Link(mid, b)]);
    }

    for (int guard = 0; guard < 64; guard++) {
      final parts = components();
      if (parts.length <= 1) break;
      parts.sort((a, b) => b.length.compareTo(a.length));
      final main = parts.first;
      final other = parts[1];
      var bestA = main.first;
      var bestB = other.first;
      var best = double.infinity;
      for (final a in main) {
        for (final b in other) {
          final d = (pts[a] - pts[b]).distance;
          if (d < best) {
            best = d;
            bestA = a;
            bestB = b;
          }
        }
      }
      addEvenBridge(bestA, bestB);
    }

    final keepOdd = <int>{};
    if (trail) {
      final endpoints = [...oddVertices()]
        ..sort((a, b) => pts[a].dy.compareTo(pts[b].dy));
      if (endpoints.length >= 2) {
        keepOdd.add(endpoints.first);
        keepOdd.add(endpoints.last);
      }
    }
    for (int guard = 0; guard < 64; guard++) {
      final repairable =
          oddVertices().where((v) => !keepOdd.contains(v)).toList();
      if (repairable.length < 2) break;
      var bestI = 0;
      var bestJ = 1;
      var bestScore = double.infinity;
      for (var i = 0; i < repairable.length; i++) {
        for (var j = i + 1; j < repairable.length; j++) {
          final d = (pts[repairable[i]] - pts[repairable[j]]).distance;
          final score = (d - 0.24).abs();
          if (score < bestScore) {
            bestScore = score;
            bestI = i;
            bestJ = j;
          }
        }
      }
      addOddBridge(repairable[bestI], repairable[bestJ]);
    }

    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in pts) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }
    const span = 0.94;
    final w = maxX - minX, h = maxY - minY;
    final scale = span / max(w <= 0 ? 1 : w, h <= 0 ? 1 : h);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final fitted = [
      for (final p in pts)
        Offset(0.5 + (p.dx - cx) * scale, 0.5 + (p.dy - cy) * scale),
    ];
    return _Skeleton(name, fitted, links,
        rotatable: false,
        eulerian: true,
        lockOrientation: lockOrientation,
        trail: trail,
        hideNodeDots: hideNodeDots);
  }

  static List<Offset> _starLoop(int tips,
      {double cx = 0.5,
      double cy = 0.5,
      double outer = 0.46,
      double inner = 0.20}) {
    final n = tips * 2;
    return [
      for (var i = 0; i < n; i++)
        _polar(cx, cy, i.isEven ? outer : inner, -pi / 2 + i * pi / tips),
    ];
  }

  static List<Offset> _bar(Offset a, Offset b, double thickness) {
    final d = b - a;
    final len = d.distance;
    if (len < 1e-6) return [a];
    final n = Offset(-d.dy, d.dx) * (thickness / len);
    final m = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    return [a, a + n, m + n, b, b - n, m - n];
  }

  static List<Offset> _gearLoop(
          double cx, double cy, double outer, double inner, int teeth) =>
      _starLoop(teeth, cx: cx, cy: cy, outer: outer, inner: inner);

  static List<_Skeleton> _hardFigures() {
    return [
      _twinSquaresConnectedByBridge(),
      _twinStarsConnectedByBridge(),
      _twinHousesConnectedByBridge(),
      _twoInterlockingRings(),
      _doubleHelix(),
      _suspensionBridge(),
      _geometricDragon(),
      _grandPiano(),
      _spaceSatellite(),
      _verticalSpan(
        'MultiBridgeCastle',
        [
          const [
            Offset(0.50, 0.06),
            Offset(0.78, 0.18),
            Offset(0.78, 0.38),
            Offset(0.50, 0.46),
            Offset(0.22, 0.38),
            Offset(0.22, 0.18),
          ],
          const [
            Offset(0.50, 0.46),
            Offset(0.64, 0.30),
            Offset(0.50, 0.20),
            Offset(0.36, 0.30),
          ],
          const [
            Offset(0.50, 0.58),
            Offset(0.84, 0.68),
            Offset(0.78, 0.92),
            Offset(0.22, 0.92),
            Offset(0.16, 0.68),
          ],
          const [
            Offset(0.50, 0.58),
            Offset(0.68, 0.72),
            Offset(0.60, 0.86),
            Offset(0.40, 0.86),
            Offset(0.32, 0.72),
          ],
        ],
        const Offset(0.50, 0.46),
        const Offset(0.50, 0.58),
      ),
      _verticalSpan(
        'SnowflakeNetwork',
        [
          _starLoop(6, cx: 0.5, cy: 0.27, outer: 0.20, inner: 0.09),
          _starLoop(6, cx: 0.5, cy: 0.73, outer: 0.20, inner: 0.09),
          const [
            Offset(0.50, 0.47),
            Offset(0.60, 0.36),
            Offset(0.72, 0.40),
            Offset(0.66, 0.54),
          ],
          const [
            Offset(0.50, 0.53),
            Offset(0.40, 0.64),
            Offset(0.28, 0.60),
            Offset(0.34, 0.46),
          ],
        ],
        const Offset(0.50, 0.47),
        const Offset(0.50, 0.53),
      ),
      _verticalSpan(
        'AncientCityWithMultipleBridges',
        [
          const [
            Offset(0.12, 0.42),
            Offset(0.12, 0.20),
            Offset(0.30, 0.20),
            Offset(0.30, 0.30),
            Offset(0.50, 0.30),
            Offset(0.50, 0.12),
            Offset(0.70, 0.12),
            Offset(0.70, 0.28),
            Offset(0.88, 0.28),
            Offset(0.88, 0.42),
          ],
          const [
            Offset(0.12, 0.42),
            Offset(0.88, 0.42),
            Offset(0.88, 0.50),
            Offset(0.12, 0.50),
          ],
          const [
            Offset(0.10, 0.64),
            Offset(0.10, 0.52),
            Offset(0.34, 0.52),
            Offset(0.34, 0.60),
            Offset(0.50, 0.60),
            Offset(0.50, 0.50),
            Offset(0.76, 0.50),
            Offset(0.76, 0.58),
            Offset(0.90, 0.58),
            Offset(0.90, 0.64),
          ],
          const [
            Offset(0.10, 0.64),
            Offset(0.90, 0.64),
            Offset(0.90, 0.92),
            Offset(0.10, 0.92),
          ],
        ],
        const Offset(0.50, 0.42),
        const Offset(0.50, 0.50),
      ),
    ];
  }

  static _Skeleton _twinSquaresConnectedByBridge() {
    const left = [
      Offset(0.08, 0.24),
      Offset(0.40, 0.24),
      Offset(0.40, 0.42),
      Offset(0.40, 0.62),
      Offset(0.40, 0.76),
      Offset(0.08, 0.76),
    ];
    const right = [
      Offset(0.60, 0.24),
      Offset(0.60, 0.42),
      Offset(0.60, 0.62),
      Offset(0.60, 0.76),
      Offset(0.92, 0.76),
      Offset(0.92, 0.24),
    ];
    return _shape('TwinSquaresConnectedByBridge', [
      left,
      right,
      _bar(const Offset(0.40, 0.42), const Offset(0.60, 0.42), 0.05),
      _bar(const Offset(0.40, 0.62), const Offset(0.60, 0.62), 0.05),
      _bar(const Offset(0.16, 0.50), const Offset(0.32, 0.50), 0.04),
      _bar(const Offset(0.68, 0.50), const Offset(0.84, 0.50), 0.04),
    ]);
  }

  static _Skeleton _twinStarsConnectedByBridge() {
    final left = _starLoop(5, cx: 0.27, cy: 0.50, outer: 0.20, inner: 0.09);
    final right = _starLoop(5, cx: 0.73, cy: 0.50, outer: 0.20, inner: 0.09);
    return _shape('TwinStarsConnectedByBridge', [
      left,
      right,
      [left[1], left[3], left[5], left[7], left[9]],
      [right[1], right[3], right[5], right[7], right[9]],
      _bar(left[2], right[8], 0.05),
      _bar(left[4], right[6], 0.05),
    ]);
  }

  static _Skeleton _twinHousesConnectedByBridge() {
    const leftRoof = [
      Offset(0.06, 0.50),
      Offset(0.20, 0.28),
      Offset(0.34, 0.50),
    ];
    const leftBody = [
      Offset(0.06, 0.50),
      Offset(0.34, 0.50),
      Offset(0.34, 0.66),
      Offset(0.34, 0.88),
      Offset(0.06, 0.88),
    ];
    const rightRoof = [
      Offset(0.66, 0.50),
      Offset(0.80, 0.28),
      Offset(0.94, 0.50),
    ];
    const rightBody = [
      Offset(0.66, 0.50),
      Offset(0.94, 0.50),
      Offset(0.94, 0.88),
      Offset(0.66, 0.88),
      Offset(0.66, 0.66),
    ];
    return _shape('TwinHousesConnectedByBridge', [
      leftRoof,
      leftBody,
      rightRoof,
      rightBody,
      _bar(const Offset(0.34, 0.66), const Offset(0.66, 0.66), 0.05),
      _bar(const Offset(0.34, 0.88), const Offset(0.66, 0.88), 0.05),
    ]);
  }

  static _Skeleton _twoInterlockingRings() {
    const top = Offset(0.50, 0.24);
    const bottom = Offset(0.50, 0.76);
    return _shape('TwoInterlockingRings', [
      [
        top,
        const Offset(0.34, 0.18),
        const Offset(0.16, 0.32),
        const Offset(0.08, 0.50),
        const Offset(0.16, 0.68),
        const Offset(0.34, 0.82),
        bottom,
        const Offset(0.42, 0.68),
        const Offset(0.42, 0.32),
      ],
      [
        top,
        const Offset(0.66, 0.18),
        const Offset(0.84, 0.32),
        const Offset(0.92, 0.50),
        const Offset(0.84, 0.68),
        const Offset(0.66, 0.82),
        bottom,
        const Offset(0.58, 0.68),
        const Offset(0.58, 0.32),
      ],
      [
        top,
        const Offset(0.30, 0.40),
        const Offset(0.24, 0.50),
        const Offset(0.30, 0.60),
        bottom,
        const Offset(0.44, 0.60),
        const Offset(0.44, 0.40),
      ],
      [
        top,
        const Offset(0.70, 0.40),
        const Offset(0.76, 0.50),
        const Offset(0.70, 0.60),
        bottom,
        const Offset(0.56, 0.60),
        const Offset(0.56, 0.40),
      ],
      [
        const Offset(0.34, 0.18),
        const Offset(0.66, 0.18),
        bottom,
        const Offset(0.66, 0.82),
        const Offset(0.34, 0.82),
        top,
      ],
    ]);
  }

  static _Skeleton _doubleHelix() {
    final left = [
      for (final y in [0.24, 0.50, 0.76]) _diamondAt(0.28, y, 0.12, 0.14),
    ];
    final right = [
      for (final y in [0.24, 0.50, 0.76]) _diamondAt(0.72, y, 0.12, 0.14),
    ];
    final loops = <List<Offset>>[...left, ...right];
    for (var i = 0; i < 3; i++) {
      loops.add(_bar(left[i][1], right[i][3], 0.05));
    }
    loops.add(_bar(left[0][2], right[1][0], 0.05));
    loops.add(_bar(left[1][2], right[2][0], 0.05));
    loops.add(_bar(left[2][1], right[0][2], 0.05));
    return _shape('DoubleHelix', loops);
  }

  static _Skeleton _suspensionBridge() {
    const leftTower = [
      Offset(0.12, 0.30),
      Offset(0.24, 0.30),
      Offset(0.24, 0.70),
      Offset(0.24, 0.84),
      Offset(0.12, 0.84),
      Offset(0.12, 0.70),
    ];
    const rightTower = [
      Offset(0.76, 0.30),
      Offset(0.76, 0.70),
      Offset(0.76, 0.84),
      Offset(0.88, 0.84),
      Offset(0.88, 0.70),
      Offset(0.88, 0.30),
    ];
    const cable = [
      Offset(0.12, 0.30),
      Offset(0.50, 0.12),
      Offset(0.88, 0.30),
      Offset(0.76, 0.44),
      Offset(0.64, 0.48),
      Offset(0.50, 0.54),
      Offset(0.36, 0.48),
      Offset(0.24, 0.44),
    ];
    const deck = [
      Offset(0.08, 0.70),
      Offset(0.36, 0.70),
      Offset(0.64, 0.70),
      Offset(0.92, 0.70),
      Offset(0.92, 0.84),
      Offset(0.64, 0.84),
      Offset(0.36, 0.84),
      Offset(0.08, 0.84),
    ];
    return _shape('SuspensionBridge', [
      leftTower,
      rightTower,
      cable,
      deck,
      _bar(const Offset(0.24, 0.44), const Offset(0.36, 0.70), 0.04),
      _bar(const Offset(0.36, 0.48), const Offset(0.64, 0.70), 0.04),
      _bar(const Offset(0.76, 0.44), const Offset(0.64, 0.70), 0.04),
    ]);
  }

  static _Skeleton _geometricDragon() {
    final b1 = _diamondAt(0.30, 0.52, 0.10, 0.12);
    final b2 = _diamondAt(0.48, 0.44, 0.10, 0.12);
    final b3 = _diamondAt(0.66, 0.52, 0.10, 0.12);
    return _shape('GeometricDragon', [
      b1,
      b2,
      b3,
      [b1[3], const Offset(0.08, 0.28), const Offset(0.10, 0.76), b1[2]],
      [b2[0], const Offset(0.42, 0.10), const Offset(0.58, 0.12), b2[1]],
      [b2[2], const Offset(0.58, 0.88), const Offset(0.42, 0.90), b2[3]],
      [b3[1], const Offset(0.90, 0.26), const Offset(0.92, 0.58), b3[2]],
      _bar(b1[1], b2[3], 0.05),
      _bar(b2[1], b3[3], 0.05),
    ]);
  }

  static _Skeleton _grandPiano() {
    final top = [
      for (final x in [0.16, 0.29, 0.42, 0.55, 0.68, 0.81, 0.90])
        Offset(x, 0.56),
    ];
    final bottom = [
      for (final x in [0.16, 0.29, 0.42, 0.55, 0.68, 0.81, 0.90])
        Offset(x, 0.78),
    ];
    final loops = <List<Offset>>[
      [
        const Offset(0.16, 0.24),
        const Offset(0.52, 0.14),
        const Offset(0.90, 0.28),
        ...top.reversed,
      ],
      [...top, ...bottom.reversed],
      [
        const Offset(0.16, 0.24),
        const Offset(0.52, 0.04),
        const Offset(0.90, 0.28),
      ],
    ];
    for (var i = 0; i < top.length; i += 2) {
      loops.add(_bar(top[i], bottom[i], 0.04));
    }
    loops.add(_bar(bottom[1], const Offset(0.29, 0.94), 0.04));
    loops.add(_bar(bottom[5], const Offset(0.81, 0.94), 0.04));
    return _shape('GrandPiano', loops);
  }

  static _Skeleton _spaceSatellite() {
    const body = [
      Offset(0.38, 0.38),
      Offset(0.62, 0.38),
      Offset(0.62, 0.50),
      Offset(0.62, 0.62),
      Offset(0.38, 0.62),
      Offset(0.38, 0.50),
    ];
    const leftPanel = [
      Offset(0.06, 0.42),
      Offset(0.38, 0.42),
      Offset(0.38, 0.58),
      Offset(0.06, 0.58),
    ];
    const rightPanel = [
      Offset(0.62, 0.42),
      Offset(0.94, 0.42),
      Offset(0.94, 0.58),
      Offset(0.62, 0.58),
    ];
    return _shape('SpaceSatellite', [
      body,
      leftPanel,
      rightPanel,
      [
        const Offset(0.50, 0.38),
        const Offset(0.42, 0.20),
        const Offset(0.50, 0.12),
        const Offset(0.58, 0.20),
      ],
      _bar(const Offset(0.22, 0.42), const Offset(0.22, 0.58), 0.04),
      _bar(const Offset(0.78, 0.42), const Offset(0.78, 0.58), 0.04),
      _bar(const Offset(0.50, 0.62), const Offset(0.50, 0.92), 0.04),
    ]);
  }

  static _Skeleton _verticalSpan(
    String name,
    List<List<Offset>> loops,
    Offset topAnchor,
    Offset bottomAnchor,
  ) {
    final mid = Offset(0.5, (topAnchor.dy + bottomAnchor.dy) / 2);
    return _fig(
      name,
      loops,
      lockOrientation: true,
      trail: true,
      hideNodeDots: true,
      extraLinks: [
        [topAnchor, mid],
        [mid, bottomAnchor],
      ],
    );
  }

  static List<_Skeleton> _newStudioFigures() {
    return [
      _mechanicalSpider(),
      _octopus(),
      _peacockWithDetailedFeathers(),
      _clockworkMachine(),
      _treehouseNetwork(),
      _eagleWithSpreadWings(),
      _citySkylineNetwork(),
      _impossibleKnot(),
      _solarSystem(),
      _mechanicalRobot(),
      _phoenix(),
      _galacticConstellation(),
      _interconnectedClockTowers(),
      _giantGearNetwork(),
      _theUltimateKingdom(),
    ];
  }

  static _Skeleton _mechanicalSpider() {
    final body = _ellipse(0.50, 0.48, 0.13, 0.12, 8);
    final loops = <List<Offset>>[body];
    for (var i = 0; i < 8; i++) {
      final angle = -pi / 2 + i * pi / 4;
      final foot = _polar(0.5, 0.48, 0.44, angle + 0.06);
      loops.add(_bar(body[i], foot, 0.035));
    }
    loops.add(_ellipse(0.50, 0.48, 0.06, 0.05, 6));
    return _shape('MechanicalSpider', loops);
  }

  static _Skeleton _octopus() {
    final head = _ellipse(0.50, 0.34, 0.22, 0.18, 8);
    final loops = <List<Offset>>[head];
    for (var i = 3; i <= 7; i++) {
      final tipX = 0.16 + (i - 3) * 0.17;
      loops.add(_bar(head[i], Offset(tipX, 0.92), 0.04));
    }
    loops.add(_bar(const Offset(0.50, 0.16), const Offset(0.50, 0.06), 0.03));
    return _shape('Octopus', loops);
  }

  static _Skeleton _peacockWithDetailedFeathers() {
    const center = Offset(0.50, 0.44);
    final rim = _ellipse(0.50, 0.40, 0.42, 0.32, 10, phase: pi);
    final loops = <List<Offset>>[
      _diamondAt(0.50, 0.64, 0.12, 0.20),
      rim,
    ];
    for (var i = 0; i < rim.length; i++) {
      loops.add(_bar(center, rim[i], 0.035));
    }
    loops.add(_bar(center, const Offset(0.50, 0.84), 0.04));
    return _shape('PeacockWithDetailedFeathers', loops);
  }

  static _Skeleton _clockworkMachine() {
    final central = _gearLoop(0.50, 0.50, 0.17, 0.11, 8);
    final satellites = [
      _gearLoop(0.20, 0.22, 0.12, 0.07, 6),
      _gearLoop(0.80, 0.22, 0.12, 0.07, 6),
      _gearLoop(0.20, 0.78, 0.12, 0.07, 6),
      _gearLoop(0.80, 0.78, 0.12, 0.07, 6),
    ];
    final loops = <List<Offset>>[central, ...satellites];
    for (var i = 0; i < satellites.length; i++) {
      loops.add(_bar(central[i * 2], satellites[i][0], 0.045));
    }
    return _shape('ClockworkMachine', loops);
  }

  static _Skeleton _treehouseNetwork() {
    final crowns = [
      _ellipse(0.24, 0.30, 0.16, 0.14, 8),
      _ellipse(0.50, 0.22, 0.18, 0.16, 8),
      _ellipse(0.76, 0.30, 0.16, 0.14, 8),
    ];
    final loops = <List<Offset>>[...crowns];
    for (var i = 0; i < crowns.length; i++) {
      loops.add(_bar(crowns[i][4], Offset(0.24 + i * 0.26, 0.90), 0.045));
    }
    loops.add(_bar(crowns[0][2], crowns[1][6], 0.04));
    loops.add(_bar(crowns[1][2], crowns[2][6], 0.04));
    loops.add(_bar(const Offset(0.24, 0.74), const Offset(0.50, 0.78), 0.04));
    loops.add(_bar(const Offset(0.50, 0.78), const Offset(0.76, 0.74), 0.04));
    return _shape('TreehouseNetwork', loops);
  }

  static _Skeleton _eagleWithSpreadWings() {
    final body = _diamondAt(0.50, 0.54, 0.11, 0.18);
    return _shape('EagleWithSpreadWings', [
      body,
      [body[0], const Offset(0.26, 0.14), const Offset(0.08, 0.30), body[1]],
      [body[0], const Offset(0.74, 0.14), const Offset(0.92, 0.30), body[3]],
      [body[2], const Offset(0.34, 0.90), const Offset(0.50, 0.78), body[3]],
      [body[2], const Offset(0.66, 0.90), const Offset(0.50, 0.78)],
      [body[0], const Offset(0.44, 0.06), const Offset(0.56, 0.06), body[1]],
      _bar(const Offset(0.26, 0.14), const Offset(0.08, 0.48), 0.04),
      _bar(const Offset(0.74, 0.14), const Offset(0.92, 0.48), 0.04),
    ]);
  }

  static _Skeleton _citySkylineNetwork() {
    final towers = [
      _box(0.06, 0.42, 0.24, 0.88),
      _box(0.28, 0.24, 0.46, 0.88),
      _box(0.54, 0.34, 0.72, 0.88),
      _box(0.76, 0.18, 0.94, 0.88),
    ];
    final loops = <List<Offset>>[...towers];
    for (var i = 0; i < towers.length - 1; i++) {
      loops.add(_bar(towers[i][1], towers[i + 1][0], 0.04));
      loops.add(_bar(towers[i][2], towers[i + 1][3], 0.04));
    }
    loops.add(_bar(const Offset(0.15, 0.42), const Offset(0.15, 0.08), 0.03));
    loops.add(_bar(const Offset(0.85, 0.18), const Offset(0.85, 0.06), 0.03));
    return _shape('CitySkylineNetwork', loops);
  }

  static _Skeleton _impossibleKnot() {
    const a = [
      Offset(0.20, 0.30),
      Offset(0.55, 0.18),
      Offset(0.80, 0.50),
      Offset(0.45, 0.82),
    ];
    const b = [
      Offset(0.20, 0.70),
      Offset(0.55, 0.82),
      Offset(0.80, 0.50),
      Offset(0.45, 0.18),
    ];
    return _shape('ImpossibleKnot', [
      a,
      b,
      _bar(const Offset(0.20, 0.30), const Offset(0.20, 0.70), 0.045),
      _bar(const Offset(0.45, 0.18), const Offset(0.55, 0.18), 0.04),
      _bar(const Offset(0.45, 0.82), const Offset(0.55, 0.82), 0.04),
    ]);
  }

  static _Skeleton _solarSystem() {
    final sun = _ellipse(0.50, 0.50, 0.14, 0.14, 10);
    final planets = [
      _ellipse(0.14, 0.20, 0.08, 0.08, 6),
      _ellipse(0.86, 0.20, 0.07, 0.07, 6),
      _ellipse(0.14, 0.80, 0.07, 0.07, 6),
      _ellipse(0.86, 0.80, 0.09, 0.09, 6),
    ];
    final loops = <List<Offset>>[sun, ...planets];
    for (var i = 0; i < planets.length; i++) {
      loops.add(_bar(sun[i * 2], planets[i][0], 0.035));
    }
    loops.add(_ellipse(0.50, 0.50, 0.42, 0.38, 12));
    return _shape('SolarSystem', loops);
  }

  static _Skeleton _mechanicalRobot() {
    const head = [
      Offset(0.36, 0.10),
      Offset(0.64, 0.10),
      Offset(0.64, 0.34),
      Offset(0.36, 0.34),
    ];
    const torso = [
      Offset(0.32, 0.38),
      Offset(0.68, 0.38),
      Offset(0.68, 0.72),
      Offset(0.32, 0.72),
    ];
    return _shape('MechanicalRobot', [
      head,
      torso,
      _bar(const Offset(0.36, 0.22), const Offset(0.64, 0.22), 0.04),
      _bar(const Offset(0.36, 0.10), const Offset(0.10, 0.30), 0.04),
      _bar(const Offset(0.64, 0.10), const Offset(0.90, 0.30), 0.04),
      _bar(const Offset(0.32, 0.72), const Offset(0.20, 0.94), 0.045),
      _bar(const Offset(0.68, 0.72), const Offset(0.80, 0.94), 0.045),
      _bar(const Offset(0.42, 0.50), const Offset(0.58, 0.50), 0.04),
    ]);
  }

  static _Skeleton _phoenix() {
    final body = _diamondAt(0.50, 0.46, 0.12, 0.22);
    return _shape('Phoenix', [
      body,
      [body[0], const Offset(0.20, 0.10), const Offset(0.06, 0.36), body[1]],
      [body[0], const Offset(0.80, 0.10), const Offset(0.94, 0.36), body[3]],
      [body[2], const Offset(0.28, 0.94), const Offset(0.42, 0.76), body[3]],
      [body[2], const Offset(0.72, 0.94), const Offset(0.58, 0.76), body[1]],
      [body[0], const Offset(0.44, 0.04), const Offset(0.56, 0.04), body[1]],
      _bar(body[1], body[3], 0.04),
      _bar(const Offset(0.20, 0.10), const Offset(0.06, 0.60), 0.035),
      _bar(const Offset(0.80, 0.10), const Offset(0.94, 0.60), 0.035),
    ]);
  }

  static _Skeleton _galacticConstellation() {
    final stars = _ellipse(0.50, 0.50, 0.42, 0.34, 8, phase: -pi / 2);
    final loops = <List<Offset>>[stars];
    for (var i = 0; i < stars.length; i++) {
      loops.add(_bar(stars[i], stars[(i + 2) % stars.length], 0.035));
    }
    loops.add(_starLoop(5, cx: 0.5, cy: 0.5, outer: 0.18, inner: 0.08));
    return _shape('GalacticConstellation', loops);
  }

  static _Skeleton _interconnectedClockTowers() {
    final left = _box(0.10, 0.30, 0.40, 0.92);
    final right = _box(0.60, 0.22, 0.90, 0.92);
    return _shape('InterconnectedClockTowers', [
      left,
      right,
      _ellipse(0.25, 0.46, 0.10, 0.10, 8),
      _ellipse(0.75, 0.38, 0.10, 0.10, 8),
      _bar(const Offset(0.25, 0.46), const Offset(0.25, 0.18), 0.03),
      _bar(const Offset(0.75, 0.38), const Offset(0.75, 0.10), 0.03),
      _bar(const Offset(0.40, 0.64), const Offset(0.60, 0.64), 0.05),
      _bar(const Offset(0.40, 0.92), const Offset(0.60, 0.92), 0.05),
    ]);
  }

  static _Skeleton _giantGearNetwork() {
    final gears = [
      _gearLoop(0.50, 0.24, 0.18, 0.11, 8),
      _gearLoop(0.24, 0.72, 0.16, 0.10, 7),
      _gearLoop(0.76, 0.72, 0.16, 0.10, 7),
    ];
    return _shape('GiantGearNetwork', [
      ...gears,
      _bar(gears[0][4], gears[1][0], 0.045),
      _bar(gears[0][0], gears[2][0], 0.045),
      _bar(gears[1][4], gears[2][4], 0.045),
    ]);
  }

  static _Skeleton _theUltimateKingdom() {
    const keep = [
      Offset(0.30, 0.34),
      Offset(0.70, 0.34),
      Offset(0.70, 0.88),
      Offset(0.30, 0.88),
    ];
    const leftTower = [
      Offset(0.08, 0.46),
      Offset(0.22, 0.20),
      Offset(0.36, 0.46),
      Offset(0.36, 0.88),
      Offset(0.08, 0.88),
    ];
    const rightTower = [
      Offset(0.64, 0.46),
      Offset(0.78, 0.20),
      Offset(0.92, 0.46),
      Offset(0.92, 0.88),
      Offset(0.64, 0.88),
    ];
    return _shape('TheUltimateKingdom', [
      keep,
      leftTower,
      rightTower,
      _starLoop(6, cx: 0.50, cy: 0.18, outer: 0.12, inner: 0.05),
      _bar(const Offset(0.22, 0.20), const Offset(0.50, 0.34), 0.04),
      _bar(const Offset(0.78, 0.20), const Offset(0.50, 0.34), 0.04),
      _bar(const Offset(0.30, 0.88), const Offset(0.70, 0.88), 0.05),
      _bar(const Offset(0.50, 0.88), const Offset(0.50, 0.98), 0.035),
    ]);
  }

  static Offset _polar(double cx, double cy, double r, double a) =>
      Offset(cx + r * cos(a), cy + r * sin(a));

  static List<Offset> _ringAt(int n, double radius, double phase) => [
        for (var i = 0; i < n; i++)
          _polar(0.5, 0.5, radius, phase + i * 2 * pi / n),
      ];

  // ── Figure construction ───────────────────────────────────────────

  OneLineLevel? _tryBuild(
    _Skeleton sk,
    _Config cfg,
    Random rng,
    int number,
    bool mirror,
  ) {
    final used = Set<int>.identity();
    if (sk.trail || sk.eulerian) {
      // Authored circuits and bridge trails ship every link so their
      // topology stays intact.
      for (var i = 0; i < sk.links.length; i++) {
        used.add(i);
      }
    } else {
      used.addAll(_trailWalk(sk, cfg.minCoverage, rng));
      if (used.isEmpty) return null;
      _enrichWithParitySafeLinks(sk, used, cfg.maxExtras, rng);
      // The whole point of this game variant: start anywhere on the
      // outline. That demands an Eulerian circuit - every degree even.
      if (!_repairToAllEven(sk, used)) return null;
    }

    // Keep only vertices the walk actually touched, remapping ids.
    final touched = <int>{};
    for (final li in used) {
      touched.add(sk.links[li].a);
      touched.add(sk.links[li].b);
    }
    if (touched.length < 3) return null;

    // Symmetric figures spin to a fresh orientation each level;
    // pictorial ones get a subtle hand-drawn tilt so no two levels
    // ever render the exact same figure.
    final angle = sk.lockOrientation
        ? 0.0
        : sk.rotatable
            ? rng.nextDouble() * 2 * pi
            : (rng.nextDouble() - 0.5) * 0.24;
    final cosA = cos(angle);
    final sinA = sin(angle);

    // Extent the unrotated figure occupies — rotating around the box
    // centre can swing asymmetric shapes (stars) out of frame, so the
    // final cloud is re-fitted into exactly this span afterwards.
    var fitSpan = 1.0;
    {
      var mnx = double.infinity;
      var mny = double.infinity;
      var mxx = double.negativeInfinity;
      var mxy = double.negativeInfinity;
      for (final p in sk.points) {
        if (p.dx < mnx) mnx = p.dx;
        if (p.dy < mny) mny = p.dy;
        if (p.dx > mxx) mxx = p.dx;
        if (p.dy > mxy) mxy = p.dy;
      }
      fitSpan = max(mxx - mnx, mxy - mny);
    }

    final remap = <int, int>{};
    final vertices = <OneLineVertex>[];
    // First pass: rotate + mirror the touched points.
    final order = touched.toList(growable: false);
    final placed = <Offset>[];
    for (final p in order) {
      final src = sk.points[p];
      var pos = Offset(
        (src.dx - 0.5) * cosA - (src.dy - 0.5) * sinA,
        (src.dx - 0.5) * sinA + (src.dy - 0.5) * cosA,
      );
      if (mirror) pos = Offset(-pos.dx, pos.dy);
      placed.add(pos);
    }
    // Second pass: re-centre and clamp back into the figure's span.
    var mnx = double.infinity;
    var mny = double.infinity;
    var mxx = double.negativeInfinity;
    var mxy = double.negativeInfinity;
    for (final p in placed) {
      if (p.dx < mnx) mnx = p.dx;
      if (p.dy < mny) mny = p.dy;
      if (p.dx > mxx) mxx = p.dx;
      if (p.dy > mxy) mxy = p.dy;
    }
    final w2 = mxx - mnx;
    final h2 = mxy - mny;
    final fit = fitSpan / max(w2 <= 0 ? 1 : w2, h2 <= 0 ? 1 : h2);
    final cx2 = (mnx + mxx) / 2;
    final cy2 = (mny + mxy) / 2;
    for (var i = 0; i < order.length; i++) {
      final pos = Offset(
        0.5 + (placed[i].dx - cx2) * fit,
        0.5 + (placed[i].dy - cy2) * fit,
      );
      remap[order[i]] = vertices.length;
      vertices.add(OneLineVertex(id: vertices.length, position: pos));
    }

    final edges = <OneLineEdge>[];
    final seenPairs = <String>{};
    for (final li in used) {
      final link = sk.links[li];
      final a = remap[link.a]!;
      final b = remap[link.b]!;
      final key = a < b ? '$a-$b' : '$b-$a';
      if (!seenPairs.add(key)) continue; // duplicate guard
      edges.add(OneLineEdge(id: edges.length, a: a, b: b));
    }
    if (edges.length < cfg.minEdges) return null;

    // Connected + 0 odd vertices for circuits, exactly 2 for bridge
    // trails. A trail's odd endpoints are the only legal start/finish.
    if (!_isConnected(vertices.length, edges)) return null;
    final odds = _oddDegreeVertices(vertices.length, edges);
    if (sk.trail) {
      if (odds.length != 2) return null;
    } else if (odds.isNotEmpty) {
      return null;
    }

    // Playability: reject cramped layouts (lines too close, strokes
    // too short, shallow-angle overlaps) before shipping the level.
    if (!_isDrawable(vertices, edges,
        minSpan: cfg.minSpan,
        gap: cfg.minGap,
        minCrossingAngle: cfg.minCrossingAngle)) {
      return null;
    }

    // Tutorial levels (1-10) are all-even circuits, so their solution
    // works from any outline point. Later levels keep a hidden canonical
    // solution start; bridge trails have two valid odd endpoints. The UI
    // never reveals or enforces either one — wrong starts just dead-end.
    final startAnywhere = number <= 10 && !sk.trail;
    final startVertex = startAnywhere
        ? 0
        : sk.trail
            ? _chooseTrailStart(vertices, odds)
            : _chooseStartVertex(vertices, edges, sk.startHint);
    final alternateStartVertex =
        sk.trail ? odds.firstWhere((v) => v != startVertex) : null;

    final solution =
        hierholzer(vertices.length, edges, startAnywhere ? null : startVertex);
    if (solution == null || solution.length != edges.length + 1) return null;
    if (sk.trail && !odds.contains(solution.last)) return null;

    final par = max(6, edges.length * 5);
    return OneLineLevel(
      number: number,
      name: sk.name,
      difficulty: cfg.difficulty,
      vertices: vertices,
      edges: edges,
      solution: solution,
      suggestedStarts: const [],
      parSeconds: par,
      startAnywhere: startAnywhere,
      startVertex: startVertex,
      alternateStartVertex: alternateStartVertex,
      hideNodeDots: sk.hideNodeDots,
    );
  }

  /// Hidden canonical solution start: the busiest junction (highest
  /// degree), breaking ties toward the bottom-most then left-most vertex
  /// so the generated solution is stable. Honours a figure's startHint
  /// when the figure author has one in mind.
  static int _chooseStartVertex(
      List<OneLineVertex> vertices, List<OneLineEdge> edges, int? hint) {
    if (hint != null && hint >= 0 && hint < vertices.length) return hint;
    final degree = List<int>.filled(vertices.length, 0);
    for (final e in edges) {
      degree[e.a]++;
      degree[e.b]++;
    }
    var best = 0;
    for (var v = 1; v < vertices.length; v++) {
      final d = degree[v];
      final bd = degree[best];
      if (d > bd) {
        best = v;
      } else if (d == bd) {
        final pv = vertices[v].position;
        final pb = vertices[best].position;
        if (pv.dy > pb.dy + 1e-9 ||
            (pv.dy > pb.dy - 1e-9 && pv.dx < pb.dx - 1e-9)) {
          best = v;
        }
      }
    }
    return best;
  }

  /// Bridge-trail start: the upper (then left-most) odd endpoint. Both
  /// odds are legal, but one stable choice keeps the hidden canonical
  /// start and the authored solution consistent.
  static int _chooseTrailStart(
      List<OneLineVertex> vertices, List<int> oddVertices) {
    var best = oddVertices.first;
    for (final v in oddVertices.skip(1)) {
      final p = vertices[v].position;
      final bp = vertices[best].position;
      if (p.dy < bp.dy - 1e-9 || (p.dy < bp.dy + 1e-9 && p.dx < bp.dx - 1e-9)) {
        best = v;
      }
    }
    return best;
  }

  /// Randomized self-avoiding-in-links walk. The returned link set is an
  /// Eulerian edge set by construction (the walk uses each exactly once).
  Set<int> _trailWalk(_Skeleton sk, double minCoverage, Random rng) {
    final target =
        (sk.links.length * minCoverage).ceil().clamp(3, sk.links.length);
    final adjacency = List<List<int>>.generate(sk.points.length, (_) => <int>[],
        growable: false);
    for (int i = 0; i < sk.links.length; i++) {
      adjacency[sk.links[i].a].add(i);
      adjacency[sk.links[i].b].add(i);
    }

    var current = rng.nextInt(sk.points.length);
    final usedLinks = <int>{};

    while (usedLinks.length < target) {
      final options =
          adjacency[current].where((l) => !usedLinks.contains(l)).toList();
      if (options.isEmpty) break;
      options.shuffle(rng);
      final chosen = options.first;
      usedLinks.add(chosen);
      current = sk.links[chosen].other(current);
    }
    return usedLinks;
  }

  /// Adds unused skeleton links while keeping "<= 2 odd-degree
  /// vertices". Adding an edge toggles both endpoint parities:
  ///  even+even -> odd count +2 (only allowed when currently 0)
  ///  odd+odd   -> odd count ->2 (always safe)
  ///  mixed     -> net 0          (always safe)
  void _enrichWithParitySafeLinks(
    _Skeleton sk,
    Set<int> used,
    int maxExtras,
    Random rng,
  ) {
    final candidates = <int>[
      for (int i = 0; i < sk.links.length; i++)
        if (!used.contains(i)) i
    ]..shuffle(rng);

    var added = 0;
    final degrees = List<int>.filled(sk.points.length, 0);
    for (final li in used) {
      degrees[sk.links[li].a]++;
      degrees[sk.links[li].b]++;
    }

    for (final li in candidates) {
      if (added >= maxExtras) break;
      final link = sk.links[li];
      if (degrees[link.a] >= 4 || degrees[link.b] >= 4) continue;
      final bothEven = degrees[link.a].isEven && degrees[link.b].isEven;
      final oddCount = degrees.where((d) => d.isOdd).length;
      if (bothEven && oddCount > 0) continue; // would create 4 odds
      used.add(li);
      degrees[link.a]++;
      degrees[link.b]++;
      added++;
    }
  }

  /// Forces every degree even so the figure becomes an Eulerian
  /// circuit, i.e. traceable starting anywhere on its outline.
  ///
  /// Pair repair: toggling two odd endpoints with one edge cancels both
  /// odds; removing such an edge does too. Returns false when a fully
  /// even connected figure is out of reach for this attempt.
  bool _repairToAllEven(_Skeleton sk, Set<int> used) {
    for (int round = 0; round < 24; round++) {
      final degrees = List<int>.filled(sk.points.length, 0);
      for (final li in used) {
        degrees[sk.links[li].a]++;
        degrees[sk.links[li].b]++;
      }
      final odds = <int>[
        for (int v = 0; v < sk.points.length; v++)
          if (degrees[v].isOdd) v
      ];
      if (odds.isEmpty) return true;
      if (odds.length.isOdd) return false; // impossible state

      bool fixed = false;

      // 1) Add an unused link bridging two odd vertices.
      for (int i = 0; i < sk.links.length && !fixed; i++) {
        if (used.contains(i)) continue;
        final l = sk.links[i];
        final aOdd = odds.contains(l.a);
        final bOdd = odds.contains(l.b);
        if (aOdd && bOdd) {
          used.add(i);
          fixed = true;
        }
      }

      // 2) Otherwise drop a used link between two odd vertices.
      if (!fixed) {
        for (int i = 0; i < sk.links.length && !fixed; i++) {
          if (!used.contains(i)) continue;
          final l = sk.links[i];
          if (odds.contains(l.a) && odds.contains(l.b)) {
            used.remove(i);
            fixed = true;
          }
        }
      }

      if (!fixed) return false;
    }
    return false;
  }

  // ── Graph utilities ─────────────────────────────────────────────────

  static List<int> _oddDegreeVertices(int n, List<OneLineEdge> edges) {
    final deg = List<int>.filled(n, 0);
    for (final e in edges) {
      deg[e.a]++;
      deg[e.b]++;
    }
    return [
      for (int v = 0; v < n; v++)
        if (deg[v].isOdd) v
    ];
  }

  static bool _isConnected(int n, List<OneLineEdge> edges) {
    if (edges.isEmpty) return n <= 1;
    final adjacency = List<List<int>>.generate(n, (_) => <int>[]);
    for (final e in edges) {
      adjacency[e.a].add(e.b);
      adjacency[e.b].add(e.a);
    }
    final seen = <int>{edges.first.a};
    final stack = <int>[edges.first.a];
    while (stack.isNotEmpty) {
      for (final nxt in adjacency[stack.removeLast()]) {
        if (seen.add(nxt)) stack.add(nxt);
      }
    }
    for (final e in edges) {
      if (!seen.contains(e.a) || !seen.contains(e.b)) return false;
    }
    return true;
  }

  /// Hierholzer's algorithm. Returns the vertex sequence of an Eulerian
  /// trail using every edge exactly once, or null when impossible.
  static List<int>? hierholzer(int n, List<OneLineEdge> edges, int? startHint) {
    if (edges.isEmpty) return null;
    if (!_isConnected(n, edges)) return null;
    final odds = _oddDegreeVertices(n, edges);
    if (odds.length > 2) return null;

    final remaining = <int, Map<int, int>>{}; // u -> (v -> multiplicity)
    for (final e in edges) {
      (remaining[e.a] ??= {})[e.b] = ((remaining[e.a]?[e.b]) ?? 0) + 1;
      (remaining[e.b] ??= {})[e.a] = ((remaining[e.b]?[e.a]) ?? 0) + 1;
    }

    int start = startHint ?? edges.first.a;
    final stack = <int>[start];
    final trail = <int>[];

    while (stack.isNotEmpty) {
      final v = stack.last;
      final outs = remaining[v];
      if (outs == null || outs.isEmpty) {
        trail.add(stack.removeLast());
        continue;
      }
      final next = outs.keys.first;
      if (outs[next]! <= 1) {
        outs.remove(next);
      } else {
        outs[next] = outs[next]! - 1;
      }
      final back = remaining[next];
      if (back![v]! <= 1) {
        back.remove(v);
      } else {
        back[v] = back[v]! - 1;
      }
      stack.add(next);
    }

    if (trail.length != edges.length + 1) return null;
    return trail.reversed.toList(growable: false);
  }

  // ── Geometry helpers ────────────────────────────────────────────────

  /// True when the layout is comfortable to trace: long-enough
  /// strokes, generous gaps between non-touching segments, and any
  /// crossings steep enough to be unambiguous.
  static bool _isDrawable(
    List<OneLineVertex> vertices,
    List<OneLineEdge> edges, {
    double minSpan = minEdgeSpan,
    double gap = minSegmentGap,
    double minCrossingAngle = minCrossingAngleDeg,
  }) {
    final p = [for (final v in vertices) v.position];
    for (final e in edges) {
      if ((p[e.b] - p[e.a]).distance < minSpan) return false;
    }
    for (int i = 0; i < edges.length; i++) {
      for (int j = i + 1; j < edges.length; j++) {
        final e = edges[i];
        final f = edges[j];
        final adjacent = e.a == f.a || e.a == f.b || e.b == f.a || e.b == f.b;
        if (adjacent) continue;
        final rel = _segmentRelation(p[e.a], p[e.b], p[f.a], p[f.b]);
        if (rel.crossing) {
          var acute =
              ((p[e.b] - p[e.a]).direction - (p[f.b] - p[f.a]).direction)
                      .abs() %
                  pi;
          if (acute > pi / 2) acute = pi - acute;
          if (acute * 180 / pi < minCrossingAngle) return false;
        } else if (rel.distance < gap) {
          return false;
        }
      }
    }
    return true;
  }

  /// Proper-crossing flag plus closest approach of two segments.
  static ({bool crossing, double distance}) _segmentRelation(
      Offset a1, Offset a2, Offset b1, Offset b2) {
    final d1 = a2 - a1;
    final d2 = b2 - b1;
    final denom = d1.dx * d2.dy - d1.dy * d2.dx;
    if (denom.abs() > 1e-9) {
      final wx = b1.dx - a1.dx;
      final wy = b1.dy - a1.dy;
      final t = (wx * d2.dy - wy * d2.dx) / denom;
      final u = (wx * d1.dy - wy * d1.dx) / denom;
      if (t >= 0 && t <= 1 && u >= 0 && u <= 1) {
        return (crossing: true, distance: 0.0);
      }
    }
    var best = _pointSegmentDist(a1, b1, b2);
    best = min(best, _pointSegmentDist(a2, b1, b2));
    best = min(best, _pointSegmentDist(b1, a1, a2));
    best = min(best, _pointSegmentDist(b2, a1, a2));
    return (crossing: false, distance: best);
  }

  static double _pointSegmentDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.distanceSquared;
    final t = len2 == 0
        ? 0.0
        : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (a + ab * t - p).distance;
  }

  static List<Offset> _ringPoints(int n,
      {Offset center = const Offset(0.5, 0.5), double radius = 0.40}) {
    return List.generate(n, (i) {
      final angle = -pi / 2 + i * 2 * pi / n;
      return Offset(center.dx + radius * cos(angle) * 0.92,
          center.dy + radius * sin(angle));
    });
  }

  /// Star-tip layout: alternating outer/inner radii produce crisp
  /// star outlines without intersection artifacts.
  static List<Offset> _starPoints(int n,
      {Offset center = const Offset(0.5, 0.52), double innerFactor = 0.45}) {
    return List.generate(n, (i) {
      final angle = -pi / 2 + i * 2 * pi / n;
      final r = i.isEven ? 0.42 : 0.42 * innerFactor;
      return Offset(center.dx + r * cos(angle), center.dy + r * sin(angle));
    });
  }

  static List<Offset> _gridPoints(int n) {
    return [
      for (int r = 0; r < n; r++)
        for (int c = 0; c < n; c++)
          Offset(
            _margin + c * (1 - 2 * _margin) / (n - 1),
            _margin + r * (1 - 2 * _margin) / (n - 1),
          )
    ];
  }

  /// Absolute fallback: regular polygon cycle - always Eulerian.
  static OneLineLevel _fallbackCycle(int number) {
    final sides = 3 + number % 6;
    final pts = _ringPoints(sides);
    final vertices =
        List.generate(sides, (i) => OneLineVertex(id: i, position: pts[i]));
    final edges = List.generate(
        sides, (i) => OneLineEdge(id: i, a: i, b: (i + 1) % sides));
    final solution = [for (int i = 0; i <= sides; i++) i % sides];
    return OneLineLevel(
      number: number,
      name: 'Polygon',
      difficulty: 'Easy',
      vertices: vertices,
      edges: edges,
      solution: solution,
      suggestedStarts: const [],
      parSeconds: max(6, sides * 5),
    );
  }
}
