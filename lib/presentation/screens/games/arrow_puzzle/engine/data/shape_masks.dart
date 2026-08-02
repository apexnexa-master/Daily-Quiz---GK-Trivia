import 'package:vector_math/vector_math_64.dart';

class ShapeMask {
  final String id;
  final String name;
  final int width;
  final int height;
  final List<List<bool>> cells;

  const ShapeMask({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.cells,
  });

  List<Vector2> getFilledPositions() {
    final positions = <Vector2>[];
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (cells[y][x]) {
          positions.add(Vector2(x.toDouble(), y.toDouble()));
        }
      }
    }
    return positions;
  }

  ShapeMask scaleToFit(int targetWidth, int targetHeight) {
    final scaleX = targetWidth / width;
    final scaleY = targetHeight / height;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final int newW = (width * scale).round().clamp(1, targetWidth);
    final int newH = (height * scale).round().clamp(1, targetHeight);
    final offsetX = (targetWidth - newW) ~/ 2;
    final offsetY = (targetHeight - newH) ~/ 2;

    final scaled = List.generate(targetHeight, (_) => List.filled(targetWidth, false));
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (cells[y][x]) {
          final sx = offsetX + (x * newW ~/ width);
          final sy = offsetY + (y * newH ~/ height);
          if (sx >= 0 && sx < targetWidth && sy >= 0 && sy < targetHeight) {
            scaled[sy][sx] = true;
          }
        }
      }
    }
    return ShapeMask(id: id, name: name, width: targetWidth, height: targetHeight, cells: scaled);
  }

  static ShapeMask fromString(String id, String name, List<String> ascii) {
    final h = ascii.length;
    final w = ascii.map((s) => s.length).reduce((a, b) => a > b ? a : b);
    final cells = List.generate(h, (_) => List.filled(w, false));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < ascii[y].length; x++) {
        cells[y][x] = ascii[y][x] == '1';
      }
    }
    return ShapeMask(id: id, name: name, width: w, height: h, cells: cells);
  }
}

