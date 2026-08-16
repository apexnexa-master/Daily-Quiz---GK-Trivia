import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gk_quiz_app/presentation/screens/games/synapse_recall/memory_object.dart';
import 'package:gk_quiz_app/presentation/screens/games/synapse_recall/synapse_config.dart';
import 'package:gk_quiz_app/presentation/screens/games/synapse_recall/synapse_recall_screen.dart';
import 'package:gk_quiz_app/presentation/workout/workout_models.dart';

List<String> _screenTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .toList();

class _Result {
  String? value;
}

Future<void> _startSynapse(WidgetTester tester, _Result result) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final popped = await Navigator.pushNamed(
                    context,
                    '/synapse-recall',
                    arguments: {
                      'workoutStep': const WorkoutStep(
                        game: WorkoutPresets.synapseRecall,
                        index: 1,
                        total: 3,
                      ),
                    },
                  );
                  result.value = popped?.toString() ?? 'null';
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => const SynapseRecallScreen(),
          settings: settings,
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pump(Duration.zero);
  await tester.pump(const Duration(milliseconds: 400));

  expect(find.text('START'), findsOneWidget,
      reason: 'Screen texts: ${_screenTexts(tester)}');
  await tester.tap(find.text('START'));
  await tester.pump(Duration.zero);

  // Countdown: '3' '2' '1' 'GO!' — one animation completion per pump.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 700));
  }
}

/// Captures the memorize sequence (rendered in order on the board) and waits
/// until the recall grid is up and the memorize board has faded out.
Future<List<MemoryObject>> _captureSequence(
    WidgetTester tester, int viewMs,
    {String? expectRound}) async {
  await tester.pump(Duration(milliseconds: viewMs - 400));
  if (expectRound != null) {
    expect(find.text(expectRound), findsOneWidget,
        reason: 'Screen texts: ${_screenTexts(tester)}');
  }
  final sequence = tester
      .widgetList<MemoryObjectView>(find.byType(MemoryObjectView))
      .map((w) => w.object)
      .toList();
  expect(sequence, isNotEmpty);

  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 500));
  expect(find.text('RECALL'), findsOneWidget,
      reason: 'Screen texts: ${_screenTexts(tester)}');
  return sequence;
}

Future<void> _answer(WidgetTester tester, List<MemoryObject> sequence,
    {required bool correct, bool expectIncorrect = true}) async {
  final objects = tester
      .widgetList<MemoryObjectView>(find.byType(MemoryObjectView))
      .map((w) => w.object)
      .toList();
  final targets = correct
      ? sequence
      : objects.where((o) => !sequence.contains(o)).take(sequence.length);

  for (final obj in targets) {
    final tile = find.byWidgetPredicate(
        (w) => w is MemoryObjectView && w.object == obj);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 60));
  }
  await tester.pump(const Duration(milliseconds: 120));

  if (correct) {
    // Correct → no skip button anywhere, auto-advance fires (1350ms).
    expect(find.text('Skip → next round'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1600));
  } else if (expectIncorrect) {
    expect(find.text('TRY AGAIN'), findsOneWidget,
        reason: 'Screen texts: ${_screenTexts(tester)}');
    expect(find.text('Skip → next round'), findsNothing);
  }
}

int _redHearts(WidgetTester tester) => tester
    .widgetList<Icon>(find.byIcon(Icons.favorite_rounded))
    .where((i) => i.color == const Color(0xFFF43F5E))
    .length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clears all rounds and pops with a workout score',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final result = _Result();
    await _startSynapse(tester, result);

    for (var round = 1; round <= SynapseConfig.sessionRounds; round++) {
      final length = SynapseConfig.roundLengths[round - 1];
      final viewMs =
          (SynapseConfig.viewSecondsForLength(length) * 1000).round();
      final sequence = await _captureSequence(tester, viewMs);
      expect(sequence.length, length);

      if (round == 1) {
        // Lives shown as hearts in the stats row during recall.
        expect(_redHearts(tester), SynapseConfig.startingLives);
      }
      await _answer(tester, sequence, correct: true);
    }

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('SESSION COMPLETE'), findsOneWidget,
        reason: 'Screen texts: ${_screenTexts(tester)}');
    expect(find.text('CONTINUE'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 400));

    expect(result.value, isNotNull);
    expect(int.tryParse(result.value!), isNotNull);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('wrong answers cost lives, retry gives a new question, '
      'and losing all lives ends the game', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final result = _Result();
    await _startSynapse(tester, result);

    final viewMs1 =
        (SynapseConfig.viewSecondsForLength(SynapseConfig.roundLengths[0]) *
                1000)
            .round();

    // Attempt 1 on round 1: wrong → lose a life, TRY AGAIN offered.
    final seq1 = await _captureSequence(tester, viewMs1);
    await _answer(tester, seq1, correct: false);
    expect(_redHearts(tester), 2);

    // TRY AGAIN stays on round 1 but deals a brand-new question.
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pump(Duration.zero);
    final seq2 = await _captureSequence(tester, viewMs1, expectRound: 'ROUND 01');
    expect(seq2, isNot(equals(seq1)));

    // Attempt 2: wrong → one life left.
    await _answer(tester, seq2, correct: false);
    expect(_redHearts(tester), 1);

    // Attempt 3: wrong → lives run out → game over (no TRY AGAIN overlay).
    await tester.tap(find.text('TRY AGAIN'));
    await tester.pump(Duration.zero);
    final seq3 = await _captureSequence(tester, viewMs1);
    await _answer(tester, seq3, correct: false, expectIncorrect: false);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('GAME OVER'), findsOneWidget,
        reason: 'Screen texts: ${_screenTexts(tester)}');
    expect(find.text('CONTINUE'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await tester.pump(Duration.zero);
    await tester.pump(const Duration(milliseconds: 400));

    expect(result.value, isNotNull);
    expect(int.tryParse(result.value!), isNotNull);
    expect(find.text('open'), findsOneWidget);
  });
}
