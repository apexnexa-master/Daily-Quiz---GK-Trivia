import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gk_quiz_app/presentation/screens/games/two_car/two_car_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('dual drive renders and starts a run', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TwoCarScreen()),
      ),
    );

    expect(find.text('DUAL DRIVE'), findsNWidgets(2));
    expect(find.text('START'), findsOneWidget);

    await tester.tap(find.text('START'));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('START'), findsNothing);
    expect(find.text('LEFT HAND'), findsNothing);
    expect(find.text('RIGHT HAND'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two pointers steer independent halves', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: TwoCarScreen()),
      ),
    );
    await tester.tap(find.text('START'));
    await tester.pump(const Duration(milliseconds: 16));

    final listenerCenter = tester.getCenter(find.byType(Listener).first);
    final left = TestPointer(1);
    final right = TestPointer(2);

    left.down(listenerCenter - const Offset(90, 0));
    right.down(listenerCenter + const Offset(90, 0));
    await tester.pump(const Duration(milliseconds: 16));

    left.move(listenerCenter - const Offset(40, 0));
    right.move(listenerCenter + const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 16));

    left.up();
    right.up();
    await tester.pump(const Duration(milliseconds: 16));

    expect(tester.takeException(), isNull);
  });
}
