import 'silhouette_models.dart';
import 'puzzle_generator.dart';

class SilhouetteLevel {
  final int id;
  final String name;
  final String themeEmoji;
  final String description;
  final int gridCols;
  final int gridRows;
  final List<List<bool>> mask;
  final List<ArrowPiece> Function() arrowFactory;
  final int maxMoves;

  const SilhouetteLevel({
    required this.id,
    required this.name,
    required this.themeEmoji,
    required this.description,
    required this.gridCols,
    required this.gridRows,
    required this.mask,
    required this.arrowFactory,
    required this.maxMoves,
  });

  List<ArrowPiece> generateArrows() => arrowFactory();
}

List<List<bool>> _parseMask(String compact) {
  final lines = compact.split('\n').where((l) => l.trim().isNotEmpty);
  final rows = <List<bool>>[];
  for (final line in lines) {
    rows.add(line.trim().split('').map((c) => c == '1').toList());
  }
  return rows;
}

List<ArrowPiece> _generateLevelArrows(SilhouetteLevel level,
    {LevelConfig config = LevelConfig.medium}) {
  final generator = PuzzleGenerator(
    rows: level.gridRows,
    cols: level.gridCols,
    mask: level.mask,
    config: config,
    seed: level.id,
  );
  return generator.generate().arrows;
}

final heartMaskCompact = '''
0000111111110000
0001111111111000
0011111111111100
0111111111111110
0111111111111110
1111111111111111
1111111111111111
1111111111111111
1111111111111111
0111111111111110
0111111111111110
0011111111111100
0001111111111000
0000111111110000
0000011111100000
0000001111000000
0000000110000000
''';

final starMaskCompact = '''
0000001100000000
0000011110000000
0000111111000000
0001111111100000
1111111111111110
0111111111111100
0011111111111000
0001111111110000
0011110001111000
0111100000111100
1111000000011110
1110000000001110
1000000000000010
''';

final birdMaskCompact = '''
0000000111000000
0000001111100000
0000011111110000
0000111111111000
0001111111111100
0011111111111110
0111111111111100
1111111111111000
0111111111110000
0011111111100000
0001111111000000
0000111110000000
0000011100000000
''';

final diamondMaskCompact = '''
0000000110000000
0000001111000000
0000011111100000
0000111111110000
0001111111111000
0011111111111100
0111111111111110
1111111111111111
0111111111111110
0011111111111100
0001111111111000
0000111111110000
0000011111100000
0000001111000000
0000000110000000
''';

final treeMaskCompact = '''
0000000110000000
0000001111000000
0000011111100000
0000111111110000
0001111111111000
0011111111111100
0111111111111110
1111111111111111
0000001111000000
0000001111000000
0000001111000000
0000001111000000
0000001111000000
0000001111000000
''';

final moonMaskCompact = '''
0000001111000000
0000111111110000
0001111111111000
0011111101111100
0111111000111110
0111110000011110
1111100000001111
1111100000001111
0111110000011110
0111111000111110
0011111101111100
0001111111111000
0000111111110000
0000001111000000
''';

final flowerMaskCompact = '''
0000001111000000
0000111111110000
0001111001111000
0111100000011110
0111000000001110
1110000000000111
1110000000000111
0111000000001110
0111100000011110
0001111001111000
0000111111110000
0000001111000000
0000001111000000
0000001111000000
0000001111000000
''';

final shieldMaskCompact = '''
0000111111110000
0001111111111000
0011111111111100
0111111111111110
0111111111111110
1111111111111111
1111111111111111
0111111111111110
0011111111111100
0001111111111000
0000111111110000
0000011111100000
0000001111000000
''';

final List<SilhouetteLevel> silhouetteLevels = [
  SilhouetteLevel(
    id: 1,
    name: 'Heart',
    themeEmoji: '\u2764\uFE0F',
    description: 'Fill the heart with arrows',
    gridCols: 16,
    gridRows: 17,
    mask: _parseMask(heartMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[0],
      config: LevelConfig.easy,
    ),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 2,
    name: 'Star',
    themeEmoji: '\u2B50',
    description: 'Fill the star with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(starMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[1],
      config: LevelConfig.easy,
    ),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 3,
    name: 'Bird',
    themeEmoji: '\uD83D\uDC26',
    description: 'Fill the bird with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(birdMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[2],
      config: LevelConfig.medium,
    ),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 4,
    name: 'Diamond',
    themeEmoji: '\uD83D\uDC8E',
    description: 'Fill the diamond with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(diamondMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[3],
      config: LevelConfig.medium,
    ),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 5,
    name: 'Tree',
    themeEmoji: '\uD83C\uDF33',
    description: 'Fill the tree with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(treeMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[4],
      config: LevelConfig.medium,
    ),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 6,
    name: 'Moon',
    themeEmoji: '\uD83C\uDF19',
    description: 'Fill the crescent moon with arrows',
    gridCols: 16,
    gridRows: 14,
    mask: _parseMask(moonMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[5],
      config: LevelConfig.hard,
    ),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 7,
    name: 'Flower',
    themeEmoji: '\uD83C\uDF3C',
    description: 'Fill the flower with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(flowerMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[6],
      config: LevelConfig.hard,
    ),
    maxMoves: 35,
  ),
  SilhouetteLevel(
    id: 8,
    name: 'Shield',
    themeEmoji: '\uD83D\uDEE1\uFE0F',
    description: 'Fill the shield with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(shieldMaskCompact),
    arrowFactory: () => _generateLevelArrows(
      silhouetteLevels[7],
      config: LevelConfig.extreme,
    ),
    maxMoves: 35,
  ),
];