// lib/presentation/screens/games/synapse_recall/memory_object.dart
// Abstract memory objects used by Synapse Recall.
//
// Every object pairs a distinctive, instantly-recognisable Material icon with a
// *color* so players never rely on colour alone (accessibility). Icons are far
// easier to name and chunk ("star", "lightning", "shield") than abstract
// polygons, which measurably improves working-memory performance.

import 'package:flutter/material.dart';

/// The recognisable silhouettes available to the game.
///
/// Adding a new shape later only requires an enum value and a label — the
/// board, tiles and engine adapt automatically because every board renders
/// objects from this enum.
enum MemoryShape {
  diamond('Diamond', Icons.diamond_rounded),
  triangle('Triangle', Icons.change_history_rounded),
  circle('Circle', Icons.circle),
  star('Star', Icons.star_rounded),
  hexagon('Hexagon', Icons.hexagon_rounded),
  ring('Ring', Icons.radio_button_unchecked),
  cross('Cross', Icons.add_rounded),
  crescent('Crescent', Icons.dark_mode_rounded),
  crystal('Crystal', Icons.auto_awesome_rounded),
  node('Node', Icons.hub_rounded),
  bolt('Bolt', Icons.bolt_rounded),
  shield('Shield', Icons.shield_rounded);

  const MemoryShape(this.label, this.iconData);

  final String label;

  /// The crisp Material glyph used to render this shape.
  final IconData iconData;
}

/// Every palette color used by memory objects. Colors repeat across *different*
/// shapes so the shape, not the color, is always the primary cue.
class MemoryPalette {
  MemoryPalette._();

  static const List<Color> colors = [
    Color(0xFFD4FF50), // lime
    Color(0xFF00F1FE), // cyan
    Color(0xFFB388FF), // purple
    Color(0xFFFF5FA2), // pink
    Color(0xFFFFC531), // amber
    Color(0xFF43E29A), // emerald
  ];

  static const Map<int, String> colorLabels = {
    0: 'Lime',
    1: 'Cyan',
    2: 'Purple',
    3: 'Pink',
    4: 'Amber',
    5: 'Emerald',
  };

  static String colorLabel(Color color) {
    for (final entry in colorLabels.entries) {
      if (colors[entry.key] == color) return entry.value;
    }
    return 'Colored';
  }
}

/// A single memory object: a [shape] rendered in a [color].
class MemoryObject {
  final MemoryShape shape;
  final Color color;

  const MemoryObject({required this.shape, required this.color});

  String get label => '${MemoryPalette.colorLabel(color)} ${shape.label}';

  @override
  bool operator ==(Object other) =>
      other is MemoryObject && other.shape == shape && other.color == color;

  @override
  int get hashCode => Object.hash(shape, color);
}

/// Convenience widget that renders a [MemoryObject] as a premium icon.
class MemoryObjectView extends StatelessWidget {
  final MemoryObject object;
  final double size;
  final bool glow;

  const MemoryObjectView({
    super.key,
    required this.object,
    this.size = 48,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = object.color;
    final hsl = HSLColor.fromColor(color);
    final light = hsl.withLightness((hsl.lightness + 0.20).clamp(0.0, 1.0)).toColor();
    final dark = hsl.withLightness((hsl.lightness - 0.22).clamp(0.0, 1.0)).toColor();

    final iconSize = size * 0.74;

    final base = Icon(object.shape.iconData, size: iconSize, color: color);

    // Flat-3D gradient fill (lit from the top-left).
    final gradientIcon = ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, color, dark],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(bounds),
      child: base,
    );

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (glow)
            Icon(
              object.shape.iconData,
              size: iconSize * 1.18,
              color: color.withValues(alpha: 0.32),
            ),
          gradientIcon,
        ],
      ),
    );
  }
}
