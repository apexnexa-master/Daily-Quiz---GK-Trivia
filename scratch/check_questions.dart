// scratch/check_questions.dart
import 'dart:convert';
import 'dart:io';

void main() async {
  final directory = Directory('d:/AndroidStudiosAndFlutterThings/flutterProjects/gk_quiz_app/gk_quiz_app/assets/questions');
  if (!directory.existsSync()) {
    print('Directory does not exist');
    return;
  }

  int totalFound = 0;
  int validCount = 0;

  final files = directory.listSync();
  for (final file in files) {
    if (file is File && file.path.endsWith('.json')) {
      try {
        final content = file.readAsStringSync();
        final List<dynamic> list = jsonDecode(content);
        for (final item in list) {
          totalFound++;
          final text = item['text'] ?? {};
          final options = item['options'] ?? {};
          final correctIndex = item['correctIndex'] ?? item['correct_index'];

          final textEn = text['en']?.toString().trim() ?? '';
          final textHi = text['hi']?.toString().trim() ?? '';
          final textBn = text['bn']?.toString().trim() ?? '';

          final optEn = options['en'] as List?;
          final optHi = options['hi'] as List?;
          final optBn = options['bn'] as List?;

          bool isValid = true;
          if (textEn.isEmpty || textHi.isEmpty || textBn.isEmpty) {
            isValid = false;
          }
          if (optEn == null || optEn.length < 4 || optEn.any((e) => e.toString().trim().isEmpty)) {
            isValid = false;
          }
          if (optHi == null || optHi.length < 4 || optHi.any((e) => e.toString().trim().isEmpty)) {
            isValid = false;
          }
          if (optBn == null || optBn.length < 4 || optBn.any((e) => e.toString().trim().isEmpty)) {
            isValid = false;
          }
          if (correctIndex == null || correctIndex < 0 || correctIndex > 3) {
            isValid = false;
          }

          if (isValid) {
            validCount++;
          }
        }
      } catch (e) {
        print('Error reading ${file.path}: $e');
      }
    }
  }

  print('Total Questions Found: $totalFound');
  print('Valid Questions (Fully translated, 4 valid options): $validCount');
}
