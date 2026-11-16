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

  /// Preferred locked-level start vertex (index into [points]). When
  /// null the builder picks the highest-degree / lowest vertex.
  final int? startHint;

  const _Skeleton(this.name, this.points, this.links,
      {this.rotatable = false, this.eulerian = false, this.startHint});
}

class _Config {
  final List<int> skeletonPool;
  final double minCoverage; // fraction of skeleton links used by the walk
  final int maxExtras; // parity chords added after the walk
  final int minEdges;
  final String difficulty;

  /// Symmetric levels ignore [skeletonPool] and build a fresh, already
  /// Eulerian figure (mandala / rosette / flower / wheel) every attempt,
  /// so the endless zone never repeats a shape.
  final bool procedural;

  /// Drawability thresholds -- symmetric figures relax these a little;
  /// curated figures use the strict class defaults.
  final double minSpan;
  final double minGap;

  const _Config({
    required this.skeletonPool,
    required this.minCoverage,
    required this.maxExtras,
    required this.minEdges,
    required this.difficulty,
    this.procedural = false,
    this.minSpan = OneLineGenerator.minEdgeSpan,
    this.minGap = OneLineGenerator.minSegmentGap,
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

  /// Effective drawability thresholds for [number] — dense procedural
  /// webs relax the stroke/gap minimums slightly.
  static double minSpanFor(int number) => _configFor(number).minSpan;
  static double minGapFor(int number) => _configFor(number).minGap;

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
    // Hand-drawn figures that ACTUALLY look like something (trees,
    // houses, animals, faces, premium geometry...) instead of plain
    // geometric primitives. Each figure is built as a union of closed
    // loops, which makes every vertex even-degree by construction, so
    // the whole figure ships exactly as drawn. Ordered easiest ->
    // hardest; edge count climbs monotonically.
    ..._thematicFigures(),
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
        startHint: s.startHint);
  }

  /// Campaign: every one of these levels is a DIFFERENT hand-crafted
  /// one-stroke figure from the new catalogue (indices [_campaignStart]
  /// onward), ordered easiest to richest by edge count. No repeats —
  /// level N draws skeleton [_curatedOrder[N - 1]].
  static const int _campaignStart = 32;

  static final List<int> _curatedOrder = [
    for (var i = _campaignStart; i < _rawSkeletons.length; i++) i,
  ];

