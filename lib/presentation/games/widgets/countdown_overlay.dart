// lib/presentation/games/widgets/countdown_overlay.dart
// A drop-in start gate that used to play a 3-2-1-GO sequence.
//
// Games now begin immediately after the player taps Start, so this widget
// simply hands control back on the next frame without showing anything.

import 'package:flutter/material.dart';

class CountdownOverlay extends StatefulWidget {
  /// Called once on the next frame so the game can start immediately.
  final VoidCallback onFinished;

  final String goLabel;

  const CountdownOverlay({
    super.key,
    required this.onFinished,
    this.goLabel = 'GO!',
  });

  @override
  State<CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<CountdownOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFinished();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
