import 'level_schema.dart';
import 'procedural_generator.dart';
import 'shape_masks.dart';

class ChapterDef {
  final int id;
  final String name;
  final String theme;
  final int startLevel;
  final int endLevel;

  const ChapterDef({
    required this.id,
    required this.name,
    required this.theme,
    required this.startLevel,
    required this.endLevel,
  });

  bool contains(int levelId) => levelId >= startLevel && levelId <= endLevel;
}

class LevelDef {
  final int levelId;
  final int chapterId;
  final int targetMoves;
  final int bossMoveLimit;
  final String? shapeSilhouetteId;
  final LevelData levelData;

  const LevelDef({
    required this.levelId,
    required this.chapterId,
    required this.targetMoves,
    this.bossMoveLimit = 0,
    this.shapeSilhouetteId,
    required this.levelData,
  });

  bool get isBossLevel => bossMoveLimit > 0;
  bool get isShowcaseLevel => levelId == 10 || levelId == 20 || levelId == 30;
}

const List<ChapterDef> kChapters = [
  ChapterDef(id: 1, name: 'The Beginning', theme: 'Minimalist', startLevel: 1, endLevel: 25),
  ChapterDef(id: 2, name: 'Crossroads', theme: 'Neon', startLevel: 26, endLevel: 50),
  ChapterDef(id: 3, name: 'The Gauntlet', theme: 'Cyber City', startLevel: 51, endLevel: 75),
  ChapterDef(id: 4, name: 'Portal Nexus', theme: 'Retro Arcade', startLevel: 76, endLevel: 100),
];

ChapterDef getChapterForLevel(int levelId) {
  for (final ch in kChapters) {
    if (ch.contains(levelId)) return ch;
  }
  return kChapters.last;
}

class CampaignCatalog {
  final Map<int, LevelDef> _levels = {};

  CampaignCatalog();

  LevelDef? getLevel(int levelId) {
    if (levelId < 1 || levelId > 100) return null;
    if (!_levels.containsKey(levelId)) {
      _levels[levelId] = _generateSingleLevel(levelId);
    }
    return _levels[levelId];
  }

  List<LevelDef> getLevelsInChapter(int chapterId) {
    // Generate levels in the chapter if not already cached
    final chapterStart = (chapterId - 1) * 25 + 1;
    final chapterEnd = chapterId * 25;
    for (int id = chapterStart; id <= chapterEnd; id++) {
      getLevel(id);
    }
    return _levels.values
        .where((l) => l.chapterId == chapterId)
        .toList()
      ..sort((a, b) => a.levelId.compareTo(b.levelId));
  }

  List<LevelDef> getAllLevels() {
    for (int id = 1; id <= 100; id++) {
      getLevel(id);
    }
    final list = _levels.values.toList();
    list.sort((a, b) => a.levelId.compareTo(b.levelId));
    return list;
  }

  int get totalLevels => 100;

  static CampaignCatalog createFullCatalog() {
    return CampaignCatalog();
  }
}

LevelDef _generateSingleLevel(int levelId) {
  final shapes = kShapeMasks.map((s) => s.id).toList();
  final chapterId = levelId <= 25 ? 1 : (levelId <= 50 ? 2 : (levelId <= 75 ? 3 : 4));
  final isBoss = levelId == 25 || levelId == 50 || levelId == 75 || levelId == 100;
  final config = GenerationConfig.forChapter(chapterId);

  ShapeMask shape;
  int cols;
  int rows;

  if (levelId % 5 == 0) {
    final shapeIndex = ((levelId ~/ 5) - 1) % 6;
    final shapeId = [
      'kinetic_rocket',
      'royal_crown',
      'imperial_sword',
      'faceted_diamond',
      'large_heart',
      'horse_face'
    ][shapeIndex];
    shape = getShapeById(shapeId);
    cols = shape.width;
    rows = shape.height;
  } else {
    shape = getShapeById(shapes[(levelId - 1) % shapes.length]);
    final size = ProceduralGenerator.gridSizeForLevel(levelId);
    cols = size;
    rows = (size * 1.5).round();
  }

  final generator = ProceduralGenerator(config: config);
  final levelData = generator.generate(cols, rows, shape,
      levelId: levelId, chapterId: chapterId);

  final arrowCount = levelData.arrows.length;
  return LevelDef(
    levelId: levelId,
    chapterId: chapterId,
    targetMoves: arrowCount,
    bossMoveLimit: isBoss ? (arrowCount * 1.5).round() : 0,
    shapeSilhouetteId: shape.id,
    levelData: levelData,
  );
}
