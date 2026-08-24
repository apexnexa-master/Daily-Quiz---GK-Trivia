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

/// Sign-aware Delaunay circumcircle test: is point [d] strictly inside
/// the circle through triangle (a, b, c)?
bool _inCircumcircle(Offset a, Offset b, Offset c, Offset d) {
  final ax = a.dx - d.dx, ay = a.dy - d.dy;
  final bx = b.dx - d.dx, by = b.dy - d.dy;
  final cx = c.dx - d.dx, cy = c.dy - d.dy;
  final az = ax * ax + ay * ay;
  final bz = bx * bx + by * by;
  final cz = cx * cx + cy * cy;
  final det = ax * (by * cz - bz * cy) -
      ay * (bx * cz - bz * cx) +
      az * (bx * cy - by * cx);
  final orient = (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
  return orient > 0 ? det > 1e-12 : det < -1e-12;
}

class _Skeleton {
  final String name;
  final List<Offset> points;
  final List<_Link> links;

  /// Symmetric figures get a per-level rotation so repeated topology
  /// still looks fresh.
  final bool rotatable;
  const _Skeleton(this.name, this.points, this.links, {this.rotatable = false});
}

class _Config {
  final List<int> skeletonPool;
  final double minCoverage; // fraction of skeleton links used by the walk
  final int maxExtras; // parity chords added after the walk
  final int minEdges;
  final String difficulty;

  /// Web levels ignore [skeletonPool] and build a fresh random
  /// constellation (Delaunay web) every attempt instead. Remix levels
  /// replay a hand-crafted skeleton with a fresh rotation/mirror and a
  /// fuller link walk.
  final bool procedural;
  final bool remix;

  /// Drawability thresholds -- dense webs relax these a little;
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
    this.remix = false,
    this.minSpan = OneLineGenerator.minEdgeSpan,
    this.minGap = OneLineGenerator.minSegmentGap,
  });
}

class OneLineGenerator {
  static const double _margin = 0.12;