  /// Levels 1-[_curatedOrder.length] teach the classic outlines. After
  /// that the endless zone builds a fresh symmetric figure every level —
  /// no repeats, no cramped random webs.
  static _Config _configFor(int number) {
    final curatedCount = _curatedOrder.length;
    if (number <= curatedCount) {
      String label;
      if (number <= 8) {
        label = 'Easy';
      } else if (number <= 16) {
        label = 'Medium';
      } else if (number <= 24) {
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
        minSpan: 0.12,
        minGap: 0.09,
      );
    }

    final n = min(17, 6 + (number - curatedCount) ~/ 6);
    String label;
    if (n <= 9) {
      label = 'Hard';
    } else if (n <= 12) {
      label = 'Expert';
    } else {
      label = 'Master';
    }
    return _Config(
      skeletonPool: const [],
      procedural: true,
      minCoverage: 1.0,
      maxExtras: 0,
      minEdges: 6,
      difficulty: label,
      minSpan: 0.15,
      minGap: 0.11,
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
      vkeys.add(inc.join(','));
    }
    vkeys.sort();
    return '${edgeLens.join('|')}#${vkeys.join(';')}';
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

    // Best-of-N: every attempt re-rolls the rotation (and, for endless
    // levels, the whole figure), and the roomiest, best-shaped result
    // wins — so the player always gets the most traceable variant.
    OneLineLevel? best;
    double bestScore = double.negativeInfinity;
    OneLineLevel? duplicateStash;
    for (int attempt = 0; attempt < 36; attempt++) {
      final sk = cfg.procedural
          ? _symmetricFigure(number, rng)
          : _skeletons[cfg.skeletonPool.first];
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
      final score = _qualityScore(level);
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

  /// Octahedron projection: an equator square bridged to two apexes.
  static _Skeleton _octahedron() {
    return _fitSkeleton('Octahedron', const [
      Offset(0.50, 0.06),
      Offset(0.18, 0.36),
      Offset(0.82, 0.36),
      Offset(0.82, 0.76),
      Offset(0.18, 0.76),
      Offset(0.50, 0.97),
    ], const [
      _Link(1, 2), _Link(2, 3), _Link(3, 4), _Link(4, 1),
      _Link(0, 1), _Link(0, 2), _Link(0, 3), _Link(0, 4),
      _Link(5, 1), _Link(5, 2), _Link(5, 3), _Link(5, 4),
    ]);
  }

  /// Prism: two nested squares laced corner-to-corner.
  static _Skeleton _prism() {
    return _fitSkeleton('Prism', const [
      Offset(0.10, 0.10),
      Offset(0.90, 0.10),
      Offset(0.90, 0.90),
      Offset(0.10, 0.90),
      Offset(0.34, 0.34),
      Offset(0.66, 0.34),
      Offset(0.66, 0.66),
      Offset(0.34, 0.66),
    ], const [
      _Link(0, 1), _Link(1, 2), _Link(2, 3), _Link(3, 0),
      _Link(4, 5), _Link(5, 6), _Link(6, 7), _Link(7, 4),
      _Link(0, 4), _Link(0, 7), _Link(1, 5), _Link(1, 4),
      _Link(2, 6), _Link(2, 5), _Link(3, 7), _Link(3, 6),
    ]);
  }

  /// Diamond chain: four diamonds sharing middle corners.
  static _Skeleton _diamondChain() {
    return _fitSkeleton('DiamondChain', const [
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
    ], const [
      _Link(0, 5), _Link(5, 1), _Link(0, 9), _Link(9, 1),
      _Link(1, 6), _Link(6, 2), _Link(1, 10), _Link(10, 2),
      _Link(2, 7), _Link(7, 3), _Link(2, 11), _Link(11, 3),
      _Link(3, 8), _Link(8, 4), _Link(3, 12), _Link(12, 4),
    ]);
  }

  /// Petal flower: a hub with [petals] two-point petals looping to a rim.
  static _Skeleton _flowerFig(String name, int petals) {
    final outer = _ringAt(petals, 0.44, -pi / 2);
    final inner = _ringAt(petals, 0.44, -pi / 2 + pi / petals);
    final pts = <Offset>[const Offset(0.5, 0.5), ...outer, ...inner];
    final links = <_Link>[];
    for (var i = 0; i < petals; i++) {
      final a = 1 + i;
      final b = 1 + petals + i;
      links.add(_Link(0, a));
      links.add(_Link(a, b));
      links.add(_Link(b, 0));
    }
    return _fitSkeleton(name, pts, links);
  }

  /// Star mandala: an [n]-point ring threaded by the given star [steps].
  /// Overlaying cycles keeps every degree even; coprime steps keep the
  /// chords long and well spaced.
  static _Skeleton _mandalaFig(String name, int n, List<int> steps) {
    final pts = _ringAt(n, 0.42, -pi / 2);
    final links = <_Link>[];
    for (final s in steps) {
      for (var i = 0; i < n; i++) {
        links.add(_Link(i, (i + s) % n));
      }
    }
    return _fitSkeleton(name, pts, links);
  }

  /// Woven rosette: an outer ring and a half-step inner ring stitched so
  /// every node has degree four. The inner radius stays well inside the
  /// outer so the woven diagonals never run tangent to the rings.
  static _Skeleton _rosetteFig(String name, int n) {
    const rOuter = 0.44;
    const rInner = rOuter * 0.54;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        _polar(0.5, 0.5, rOuter, -pi / 2 + i * 2 * pi / n),
      for (var i = 0; i < n; i++)
        _polar(0.5, 0.5, rInner, -pi / 2 + pi / n + i * 2 * pi / n),
    ];
    final links = <_Link>[];
    for (var i = 0; i < n; i++) {
      links.add(_Link(i, (i + 1) % n));
      links.add(_Link(n + i, n + (i + 1) % n));
      links.add(_Link(i, n + i));
      links.add(_Link(n + i, (i + 1) % n));
    }
    return _fitSkeleton(name, pts, links);
  }

  // ── Thematic catalogue builders ────────────────────────────────────
  // Objects, animals, faces and premium geometry. Every figure is a
  // union of closed loops that only meet at shared vertices — so the
  // degree of every vertex is even and there are never two strokes on
  // top of each other (no overlaps). Fitting is uniform, so shapes are
  // never stretched or squashed.

  static List<_Skeleton> _thematicFigures() {
    final figures = <_Skeleton>[
      // ── Easy: recognizable single outlines ──────────────────────────
      _fig('Star', [_starLoop(5)]),
      _fig('House', [
        const [
          Offset(0.50, 0.08),
          Offset(0.92, 0.42),
          Offset(0.92, 0.90),
          Offset(0.08, 0.90),
          Offset(0.08, 0.42),
        ],
      ]),
      _fig('Heart', [_heartLoop()]),
      _fig('Cat', [_catHeadLoop()]),
      _fig('Tree', [_treeLoop()]),
      _fig('Crown', [_crownLoop()]),
      _fig('Diamond', [_diamondLoop(), _diamondInnerLoop()]),
      _fig('Fish', [_fishBodyLoop(), _fishTailLoop()]),
      _fig('Boat', [_boatHullLoop(), _boatSailLoop()]),
      _fig('Rocket', [_rocketLoop(), _rocketLeftFin(), _rocketRightFin()]),
      _fig('Leaf', [_leafLoop()]),
      _fig('Key', [_keyLoop()]),
      _fig('Bird', [_birdLoop()]),

      // ── Medium: hub/detail figures with real junctions ─────────────
      _flowerFig('Flower', 4),
      _rosetteFig('Weave', 5),
      _mandalaFig('Pinwheel', 6, const [1, 2]),
      _flowerFig('Bloom', 5),
      _octahedron(),
      _prism(),
      _mandalaFig('Starburst', 7, const [1, 2]),
      _flowerFig('Lotus', 6),
      _diamondChain(),

      // ── Hard: dense interlocking geometry ──────────────────────────
      _lattice(),
      _mandalaFig('OctoWeb', 8, const [1, 3]),
      _rosetteFig('Filigree', 6),
      _mandalaFig('Pentagram', 5, const [1, 2]),
      _rosetteFig('Rosette', 8),
      _mandalaFig('Decagram', 10, const [1, 4]),
      _rosetteFig('Webbing', 7),
      _mandalaFig('Mandala', 12, const [1, 5]),
      _mandalaFig('Enneagram', 9, const [1, 4, 5]),
    ];
    // Difficulty climbs with edge count — ship the simplest first.
    figures.sort((a, b) => a.links.length.compareTo(b.links.length));
    return figures;
  }

  /// Builds a figure from closed loops, merging coincident points into
  /// shared vertices and dropping duplicate edges, then fitting it into
  /// a centred unit box with a UNIFORM scale (aspect ratio preserved).
  static _Skeleton _fig(String name, List<List<Offset>> loops) {
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

    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in pts) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }
    const span = 0.90;
    final w = maxX - minX, h = maxY - minY;
    final scale = span / max(w <= 0 ? 1 : w, h <= 0 ? 1 : h);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final fitted = [
      for (final p in pts)
        Offset(0.5 + (p.dx - cx) * scale, 0.5 + (p.dy - cy) * scale),
    ];
    return _Skeleton(name, fitted, links, rotatable: false, eulerian: true);
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

