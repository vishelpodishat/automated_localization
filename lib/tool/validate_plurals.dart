// validate_plurals.dart
// ignore_for_file: avoid_print
//
// Проверяет, что во всех ARB-файлах локализации корректно заполнены
// формы множественного числа (ICU plural categories: zero/one/two/few/many/other)
// для каждого языка согласно правилам CLDR.
//
// Использование:
//   dart run tool/validate_plurals.dart lib/l10n
//
// Возвращает код выхода 1 (и падает CI-джоба), если для какого-то языка
// не хватает обязательной формы или отсутствует категория "other".

import 'dart:convert';
import 'dart:io';

/// Какие ICU plural-категории обязательны для каждого языка (по CLDR).
/// Список неполный — дополняйте под свои локали.
const Map<String, Set<String>> requiredCategories = {
  'en': {'one', 'other'},
  'ru': {'one', 'few', 'many', 'other'},
  'uk': {'one', 'few', 'many', 'other'},
  'pl': {'one', 'few', 'many', 'other'},
  'kk': {'other'},
  'ar': {'zero', 'one', 'two', 'few', 'many', 'other'},
};

const List<String> allKnownCategories = [
  'zero',
  'one',
  'two',
  'few',
  'many',
  'other',
];

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln(
      'Использование: dart run validate_plurals.dart <папка с .arb>',
    );
    exit(1);
  }

  final dir = Directory(args[0]);
  if (!dir.existsSync()) {
    stderr.writeln('Папка не найдена: ${args[0]}');
    exit(1);
  }

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

  for (final file in arbFiles) {
    final locale = _localeFromFileName(file.path);
    late Map<String, dynamic> content;
    try {
      content = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } catch (e) {
      stderr.writeln('❌ ${file.path}: не удалось распарсить JSON ($e)');
      hasErrors = true;
      continue;
    }

    for (final entry in content.entries) {
      final key = entry.key;
      if (key.startsWith('@')) continue; // это метаданные, а не строка перевода
      final value = entry.value;
      if (value is! String || !value.contains(', plural,')) continue;

      final categories = _extractPluralCategories(value);
      if (categories == null) {
        print(
          '⚠️  $locale/$key: не удалось разобрать plural-конструкцию — проверьте вручную',
        );
        continue;
      }

      if (!categories.contains('other')) {
        print('❌ $locale/$key: отсутствует обязательная категория "other"');
        hasErrors = true;
      }

      final required = requiredCategories[locale];
      if (required != null) {
        final missing = required.difference(categories);
        if (missing.isNotEmpty) {
          print(
            '❌ $locale/$key: не хватает форм множественного числа '
            'для языка "$locale": ${missing.join(", ")}',
          );
          hasErrors = true;
        }
      }

      final unknown = categories.difference(allKnownCategories.toSet());
      if (unknown.isNotEmpty) {
        print(
          '⚠️  $locale/$key: неизвестные категории (возможна опечатка): '
          '${unknown.join(", ")}',
        );
      }
    }
  }

  if (hasErrors) {
    stderr.writeln('\nВалидация plural-форм провалена.');
    exit(1);
  }

  print('\n✅ Все plural-формы на месте.');
}

/// Извлекает код языка из имени файла вида app_ru.arb -> ru, app_en_US.arb -> en_US.
String _localeFromFileName(String path) {
  final name = path.split(Platform.pathSeparator).last;
  final match = RegExp(r'_([a-zA-Z]{2,3}(_[A-Z]{2})?)\.arb$').firstMatch(name);
  return match != null ? match.group(1)! : 'unknown';
}

/// Достаёт имена plural-категорий (one/few/many/other/...) из ICU-строки вида
/// "{count, plural, one{...} few{...} other{...}}", корректно учитывая
/// вложенные фигурные скобки внутри каждой ветки (например {count} внутри текста).
/// Возвращает null, если строку не удалось корректно разобрать.
Set<String>? _extractPluralCategories(String value) {
  final pluralMarker = ', plural,';
  final pluralIndex = value.indexOf(pluralMarker);
  if (pluralIndex == -1) return null;

  var i = pluralIndex + pluralMarker.length;
  final categories = <String>{};
  final n = value.length;

  while (i < n) {
    while (i < n && value[i].trim().isEmpty) {
      i++;
    }
    if (i >= n) break;
    if (value[i] == '}') break; // конец всей plural-конструкции

    final start = i;
    while (i < n && value[i] != '{') {
      i++;
    }
    if (i >= n) return null; // некорректный формат — не нашли '{'
    final category = value.substring(start, i).trim();

    var depth = 1;
    i++; // пропускаем открывающую '{'
    while (i < n && depth > 0) {
      if (value[i] == '{') depth++;
      if (value[i] == '}') depth--;
      i++;
    }
    if (depth != 0) return null; // не нашли парную закрывающую скобку

    // категории вида "=0", "=1" (точные значения) не являются
    // грамматическими формами и не обязательны — не считаем их
    if (!category.startsWith('=') && category.isNotEmpty) {
      categories.add(category);
    }
  }

  return categories;
}