final List<ShapeMask> kShapeMasks = [
  ShapeMask.fromString('heart', 'Heart', [
    '01110',
    '11111',
    '11111',
    '01110',
    '00100',
  ]),
  ShapeMask.fromString('star', 'Star', [
    '00100',
    '01110',
    '11111',
    '01110',
    '00100',
  ]),
  ShapeMask.fromString('diamond', 'Diamond', [
    '00100',
    '01110',
    '11111',
    '01110',
    '00100',
  ]),
  ShapeMask.fromString('cross', 'Cross', [
    '00100',
    '00100',
    '11111',
    '00100',
    '00100',
  ]),
  ShapeMask.fromString('butterfly', 'Butterfly', [
    '11011',
    '11111',
    '01110',
    '11111',
    '11011',
  ]),
  ShapeMask.fromString('fish', 'Fish', [
    '01110',
    '11111',
    '11111',
    '11111',
    '01110',
  ]),
  ShapeMask.fromString('bird', 'Bird', [
    '00100',
    '01110',
    '11111',
    '01100',
    '00100',
  ]),
  ShapeMask.fromString('rabbit', 'Rabbit', [
    '11000',
    '11110',
    '11111',
    '01111',
    '00011',
  ]),
  ShapeMask.fromString('car', 'Car', [
    '01110',
    '11111',
    '11111',
    '11111',
    '01110',
  ]),
  ShapeMask.fromString('rocket', 'Rocket', [
    '00100',
    '01110',
    '11111',
    '01110',
    '00100',
  ]),
  ShapeMask.fromString('ship', 'Ship', [
    '00100',
    '01110',
    '11111',
    '11111',
    '11111',
  ]),
  ShapeMask.fromString('plane', 'Plane', [
    '00010',
    '00110',
    '11111',
    '00110',
    '00010',
  ]),
  ShapeMask.fromString('castle', 'Castle', [
    '10001',
    '11111',
    '11111',
    '11111',
    '11111',
  ]),
  ShapeMask.fromString('house', 'House', [
    '00100',
    '01110',
    '11111',
    '11111',
    '11111',
  ]),
  ShapeMask.fromString('tower', 'Tower', [
    '00100',
    '01110',
    '01110',
    '01110',
    '11111',
  ]),
  ShapeMask.fromString('bridge', 'Bridge', [
    '10001',
    '10001',
    '11111',
    '11111',
    '11111',
  ]),
  ShapeMask.fromString('smiley', 'Smiley', [
    '01110',
    '10001',
    '10101',
    '10001',
    '01110',
  ]),
  ShapeMask.fromString('music_note', 'Music Note', [
    '00110',
    '00110',
    '00110',
    '00110',
    '11110',
  ]),
  ShapeMask.fromString('sun', 'Sun', [
    '01010',
    '11111',
    '11111',
    '11111',
    '01010',
  ]),
  ShapeMask.fromString('moon', 'Moon', [
    '01110',
    '11100',
    '11110',
    '11100',
    '01110',
  ]),
  ShapeMask.fromString('zigzag', 'Zigzag', [
    '11100',
    '00110',
    '01100',
    '11000',
    '00111',
  ]),
  ShapeMask.fromString('spiral', 'Spiral', [
    '11111',
    '01110',
    '01010',
    '01110',
    '11111',
  ]),
  ShapeMask.fromString('arrow_shape', 'Arrow Shape', [
    '00100',
    '01110',
    '11111',
    '01110',
    '01110',
  ]),
  ShapeMask.fromString('wave', 'Wave', [
    '11001',
    '00110',
    '11001',
    '00110',
    '11001',
  ]),
  ShapeMask.fromString('crown', 'Crown', [
    '10101',
    '11111',
    '11111',
    '11111',
    '01110',
  ]),
  ShapeMask.fromString('anchor', 'Anchor', [
    '00100',
    '01110',
    '01110',
    '10101',
    '01110',
  ]),
  ShapeMask.fromString('key', 'Key', [
    '11100',
    '10100',
    '11100',
    '00100',
    '01110',
  ]),
  ShapeMask.fromString('lock', 'Lock', [
    '01110',
    '10001',
    '11111',
    '11111',
    '11111',
  ]),
  ShapeMask.fromString('shield', 'Shield', [
    '11111',
    '11111',
    '01110',
    '01110',
    '00100',
  ]),
  ShapeMask.fromString('paw', 'Paw', [
    '10101',
    '01110',
    '11111',
    '01110',
    '00100',
  ]),
  ShapeMask.fromString('kinetic_rocket', 'Kinetic Rocket', [
    '0000100000',
    '0001110000',
    '0011111000',
    '0011111100',
    '0011111100',
    '0011111100',
    '0011111100',
    '0011111100',
    '0111111110',
    '1111111111',
  ]),
  ShapeMask.fromString('royal_crown', 'Royal Crown', [
    '010001100010',
    '010001100010',
    '111001100111',
    '111011110111',
    '111111111111',
    '111111111111',
    '111111111111',
    '111111111111',
    '111111111111',
    '111111111111',
    '011111111110',
    '001111111100',
  ]),
  ShapeMask.fromString('imperial_sword', 'Imperial Sword', [
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00000011100000',
    '00111111111100',
    '00000001100000',
    '00000001100000',
    '00000001100000',
  ]),
  ShapeMask.fromString('faceted_diamond', 'Faceted Diamond', [
    '0001111000',
    '0011111100',
    '0111111110',
    '1111111111',
    '0111111110',
    '0011111100',
    '0001111000',
    '0000110000',
    '0000110000',
    '0000010000',
  ]),
  ShapeMask.fromString('large_heart', 'Large Heart', [
    '001100001100',
    '011110011110',
    '111111111111',
    '111111111111',
    '111111111111',
    '011111111110',
    '011111111110',
    '001111111100',
    '000111111000',
    '000011110000',
    '000001100000',
    '000001100000',
  ]),
  ShapeMask.fromString('horse_face', 'Horse Face', [
    '00110000001100',
    '00110000001100',
    '00111000011100',
    '00111111111100',
    '01111111111110',
    '01111111111110',
    '01111111111110',
    '00111111111100',
    '00111111111100',
    '00111111111100',
    '00011111111000',
    '00001111110000',
    '00001111110000',
    '00011111111000',
  ]),
];

ShapeMask getShapeById(String id) {
  return kShapeMasks.firstWhere((s) => s.id == id);
}