  static List<Offset> _heartLoop({int n = 22}) {
    final raw = <Offset>[];
    for (var i = 0; i < 60; i++) {
      final t = i * 2 * pi / 60;
      final x = 16 * pow(sin(t), 3).toDouble();
      final y = 13 * cos(t) -
          5 * cos(2 * t) -
          2 * cos(3 * t) -
          cos(4 * t);
      raw.add(Offset(x, -y)); // flip y so the point sits at the bottom
    }
    return _resampleLoop(raw, n);
  }

  /// Resamples a closed polyline into [count] points spaced uniformly by
  /// arc length, so pointed parametric curves (heart, star…) never leave
  /// two vertices so close the stroke becomes untraceable.
  static List<Offset> _resampleLoop(List<Offset> loop, int count) {
    final n = loop.length;
    final cum = <double>[0];
    for (var i = 0; i < n; i++) {
      cum.add(cum[i] + (loop[(i + 1) % n] - loop[i]).distance);
    }
    final total = cum[n];
    if (total <= 0) return List<Offset>.from(loop);
    final out = <Offset>[];
    var seg = 0;
    for (var k = 0; k < count; k++) {
      final target = total * k / count;
      while (seg < n - 1 && cum[seg + 1] < target) {
        seg++;
      }
      final segLen = cum[seg + 1] - cum[seg];
      final t = segLen <= 0 ? 0.0 : (target - cum[seg]) / segLen;
      final a = loop[seg];
      final b = loop[(seg + 1) % n];
      out.add(Offset(a.dx + (b.dx - a.dx) * t, a.dy + (b.dy - a.dy) * t));
    }
    return out;
  }

