// validate_arb.dart
//
// Проверяет консистентность ARB-файлов локализации:
//   1. Каждый файл — валидный JSON
//   2. Набор ключей во всех локалях совпадает с базовой локалью
//      (нет пропущенных и нет "лишних" ключей, которых нет в базе)
//   3. Плейсхолдеры вида {name} совпадают между базовой строкой и переводом
//   4. Значения не пустые
//   5. В значениях нет HTML/скриптовых тегов (защита от injection)
//
// Использование:
//   dart run tool/validate_arb.dart lib/l10n [base_locale]
//   base_locale по умолчанию: ru

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Использование: dart run validate_arb.dart <папка с .arb> [base_locale]',
    );
    exit(1);
  }

  final dir = Directory(args[0]);
  if (!dir.existsSync()) {
    stderr.writeln('Папка не найдена: ${args[0]}');
    exit(1);
  }
  final baseLocale = args.length > 1 ? args[1] : 'ru';

  final arbFiles =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (arbFiles.isEmpty) {
    stderr.writeln('В папке ${args[0]} не найдено ни одного .arb файла');
    exit(1);
  }

  var hasErrors = false;
  final parsed = <String, Map<String, dynamic>>{};

  // 1. Парсинг + проверка валидности JSON
  for (final file in arbFiles) {
    final locale = _localeFromFileName(file.path);
    try {
      parsed[locale] =
          jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      print('❌ ${file.path}: некорректный JSON ($e)');
      hasErrors = true;
    }
  }

  if (!parsed.containsKey(baseLocale)) {
    stderr.writeln('❌ Базовая локаль "$baseLocale" не найдена среди файлов');
    exit(1);
  }

  final baseKeys = parsed[baseLocale]!.keys
      .where((k) => !k.startsWith('@'))
      .toSet();
  final basePlaceholders = <String, Set<String>>{
    for (final k in baseKeys)
      k: _extractPlaceholders(parsed[baseLocale]![k]?.toString() ?? ''),
  };

  // 2-4. Сверка каждой локали с базой
  for (final locale in parsed.keys) {
    if (locale == baseLocale) continue;
    final content = parsed[locale]!;
    final keys = content.keys.where((k) => !k.startsWith('@')).toSet();

    final missing = baseKeys.difference(keys);
    final extra = keys.difference(baseKeys);

    if (missing.isNotEmpty) {
      print('❌ $locale: не хватает ключей: ${missing.join(", ")}');
      hasErrors = true;
    }
    if (extra.isNotEmpty) {
      print(
        '⚠️  $locale: лишние ключи (отсутствуют в базовой локали "$baseLocale"): ${extra.join(", ")}',
      );
    }

    for (final key in keys.intersection(baseKeys)) {
      final value = content[key];

      if (value is! String) continue;

      if (value.trim().isEmpty) {
        print('❌ $locale/$key: пустое значение перевода');
        hasErrors = true;
        continue;
      }

      final placeholders = _extractPlaceholders(value);
      final expected = basePlaceholders[key] ?? {};
      if (!_setEquals(placeholders, expected)) {
        print(
          '❌ $locale/$key: плейсхолдеры не совпадают с базой '
          '(ожидались: ${expected.join(", ")}; получены: ${placeholders.join(", ")})',
        );
        hasErrors = true;
      }

      if (_containsForbiddenHtml(value)) {
        print(
          '❌ $locale/$key: найдены HTML/script-теги в переводе — потенциальный injection',
        );
        hasErrors = true;
      }
    }
  }

  if (hasErrors) {
    stderr.writeln('\nВалидация ARB провалена.');
    exit(1);
  }

  print('\n✅ Все ARB-файлы консистентны.');
}

String _localeFromFileName(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final match = RegExp(r'_([a-zA-Z]{2,3}(_[A-Z]{2})?)\.arb$').firstMatch(name);
  return match != null ? match.group(1)! : 'unknown';
}

/// Достаёт имена плейсхолдеров вида {name} или {count, plural, ...} —
/// в последнем случае берётся только имя переменной перед запятой.
Set<String> _extractPlaceholders(String value) {
  final result = <String>{};
  final matches = RegExp(r'\{([^{},]+)[,}]').allMatches(value);
  for (final m in matches) {
    final name = m.group(1)?.trim();
    if (name != null && name.isNotEmpty) result.add(name);
  }
  return result;
}

bool _setEquals(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Простая эвристика: ищем угловые скобки с похожим на тег содержимым.
bool _containsForbiddenHtml(String value) {
  return RegExp(
    r'<\s*(script|iframe|img|a|div|span|style)\b',
    caseSensitive: false,
  ).hasMatch(value);
}
