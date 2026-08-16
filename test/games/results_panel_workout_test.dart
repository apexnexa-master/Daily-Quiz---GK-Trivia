import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gk_quiz_app/presentation/games/widgets/game_results_panel.dart';

Widget _panel({String? continueLabel, VoidCallback? onContinue}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          GameResultsPanel(
            title: "TIME'S UP!",
            score: 75,
            isNewBest: true,
            stats: const [
              GameResultStat(
                label: 'SOLVED',
                value: '9',
                icon: Icons.check_circle_rounded,
                color: Colors.blue,
              ),
            ],
            playAgainLabel: 'PLAY AGAIN',
            shareLabel: 'SHARE SCORE',
            exitLabel: 'EXIT',
            onPlayAgain: () {},
            onShare: () {},
            onExit: () {},
            continueLabel: continueLabel,
            onContinue: onContinue,
          ),
        ],
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('workout mode shows only CONTINUE (no play again / share / exit)',
      (WidgetTester tester) async {
    await tester.pumpWidget(_panel(
      continueLabel: 'CONTINUE',
      onContinue: () {},
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CONTINUE'), findsOneWidget);
    expect(find.text('PLAY AGAIN'), findsNothing);
    expect(find.text('SHARE SCORE'), findsNothing);
    expect(find.text('EXIT'), findsNothing);
  });

  testWidgets('standalone mode keeps PLAY AGAIN / SHARE / EXIT',
      (WidgetTester tester) async {
    await tester.pumpWidget(_panel());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CONTINUE'), findsNothing);
    expect(find.text('PLAY AGAIN'), findsOneWidget);
    expect(find.text('SHARE SCORE'), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
  });
}