  /// Cat/animal head with pointy ears, drawn as one outline.
  static List<Offset> _catHeadLoop() => const [
        Offset(0.50, 0.88), // chin
        Offset(0.24, 0.76),
        Offset(0.12, 0.54),
        Offset(0.14, 0.30),
        Offset(0.20, 0.06), // left ear tip
        Offset(0.40, 0.26),
        Offset(0.50, 0.34), // dip between the ears
        Offset(0.60, 0.26),
        Offset(0.80, 0.06), // right ear tip
        Offset(0.86, 0.30),
        Offset(0.88, 0.54),
        Offset(0.76, 0.76),
      ];

  /// Pine tree: a triangular canopy over a short trunk (one clean notch).
  static List<Offset> _treeLoop() => const [
        Offset(0.50, 0.06), // apex
        Offset(0.88, 0.62), // canopy right
        Offset(0.62, 0.62),
        Offset(0.62, 0.92), // trunk right
        Offset(0.38, 0.92), // trunk left
        Offset(0.38, 0.62),
        Offset(0.12, 0.62), // canopy left
      ];

  /// Crown outline: jewelled zig-zag top over a band.
  static List<Offset> _crownLoop() => const [
        Offset(0.10, 0.30),
        Offset(0.26, 0.62),
        Offset(0.38, 0.40),
        Offset(0.50, 0.18),
        Offset(0.62, 0.40),
        Offset(0.74, 0.62),
        Offset(0.90, 0.30),
        Offset(0.90, 0.82),
        Offset(0.10, 0.82),
      ];

  /// Big gem outline (a faceted octagon).
  static List<Offset> _diamondLoop() => const [
        Offset(0.50, 0.06),
        Offset(0.86, 0.36),
        Offset(0.72, 0.88),
        Offset(0.28, 0.88),
        Offset(0.14, 0.36),
      ];

  /// Inner gem facet sharing the top vertex so the two loops connect.
  static List<Offset> _diamondInnerLoop() => const [
        Offset(0.50, 0.06),
        Offset(0.66, 0.40),
        Offset(0.50, 0.72),
        Offset(0.34, 0.40),
      ];

  static List<Offset> _fishBodyLoop() => const [
        Offset(0.08, 0.50), // nose
        Offset(0.34, 0.24),
        Offset(0.66, 0.38),
        Offset(0.72, 0.50), // tail attach point (a real body vertex)
        Offset(0.66, 0.62),
        Offset(0.34, 0.76),
      ];

  /// Tail fin attaches at a single shared body vertex (no overlap).
  static List<Offset> _fishTailLoop() => const [
        Offset(0.72, 0.50),
        Offset(0.98, 0.30),
        Offset(0.98, 0.70),
      ];

  static List<Offset> _boatHullLoop() => const [
        Offset(0.12, 0.66),
        Offset(0.50, 0.66),
        Offset(0.82, 0.66),
        Offset(0.70, 0.88),
        Offset(0.30, 0.88),
      ];

  /// Sail triangle sharing the mast-base vertex of the hull.
  static List<Offset> _boatSailLoop() => const [
        Offset(0.50, 0.66),
        Offset(0.50, 0.10),
        Offset(0.80, 0.54),
      ];

  static List<Offset> _rocketLoop() => const [
        Offset(0.50, 0.05), // nose
        Offset(0.64, 0.30),
        Offset(0.64, 0.80),
        Offset(0.36, 0.80),
        Offset(0.36, 0.30),
      ];

  /// Tail fins share a single body-corner vertex each (no overlaps).
  static List<Offset> _rocketLeftFin() => const [
        Offset(0.36, 0.80),
        Offset(0.14, 0.94),
        Offset(0.36, 0.94),
      ];

  static List<Offset> _rocketRightFin() => const [
        Offset(0.64, 0.80),
        Offset(0.86, 0.94),
        Offset(0.64, 0.94),
      ];

  static List<Offset> _leafLoop() => const [
        Offset(0.50, 0.06),
        Offset(0.78, 0.24),
        Offset(0.88, 0.54),
        Offset(0.68, 0.84),
        Offset(0.44, 0.94),
        Offset(0.24, 0.78),
        Offset(0.16, 0.46),
        Offset(0.28, 0.20),
      ];

