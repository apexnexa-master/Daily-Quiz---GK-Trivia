import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gk_quiz_app/core/constants/app_constants.dart';
import 'package:gk_quiz_app/core/theme/theme_manager.dart';
import 'package:gk_quiz_app/presentation/widgets/profile/settings_section.dart';

void main() {
  testWidgets('smoke: MaterialApp renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: Text('GK Quiz')),
          ),
        ),
      ),
    );
    expect(find.text('GK Quiz'), findsOneWidget);
  });

  testWidgets('theme sheet labels and applies the selected theme',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefThemeMode: AppThemeMode.light.name,
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SettingsSection(
              lang: 'en',
              themeMode: AppThemeMode.light,
              isDark: false,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    expect(find.text('Light'), findsNWidgets(2));
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.text('Light').last,
          matching: find.byType(InkWell),
        ),
        matching: find.byIcon(Icons.check_circle_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Light').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
        prefs.getString(AppConstants.prefThemeMode), AppThemeMode.light.name);
    expect(find.text('Select Theme'), findsNothing);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(prefs.getString(AppConstants.prefThemeMode), AppThemeMode.dark.name);
  });
}
