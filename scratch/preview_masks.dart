import '../lib/presentation/screens/games/arrow_silhouette/silhouette_levels.dart';

void preview(String name, List<List<bool>> mask) {
  print('\n=== $name ===');
  for (final row in mask) {
    final sb = StringBuffer();
    for (final v in row) {
      sb.write(v ? '##' : '  ');
    }
    print(sb.toString());
  }
}

void main() {
  for (final level in silhouetteLevels) {
    final w = level.mask.map((r) => r.length).toSet();
    print('id=${level.id} ${level.name} rows=${level.gridRows} cols=${level.gridCols} '
        'widths={$w} arrows=${level.config.minArrows}-${level.config.maxArrows}');
    preview('${level.id} ${level.name}', level.mask);
  }
}