  static List<Offset> _keyLoop() => const [
        Offset(0.10, 0.50), // bow left
        Offset(0.14, 0.30),
        Offset(0.30, 0.20),
        Offset(0.46, 0.28),
        Offset(0.50, 0.42), // bow/shaft top junction
        Offset(0.92, 0.42), // shaft top right
        Offset(0.92, 0.58), // shaft tip
        Offset(0.74, 0.58),
        Offset(0.74, 0.72), // tooth down
        Offset(0.62, 0.72),
        Offset(0.62, 0.58),
        Offset(0.50, 0.58), // bow/shaft bottom junction
        Offset(0.44, 0.72),
        Offset(0.30, 0.82),
        Offset(0.16, 0.72),
      ];

  static List<Offset> _birdLoop() => const [
        Offset(0.10, 0.40), // beak
        Offset(0.26, 0.30),
        Offset(0.42, 0.34),
        Offset(0.52, 0.20), // crown
        Offset(0.66, 0.30),
        Offset(0.86, 0.24), // wing tip
        Offset(0.70, 0.52),
        Offset(0.82, 0.74),
        Offset(0.56, 0.66),
        Offset(0.46, 0.84), // tail
        Offset(0.28, 0.66),
      ];

  /// 3x3 lattice with two opposite cell diagonals (every degree even).
  static _Skeleton _lattice() {
    final pts = _gridPoints(3);
    const links = [
      _Link(0, 1), _Link(1, 2), _Link(3, 4), _Link(4, 5),
      _Link(6, 7), _Link(7, 8),
      _Link(0, 3), _Link(3, 6), _Link(1, 4), _Link(4, 7),
      _Link(2, 5), _Link(5, 8),
      _Link(1, 3), _Link(5, 7),
    ];
    return _fitSkeleton('Lattice', pts, links);
  }

  // ── Symmetric figure bank ──────────────────────────────────────────
  // The endless zone draws from a family of clean, already-Eulerian
  // figures — star mandalas, woven rosettes, petal flowers and spoked
  // wheels. Each is built from concentric rings so the strokes stay
  // long and evenly spaced, and the parameters vary per level so no two
  // figures ever look the same.

  _Skeleton _symmetricFigure(int number, Random rng) {
    // Rotate through the three silhouettes so consecutive levels feel
    // different, while the seeded rng keeps each one unique.
    switch ((number * 5 + 1) % 3) {
      case 0:
        return _mandala(rng);
      case 1:
        return _rosette(rng);
      default:
        return _flower(rng);
    }
  }

  /// Star mandala: n points on a ring threaded by two or three star
  /// polygons. Overlaying cycles keeps every degree even by definition.
  _Skeleton _mandala(Random rng) {
    final n = 7 + rng.nextInt(6); // 7..12
    final phase = rng.nextDouble() * 2 * pi;
    final pts = _ringAt(n, 0.42, phase);
    final maxStep = (n - 1) ~/ 2; // never n/2 (would duplicate edges)
    final steps = <int>{1};
    steps.add(2 + rng.nextInt(max(1, maxStep - 1)));
    if (n >= 9 && rng.nextBool()) {
      steps.add(2 + rng.nextInt(max(1, maxStep - 1)));
    }
    final links = <_Link>[];
    for (final s in steps) {
      for (var i = 0; i < n; i++) {
        links.add(_Link(i, (i + s) % n));
      }
    }
    return _fitSkeleton('Mandala', pts, links);
  }

  /// Woven rosette: an outer ring and a half-step inner ring stitched
  /// together so every node has degree four.
  _Skeleton _rosette(Random rng) {
    final n = 5 + rng.nextInt(4); // 5..8
    const rOuter = 0.44;
    final rInner = rOuter * (0.50 + rng.nextDouble() * 0.08);
    final phase = rng.nextDouble() * 2 * pi;
    final pts = <Offset>[
      for (var i = 0; i < n; i++)
        _polar(0.5, 0.5, rOuter, phase + i * 2 * pi / n),
      for (var i = 0; i < n; i++)
        _polar(0.5, 0.5, rInner, phase + pi / n + i * 2 * pi / n),
    ];
    final links = <_Link>[];
    for (var i = 0; i < n; i++) {
      links.add(_Link(i, (i + 1) % n)); // outer ring
      links.add(_Link(n + i, n + (i + 1) % n)); // inner ring
      links.add(_Link(i, n + i)); // spoke
      links.add(_Link(n + i, (i + 1) % n)); // woven diagonal
    }
    return _fitSkeleton('Rosette', pts, links);
  }

