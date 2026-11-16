import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/widgets/workout_card.dart';

void main() {
  for (final width in [288.0, 328.0, 600.0]) {
    for (final brightness in [Brightness.dark, Brightness.light]) {
      testWidgets('workout card fits ${width.toInt()} $brightness', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: width,
                  child: const QuickBrainWorkoutCard(lang: 'en'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('BRAIN WORKOUT'), findsOneWidget);
      });
    }
  }
}