  /// Drawability guarantees (normalized board units, board side = 1):
  /// every stroke must be long enough to drag and far enough from its
  /// neighbours that the pen can follow it without snapping onto the
  /// wrong line.
  static const double minEdgeSpan = 0.15;
  static const double minSegmentGap = 0.08;
  static const double minCrossingAngleDeg = 32;

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
    // 30 ── Enneagram: a ring laced with three interlocked triangles
    // (every chord skips two points — the classic {9/3} figure).
    _Skeleton(
        'Enneagram',
        _ringPoints(9, radius: 0.42),
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
          _Link(0, 3),
          _Link(3, 6),
          _Link(6, 0),
          _Link(1, 4),
          _Link(4, 7),
          _Link(7, 1),
          _Link(2, 5),
          _Link(5, 8),
          _Link(8, 2),
        ],
        rotatable: true),
    // 31 ── Decagram: decagon threaded by one ten-point star polygon
    // ({10/3}) — every chord spans three points.
    _Skeleton(
        'Decagram',
        _ringPoints(10, radius: 0.42),
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
          _Link(0, 3),
          _Link(3, 6),
          _Link(6, 9),
          _Link(9, 2),
          _Link(2, 5),
          _Link(5, 8),
          _Link(8, 1),
          _Link(1, 4),
          _Link(4, 7),
          _Link(7, 0),
        ],
        rotatable: true),
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
    final span = 0.80 + t * 0.15; // 0.80 .. 0.95
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
        rotatable: s.rotatable);
  }

  /// Campaign: every one of these levels is a DIFFERENT hand-crafted
  /// classic one-stroke figure, ordered easy to rich. No repeats —
  /// level N draws skeleton [_curatedOrder[N - 1]].
  static const List<int> _curatedOrder = [
    0, // 1 Triangle
    20, // 2 Hourglass
    1, // 3 Square
    21, // 4 Triforce
    2, // 5 Pentagon
    3, // 6 House
    9, // 7 Arrow
    8, // 8 Crown
    7, // 9 Fish
    4, // 10 Bowtie
    5, // 11 Envelope
    17, // 12 Ladder
    11, // 13 Hexagon
    15, // 14 Gem
    12, // 15 Wheel
    14, // 16 Octagram
    22, // 17 Star of David
    18, // 18 Pentagram K5
    23, // 19 Diamond chain
    24, // 20 Cube X
    25, // 21 OctoWeb
    16, // 22 Snowflake
    13, // 23 Lattice
    19, // 24 Octahedron
    6, // 25 Star web
    26, // 26 Star outline
    27, // 27 Bolt
    28, // 28 Rocket
    29, // 29 Prism
    30, // 30 Enneagram
    31, // 31 Decagram
  ];

  /// Levels 1-[_curatedOrder.length] teach the classic outlines. After
  /// that the endless zone ALTERNATES fresh Delaunay constellations
  /// with remixed rotations of every hand-crafted figure, so both
  /// families keep appearing forever while density keeps growing.
  static _Config _configFor(int number) {
    final curatedCount = _curatedOrder.length;
    if (number <= curatedCount) {
      String label;
      if (number <= 6) {
        label = 'Easy';
      } else if (number <= 12) {
        label = 'Medium';
      } else if (number <= 19) {
        label = 'Hard';
      } else {
        label = 'Expert';
      }
      return _Config(
        skeletonPool: [_curatedOrder[number - 1]],
        minCoverage: number <= 3 ? 0.72 : 0.85,
        maxExtras: 2,
        minEdges: 3,
        difficulty: label,
      );
    }

    final n = min(17, 6 + (number - curatedCount) ~/ 6);
    final remix = (number - curatedCount).isOdd;
    String label;
    if (n <= 9) {
      label = remix ? 'Expert' : 'Hard';
    } else if (n <= 12) {
      label = 'Expert';
    } else {
      label = 'Master';
    }
    return _Config(
      skeletonPool: const [],
      procedural: !remix,
      remix: remix,
      // Small skeletons (Square, Triangle...) cannot feed an 8-edge
      // minimum once the walk stalls; 6 keeps them viable while large
      // figures naturally ship far more.
      minCoverage: remix ? 0.80 : 0.72,
      maxExtras: 3,
      minEdges: remix ? 6 : max(7, n * 5 ~/ 4),
      difficulty: label,
      minSpan: remix ? 0.10 : 0.09,
      minGap: remix ? 0.055 : 0.05,
    );
  }

  /// Remix levels rotate through the richer half of the catalogue:
  /// tiny outlines (Triangle, Square...) can never feed the
  /// endless-zone density floor, so picking them would only force a
  /// sparse fallback polygon.
  static final List<int> _remixPool = [
    for (int i = 0; i < _skeletons.length; i++)
      if (_skeletons[i].links.length >= 8) i,
  ];

  /// Deterministic remix pick, keyed on the offset INTO the endless
  /// zone so extending the campaign never reshuffles existing levels.
  _Skeleton _remixPick(int number) {
    final offset = number - _curatedOrder.length;
    return _skeletons[_remixPool[(offset * 31 + 7) % _remixPool.length]];
  }

  /// Memoised levels. Doubles as the layout-history used to keep any
  /// two levels from shipping the same figure.
  final Map<int, OneLineLevel> _memo = {};  /// Canonical geometry signature of a built level: sorted vertex
  /// positions plus canonical edge pairs, so id remapping, mirroring
  /// and walk order cannot hide a true duplicate.
  String _layoutKey(OneLineLevel lv) {
    final pos = <int, String>{};
    for (final v in lv.vertices) {
      pos[v.id] =
          '${v.position.dx.toStringAsFixed(3)},${v.position.dy.toStringAsFixed(3)}';
    }
    final verts = pos.values.toList()..sort();
    final edges = <String>[];
    for (final e in lv.edges) {
      final a = pos[e.a]!;
      final b = pos[e.b]!;
      edges.add(a.compareTo(b) <= 0 ? '$a~$b' : '$b~$a');
    }
    edges.sort();
    return '${verts.join(';')}#${edges.join(';')}';
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

    OneLineLevel? duplicateStash;
    for (int attempt = 0; attempt < 240; attempt++) {
      // Curated levels own one hand-crafted skeleton each; remix
      // levels rotate a deterministic pick from the full catalogue;
      // web levels roll a brand-new constellation per attempt.
      final _Skeleton sk;
      if (cfg.procedural) {
        sk = _proceduralWeb(number, rng);
      } else if (cfg.remix) {
        sk = _remixPick(number);
      } else {
        sk = _skeletons[cfg.skeletonPool.first];
      }
      final mirror = attempt.isOdd || rng.nextBool();
      final level = _tryBuild(sk, cfg, rng, number, mirror);
      if (level == null) continue;

      var clash = false;
      final key = _layoutKey(level);
      for (final existing in _memo.values) {
        if (_layoutKey(existing) == key) {
          clash = true;
          break;
        }
      }
      if (clash) {
        // Prefer re-rolling over a fallback polygon; if every attempt
        // collides (exhausted variety), ship the least-bad duplicate.
        duplicateStash ??= level;
        continue;
      }
      _memo[number] = level;
      return level;
    }
    final chosen = duplicateStash ?? _fallbackCycle(number);
    _memo[number] = chosen;
    return chosen;
  }

  // ── Construction pipeline ─────────────────────────────────────────

  // ── Procedural constellations ──────────────────────────────────────
  // Inspired by how modern one-line games scale content: hand-crafted
  // classics for the opening campaign, then freshly generated planar
  // webs whose topology is unique per level.

  /// Brand-new random figure for procedural levels: well-spaced points
  /// joined by a Delaunay web (planar — strokes never cross), thinned
  /// for airiness and kept connected. The regular walk/repair pipeline
  /// then carves the Eulerian circuit out of it.
  _Skeleton _proceduralWeb(int number, Random rng) {
    final curated = _curatedOrder.length;
    final n = min(17, 8 + max(0, number - curated) ~/ 6);
    final style = (number * 7 + 3) % 3;
    final pts = _scatterPoints(n, style, rng);
    final links = _delaunayLinks(pts);
    if (links.length < 4) return _proceduralWeb(number + 7919, rng);

    // Thin a light random slice of edges so webs feel airy and leave
    // repair room; connectivity is restored from the full set.
    final thinned = <_Link>[
      for (final l in links)
        if (rng.nextDouble() >= 0.10) l,
    ];
    final alive = _connectComponents(pts, links, thinned);
    return _Skeleton('Web', pts, alive, rotatable: true);
  }

  /// Well-spaced points using one of three layout families (jittered
  /// grid, concentric rings, best-candidate scatter) so consecutive
  /// webs do not all feel alike.
  List<Offset> _scatterPoints(int n, int style, Random rng) {
    const m = 0.055;
    switch (style % 3) {
      case 0:
        final cols = sqrt(n.toDouble()).ceil();
        final rows = (n / cols).ceil();
        final cw = (1 - 2 * m) / cols;
        final ch = (1 - 2 * m) / rows;
        return [
          for (var r = 0; r < rows; r++)
            for (var c = 0; c < cols; c++)
              if (r * cols + c < n)
                Offset(
                  m + (c + 0.5) * cw + (rng.nextDouble() - 0.5) * cw * 0.5,
                  m + (r + 0.5) * ch + (rng.nextDouble() - 0.5) * ch * 0.5,
                ),
        ];
      case 1:
        final pts = <Offset>[const Offset(0.5, 0.5)];
        var ring = 1;
        while (pts.length < n && ring < 6) {
          final count = min(n - pts.length, ring * 5);
          final radius = 0.20 * ring + rng.nextDouble() * 0.06;
          final phase = rng.nextDouble() * 2 * pi;
          for (var k = 0; k < count; k++) {
            final ang = phase + k * 2 * pi / count;
            pts.add(Offset(
              0.5 + radius * cos(ang),
              0.5 + radius * sin(ang),
            ));
          }
          ring++;
        }
        return pts;
      default:
        final pts = <Offset>[];
        for (var i = 0; i < n; i++) {
          Offset best = const Offset(m, m);
          var bestD = -1.0;
          for (var t = 0; t < 24; t++) {
            final cand = Offset(
              m + rng.nextDouble() * (1 - 2 * m),
              m + rng.nextDouble() * (1 - 2 * m),
            );
            var dmin = double.infinity;
            for (final p in pts) {
              dmin = min(dmin, (cand - p).distanceSquared);
            }
            if (dmin > bestD) {
              bestD = dmin;
              best = cand;
            }
          }
          pts.add(best);
        }
        return pts;
    }
  }

  /// Bowyer–Watson Delaunay triangulation over [pts]; returns the
  /// unique edges of the triangulation — a planar connected graph.
  List<_Link> _delaunayLinks(List<Offset> pts) {
    final n = pts.length;
    if (n < 3) return [for (var i = 1; i < n; i++) _Link(0, i)];

    var minX = double.infinity, minY = double.infinity;
    var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
    for (final p in pts) {
      minX = min(minX, p.dx);
      minY = min(minY, p.dy);
      maxX = max(maxX, p.dx);
      maxY = max(maxY, p.dy);
    }
    final dmax = max(maxX - minX, maxY - minY) * 10 + 10;
    final midX = (minX + maxX) / 2, midY = (minY + maxY) / 2;
    Offset vertex(int i) => i < n
        ? pts[i]
        : switch (i - n) {
            0 => Offset(midX - dmax, midY - dmax),
            1 => Offset(midX + dmax, midY - dmax),
            _ => Offset(midX, midY + dmax),
          };

    var tris = <List<int>>[
      [n, n + 1, n + 2],
    ];
    for (var i = 0; i < n; i++) {
      final p = pts[i];
      final bad = <List<int>>[];
      final keep = <List<int>>[];
      for (final t in tris) {
        (_inCircumcircle(vertex(t[0]), vertex(t[1]), vertex(t[2]), p)
                ? bad
                : keep)
            .add(t);
      }
      // Boundary of the hole: edges that appear in exactly one bad tri.
      final counts = <String, int>{};
      final ends = <String, List<int>>{};
      for (final t in bad) {
        for (var e = 0; e < 3; e++) {
          final a = t[e], b = t[(e + 1) % 3];
          final key = a < b ? '$a-$b' : '$b-$a';
          counts[key] = (counts[key] ?? 0) + 1;
          ends[key] = [a, b];
        }
      }
      for (final entry in counts.entries) {
        if (entry.value == 1) keep.add([...ends[entry.key]!, i]);
      }
      tris = keep;
    }

    final seen = <String>{};
    final links = <_Link>[];
    for (final t in tris) {
      for (var e = 0; e < 3; e++) {
        final a = t[e], b = t[(e + 1) % 3];
        if (a >= n || b >= n) continue;
        final key = a < b ? '$a-$b' : '$b-$a';
        if (seen.add(key)) links.add(_Link(a, b));
      }
    }
    return links;
  }

  /// Re-adds the shortest missing candidate edges until the graph is a
  /// single connected component.
  List<_Link> _connectComponents(
    List<Offset> pts,
    List<_Link> candidates,
    List<_Link> alive,
  ) {
    final parent = List<int>.generate(pts.length, (i) => i);
    int find(int x) => parent[x] == x ? x : parent[x] = find(parent[x]);
    void union(int a, int b) => parent[find(a)] = find(b);
    for (final l in alive) {
      union(l.a, l.b);
    }

    final out = List<_Link>.of(alive);
    while (true) {
      _Link? shortest;
      var bestDist = double.infinity;
      for (final l in candidates) {
        if (find(l.a) == find(l.b)) continue;
        final d = (pts[l.a] - pts[l.b]).distanceSquared;
        if (d < bestDist) {
          bestDist = d;
          shortest = l;
        }
      }
      if (shortest == null) break;
      out.add(shortest);
      union(shortest.a, shortest.b);
    }
    return out;
  }

  // ── Figure construction ───────────────────────────────────────────

  OneLineLevel? _tryBuild(
    _Skeleton sk,
    _Config cfg,
    Random rng,
    int number,
    bool mirror,
  ) {
    final used = _trailWalk(sk, cfg.minCoverage, rng);
    if (used.isEmpty) return null;

    _enrichWithParitySafeLinks(sk, used, cfg.maxExtras, rng);
    // The whole point of this game variant: start anywhere on the
    // outline. That demands an Eulerian circuit - every degree even.
    if (!_repairToAllEven(sk, used)) return null;

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

    final solution = hierholzer(vertices.length, edges, null);
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
    );
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