  /// Petal flower: a hub with n two-point petals looping out to a rim.
  _Skeleton _flower(Random rng) {
    final petals = 4 + rng.nextInt(5); // 4..8
    final phase = rng.nextDouble() * 2 * pi;
    final outer = _ringAt(petals, 0.44, phase);
    final inner = _ringAt(petals, 0.44, phase + pi / petals);
    final pts = <Offset>[const Offset(0.5, 0.5), ...outer, ...inner];
    final links = <_Link>[];
    for (var i = 0; i < petals; i++) {
      final a = 1 + i;
      final b = 1 + petals + i;
      links.add(_Link(0, a));
      links.add(_Link(a, b));
      links.add(_Link(b, 0));
    }
    return _fitSkeleton('Flower', pts, links);
  }

  static Offset _polar(double cx, double cy, double r, double a) =>
      Offset(cx + r * cos(a), cy + r * sin(a));

  static List<Offset> _ringAt(int n, double radius, double phase) => [
        for (var i = 0; i < n; i++)
          _polar(0.5, 0.5, radius, phase + i * 2 * pi / n),
      ];

  /// Centres [pts] and scales them to a consistent span, then
  /// de-duplicates [links]. Marked eulerian so the caller ships the
  /// whole symmetric figure untouched.
  static _Skeleton _fitSkeleton(
      String name, List<Offset> pts, List<_Link> links) {
    final seen = <String>{};
    final dedup = <_Link>[];
    for (final l in links) {
      if (l.a == l.b) continue;
      if (l.a < 0 || l.b < 0 || l.a >= pts.length || l.b >= pts.length) {
        continue;
      }
      final key = l.a <= l.b ? '${l.a}-${l.b}' : '${l.b}-${l.a}';
      if (seen.add(key)) dedup.add(l.a <= l.b ? l : _Link(l.b, l.a));
    }
    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in pts) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }
    const span = 0.90;
    final w = maxX - minX, h = maxY - minY;
    final scale = span / max(w <= 0 ? 1 : w, h <= 0 ? 1 : h);
    final cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
    final fitted = [
      for (final p in pts)
        Offset(0.5 + (p.dx - cx) * scale, 0.5 + (p.dy - cy) * scale),
    ];
    return _Skeleton(name, fitted, dedup, rotatable: true, eulerian: true);
  }

  // ── Figure construction ───────────────────────────────────────────

  OneLineLevel? _tryBuild(
    _Skeleton sk,
    _Config cfg,
    Random rng,
    int number,
    bool mirror,
  ) {
    final used = Set<int>.identity();
    if (sk.eulerian) {
      // Already an Eulerian circuit by construction — ship every link so
      // the symmetric figure stays intact (no walk or parity repair).
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
    final angle = sk.rotatable
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

    // Eulerian-circuit invariants: connectivity + zero odd vertices.
    if (!_isConnected(vertices.length, edges)) return null;
    if (_oddDegreeVertices(vertices.length, edges).isNotEmpty) return null;

    // Playability: reject cramped layouts (lines too close, strokes
    // too short, shallow-angle overlaps) before shipping the level.
    if (!_isDrawable(vertices, edges, minSpan: cfg.minSpan, gap: cfg.minGap)) {
      return null;
    }

    // Tutorial levels (1-10) let the stroke begin anywhere on the
    // outline. From level 11 the start is locked to one glowing vertex,
    // so a careless turn at a junction can strand the stroke and the
    // player has to plan ahead.
    final startAnywhere = number <= 10;
    final startVertex =
        startAnywhere ? 0 : _chooseStartVertex(vertices, edges, sk.startHint);

    final solution = hierholzer(
        vertices.length, edges, startAnywhere ? null : startVertex);
    if (solution == null || solution.length != edges.length + 1) return null;

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
    );
  }

  /// Locked-level start: the busiest junction (highest degree), breaking
  /// ties toward the bottom-most then left-most vertex so the mandated
  /// start is stable and visually obvious. Honours a figure's startHint
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
          if (acute * 180 / pi < minCrossingAngleDeg) return false;
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
