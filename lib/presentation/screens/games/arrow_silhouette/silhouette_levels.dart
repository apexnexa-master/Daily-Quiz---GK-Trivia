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
  final LevelConfig config;

  const SilhouetteLevel({
    required this.id,
    required this.name,
    required this.themeEmoji,
    required this.description,
    required this.gridCols,
    required this.gridRows,
    required this.mask,
    required this.arrowFactory,
    required this.config,
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

List<ArrowPiece> _generateLevelArrows(SilhouetteLevel level) {
  final generator = PuzzleGenerator(
    rows: level.gridRows,
    cols: level.gridCols,
    mask: level.mask,
    config: level.config,
    seed: level.id,
  );
  return generator.generate().arrows;
}

const heartMaskCompact = '''
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

const starMaskCompact = '''
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

const birdMaskCompact = '''
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

const diamondMaskCompact = '''
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

const treeMaskCompact = '''
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

const moonMaskCompact = '''
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

const flowerMaskCompact = '''
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

const shieldMaskCompact = '''
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

const fishMaskCompact = '''
0000000011000000
0000001111110000
0000011111111000
0000111111111100
0011111111111110
0011111111111111
0111111111111111
0011111111111111
0011111111111110
0001111111111100
0000111111111000
0000011111110000
0000001111100000
0000111111000000
0001111110000000
''';

const butterflyMaskCompact = '''
0000000110000000
0011110110111100
0111111111111110
1111111111111111
0111111111111110
0001110110111000
0000001111000000
0000001111000000
0111111111111110
0111111111111110
0011111111111100
0001111111111000
0000111111110000
0000011111100000
0000001111000000
''';

const sunMaskCompact = '''
0000001110000000
0000001110000000
0000001110000000
0001111111110000
0001111111110000
0111111111111110
0111111111111110
1111111111111111
1111111111111111
0111111111111110
0111111111111110
0001111111110000
0001111111110000
0000001110000000
0000001110000000
0000001110000000
''';

const lightningMaskCompact = '''
0000000010000000
0000001110000000
0000111110000000
0011111100000000
0111110000000000
1111000000000000
1110000000000000
0111111000000000
0001111111100000
0000111111111100
0000011111111000
0000001111100000
0000000111000000
0000000011000000
0000000110000000
''';

const mushroomMaskCompact = '''
0000111111110000
0011111111111100
0111111111111110
1111111111111111
1111111111111111
0111111111111110
0011111111111100
0001111111111000
0000001111000000
0000001111000000
0000001111000000
0000011111100000
0000011111100000
0000111111110000
0000111111110000
''';

const cloudMaskCompact = '''
0000000111110000
0000001111111000
0000011111111100
0011111111111110
0111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
0111111111111110
0001111111111000
''';

const crownMaskCompact = '''
0001000100010000
0001000100010000
0001110111011100
0001110111011100
0001111111111100
0011111111111110
0111111111111111
1111111111111111
1111111111111111
1111111111111111
0011111111111100
''';

const rocketMaskCompact = '''
0000000110000000
0000011111000000
0000111111110000
0001111111111000
0011111111111100
0111111111111110
1111111111111111
0111111111111110
0001111111111000
0000111111110000
0000111111110000
0000111111110000
0110111111110110
1111111111111111
0001111111111000
0000111000111000
0000011000011000
''';

const ghostMaskCompact = '''
0000001111000000
0000111111110000
0011111111111100
0111111111111110
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1101101101101100
1011011011011010
1101101101101100
0011111111111100
''';

const snowmanMaskCompact = '''
0000001111000000
0000111111110000
0001111111111000
0011111111111100
0011111111111100
0001111111111000
0001111111111000
0001111111111000
0000111111110000
0000001111000000
0011111111111100
0111111111111110
0111111111111110
0111111111111110
0111111111111110
0011111111111100
0001111111111000
''';

const batteryMaskCompact = '''
0000000011000000
0000000011000000
0000001111110000
0000111111110000
0111111111111110
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
1111111111111111
0111111111111110
0011111111111100
0001111111111000
''';

const keyMaskCompact = '''
0000001111110000
0000111111111000
0001111111111100
0011111000111110
0111110000011110
0111100000001110
0111100000001110
0111100000001110
0111110000011110
0011111000111110
0001111111111100
0000111111111000
0000001111110000
0000000111110000
0000000111110000
0000000111110000
0000000111000000
0000000111000000
''';

const catMaskCompact = '''
0000011000110000
0000111101111000
0001111111111100
0001111111111100
0111111111111110
0111111111111110
0001111111111000
0000011111100000
0001111111111000
0111111111111110
0111111111111110
0111111111111110
0111111111111110
0011111111111100
0001111111111000
''';

const pawMaskCompact = '''
0011011011011000
0011011011011000
0001101101100000
0000000000000000
0000001111000000
0000111111110000
0011111111111100
0111111111111110
1111111111111111
1111111111111111
0111111111111110
0001111111111000
''';

const bellMaskCompact = '''
0000000110000000
0000001111000000
0000011111100000
0001111111111000
0011111111111100
0111111111111110
1111111111111111
0111111111111110
0011111111111100
0001111111111000
0000011111100000
0000001111000000
0000000000000000
0000001001000000
0000011000110000
''';

const carMaskCompact = '''
0000001111110000
0000011111111000
0000111111111100
0001111111111110
0111111111111110
1111111111111111
1111111111111111
1111111111111111
1111111111111111
0111111111111110
0011111111111100
0000011111110000
0000111001110000
0001110000111000
0001100000001100
0001100000001100
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
    config: LevelConfig.easy,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[0]),
  ),
  SilhouetteLevel(
    id: 2,
    name: 'Star',
    themeEmoji: '\u2B50',
    description: 'Fill the star with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(starMaskCompact),
    config: LevelConfig.easy,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[1]),
  ),
  SilhouetteLevel(
    id: 3,
    name: 'Bird',
    themeEmoji: '\uD83D\uDC26',
    description: 'Fill the bird with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(birdMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[2]),
  ),
  SilhouetteLevel(
    id: 4,
    name: 'Diamond',
    themeEmoji: '\uD83D\uDC8E',
    description: 'Fill the diamond with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(diamondMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[3]),
  ),
  SilhouetteLevel(
    id: 5,
    name: 'Tree',
    themeEmoji: '\uD83C\uDF33',
    description: 'Fill the tree with arrows',
    gridCols: 16,
    gridRows: 14,
    mask: _parseMask(treeMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[4]),
  ),
  SilhouetteLevel(
    id: 6,
    name: 'Moon',
    themeEmoji: '\uD83C\uDF19',
    description: 'Fill the crescent moon with arrows',
    gridCols: 16,
    gridRows: 14,
    mask: _parseMask(moonMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[5]),
  ),
  SilhouetteLevel(
    id: 7,
    name: 'Flower',
    themeEmoji: '\uD83C\uDF3C',
    description: 'Fill the flower with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(flowerMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[6]),
  ),
  SilhouetteLevel(
    id: 8,
    name: 'Shield',
    themeEmoji: '\uD83D\uDEE1\uFE0F',
    description: 'Fill the shield with arrows',
    gridCols: 16,
    gridRows: 13,
    mask: _parseMask(shieldMaskCompact),
    config: LevelConfig.extreme,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[7]),
  ),
  SilhouetteLevel(
    id: 9,
    name: 'Fish',
    themeEmoji: '\uD83D\uDC1F',
    description: 'Fill the fish with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(fishMaskCompact),
    config: LevelConfig.easy,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[8]),
  ),
  SilhouetteLevel(
    id: 10,
    name: 'Butterfly',
    themeEmoji: '\uD83E\uDD8B',
    description: 'Fill the butterfly with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(butterflyMaskCompact),
    config: LevelConfig.easy,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[9]),
  ),
  SilhouetteLevel(
    id: 11,
    name: 'Sun',
    themeEmoji: '\u2600\uFE0F',
    description: 'Fill the sun with arrows',
    gridCols: 16,
    gridRows: 16,
    mask: _parseMask(sunMaskCompact),
    config: LevelConfig.easy,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[10]),
  ),
  SilhouetteLevel(
    id: 12,
    name: 'Lightning',
    themeEmoji: '\u26A1',
    description: 'Fill the lightning bolt with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(lightningMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[11]),
  ),
  SilhouetteLevel(
    id: 13,
    name: 'Mushroom',
    themeEmoji: '\uD83C\uDF44',
    description: 'Fill the mushroom with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(mushroomMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[12]),
  ),
  SilhouetteLevel(
    id: 14,
    name: 'Cloud',
    themeEmoji: '\u2601\uFE0F',
    description: 'Fill the cloud with arrows',
    gridCols: 16,
    gridRows: 11,
    mask: _parseMask(cloudMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[13]),
  ),
  SilhouetteLevel(
    id: 15,
    name: 'Crown',
    themeEmoji: '\uD83D\uDC51',
    description: 'Fill the crown with arrows',
    gridCols: 16,
    gridRows: 11,
    mask: _parseMask(crownMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[14]),
  ),
  SilhouetteLevel(
    id: 16,
    name: 'Rocket',
    themeEmoji: '\uD83D\uDE80',
    description: 'Fill the rocket with arrows',
    gridCols: 16,
    gridRows: 17,
    mask: _parseMask(rocketMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[15]),
  ),
  SilhouetteLevel(
    id: 17,
    name: 'Ghost',
    themeEmoji: '\uD83D\uDC7B',
    description: 'Fill the ghost with arrows',
    gridCols: 16,
    gridRows: 17,
    mask: _parseMask(ghostMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[16]),
  ),
  SilhouetteLevel(
    id: 18,
    name: 'Snowman',
    themeEmoji: '\u26C4',
    description: 'Fill the snowman with arrows',
    gridCols: 16,
    gridRows: 17,
    mask: _parseMask(snowmanMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[17]),
  ),
  SilhouetteLevel(
    id: 19,
    name: 'Battery',
    themeEmoji: '\uD83D\uDD0B',
    description: 'Fill the battery with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(batteryMaskCompact),
    config: LevelConfig.medium,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[18]),
  ),
  SilhouetteLevel(
    id: 20,
    name: 'Key',
    themeEmoji: '\uD83D\uDDDD\uFE0F',
    description: 'Fill the key with arrows',
    gridCols: 16,
    gridRows: 18,
    mask: _parseMask(keyMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[19]),
  ),
  SilhouetteLevel(
    id: 21,
    name: 'Cat',
    themeEmoji: '\uD83D\uDC08',
    description: 'Fill the cat with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(catMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[20]),
  ),
  SilhouetteLevel(
    id: 22,
    name: 'Paw',
    themeEmoji: '\uD83D\uDC3E',
    description: 'Fill the paw with arrows',
    gridCols: 16,
    gridRows: 12,
    mask: _parseMask(pawMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[21]),
  ),
  SilhouetteLevel(
    id: 23,
    name: 'Bell',
    themeEmoji: '\uD83D\uDD14',
    description: 'Fill the bell with arrows',
    gridCols: 16,
    gridRows: 15,
    mask: _parseMask(bellMaskCompact),
    config: LevelConfig.hard,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[22]),
  ),
  SilhouetteLevel(
    id: 24,
    name: 'Car',
    themeEmoji: '\uD83D\uDE97',
    description: 'Fill the car with arrows',
    gridCols: 16,
    gridRows: 16,
    mask: _parseMask(carMaskCompact),
    config: LevelConfig.extreme,
    arrowFactory: () => _generateLevelArrows(silhouetteLevels[23]),
  ),
];