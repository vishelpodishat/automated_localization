# Локализация: руководство для разработчиков

Смежный документ: [руководство для переводчиков](LOCALIZATION_TRANSLATORS.md).

## 1. Назначение

Этот документ описывает полный процесс работы с локализацией Flutter-приложения:

```text
Google Sheet
-> sheety_localization
-> ARB и generated Dart
-> автоматические проверки
-> GitHub approval
-> Shorebird patch
```

Google Sheet является основным источником истины. Сгенерированные ARB и Dart-файлы
не следует редактировать как постоянное хранилище переводов: следующая генерация
перезапишет их содержимым таблицы.

Поддерживаемые локали:

```text
ru - русский, базовая локаль
kk - казахский
en - английский
```

## 2. Ответственность файлов

```text
lib/src/l10n/localization/
  app_ru.arb
  app_kk.arb
  app_en.arb

lib/src/generated/
  locales.dart
  localization/
    localization_localization.dart
    localization_localization_ru.dart
    localization_localization_kk.dart
    localization_localization_en.dart

lib/localization.dart
```

- `lib/src/l10n/localization/*.arb` — промежуточные файлы, генерируемые из Sheet.
- `lib/src/generated/**` — generated Dart API. Ручные изменения запрещены.
- `lib/localization.dart` — generated barrel-файл для импорта локализации.
- `lib/tool/validate_arb.dart` — проверка JSON, ключей, placeholders и значений.
- `lib/tool/validate_plurals.dart` — проверка ICU plural-категорий.
- `lib/tool/export_arb_to_sheet.py` — безопасный экспорт новых ARB-ключей в Sheet.

Название вкладки Google Sheet определяет имя подпапки и generated-класса.
Вкладка `localization` при базовых параметрах:

```text
--arb=src/l10n
--gen=src/generated
```

создаёт:

```text
lib/src/l10n/localization/
lib/src/generated/localization/
```

Не добавляйте `localization` в параметры `--arb` или `--gen`, иначе появится
лишний уровень `localization/localization`.

## 3. Структура Google Sheet

Рабочая вкладка называется `localization`. Первая строка должна содержать:

```text
label | description | meta | ru | kk | en
```

Назначение колонок:

| Колонка | Назначение |
|---|---|
| `label` | Уникальный Dart-ключ, например `profileTitle` |
| `description` | Контекст для переводчика и комментарий в ARB |
| `meta` | JSON-метаданные ARB; для обычной строки используется `{}` |
| `ru` | Русский перевод и базовое значение |
| `kk` | Казахский перевод |
| `en` | Английский перевод |

Пример:

| label | description | meta | ru | kk | en |
|---|---|---|---|---|---|
| `profileTitle` | Заголовок экрана профиля | `{}` | Профиль | Профиль | Profile |

Правила для `label`:

- Используйте `lowerCamelCase`.
- Ключ должен описывать назначение текста, а не его текущее значение.
- Не переиспользуйте один ключ для текстов с разным контекстом.
- Не переименовывайте опубликованный ключ без изменения кода.
- Не создавайте дубликаты.

## 4. Основной flow: изменение через Google Sheet

Это предпочтительный сценарий.

1. Разработчик создаёт ключ, `description` и при необходимости `meta`.
2. Переводчики заполняют `ru`, `kk`, `en`.
3. Ответственный проверяет, что нет пустых ячеек и placeholders совпадают.
4. Запускается GitHub Actions workflow `Publish localizations`.
5. Sheety генерирует ARB и Dart-файлы во временном GitHub runner.
6. CI запускает validation, format, analyze и tests.
7. Generated-файлы и `localization.diff` сохраняются в artifact.
8. Job ожидает approval GitHub environment `production`.
9. После approval публикуется Shorebird patch в выбранный track.

Изменение в Google Sheet само по себе не обновляет установленное приложение.
Нужен успешный publish workflow и Shorebird patch.

## 5. Альтернативный flow: новый ключ сначала создан в ARB

Используйте этот сценарий, если разработчик создал ключ локально до добавления
его в Google Sheet.

### 5.1 Добавить ключ во все локали

Ключ должен присутствовать во всех ARB:

```json
// app_ru.arb
"profileTitle": "Профиль"
```

```json
// app_kk.arb
"profileTitle": "Профиль"
```

```json
// app_en.arb
"profileTitle": "Profile"
```

### 5.2 Проверить ARB локально

```bash
dart run lib/tool/validate_arb.dart lib/src/l10n/localization ru
dart run lib/tool/validate_plurals.dart lib/src/l10n/localization
```

### 5.3 Установить зависимости exporter

Рекомендуется Python 3.12:

```bash
python3 -m pip install -r lib/tool/requirements-l10n.txt
```

### 5.4 Выполнить dry run

Без `--apply` таблица не изменяется:

```bash
python3 lib/tool/export_arb_to_sheet.py \
  --credentials=credentials.json \
  --sheet=REAL_SHEET_ID
```

Ожидаемый план:

```text
[localization]
  append key: profileTitle

dry run: 1 keys appended, 0 empty cells filled
```

### 5.5 Применить экспорт

```bash
python3 lib/tool/export_arb_to_sheet.py \
  --credentials=credentials.json \
  --sheet=REAL_SHEET_ID \
  --apply
```

Успешный результат:

```text
[localization]
  append key: profileTitle

applied: 1 keys appended, 0 empty cells filled
```

### 5.6 Подтвердить результат

Повторный dry run должен показать:

```text
[localization]
  no changes

dry run: 0 keys appended, 0 empty cells filled
```

После этого запустите генерацию из Sheet. Если сначала запустить генерацию, а
ключа ещё нет в Sheet, ручной ключ исчезнет из ARB.

## 6. Безопасность exporter

`export_arb_to_sheet.py` работает консервативно:

- добавляет ключ, которого нет в Sheet;
- добавляет отсутствующую locale-колонку;
- заполняет пустую ячейку значением из ARB;
- не перезаписывает непустое значение в Sheet;
- останавливается при пустом переводе;
- останавливается при дублирующемся `label`;
- проверяет первые колонки `label | description | meta`;
- проверяет наличие вкладки, соответствующей папке ARB.

Пример конфликта:

```text
Sheet changes/ru = "Текст переводчика"
ARB   changes/ru = "Текст разработчика"
```

Exporter сохранит `Текст переводчика`. Для изменения существующего перевода
редактируйте Google Sheet.

Флаг `--allow-empty` разрешает неполные строки и не должен использоваться в
обычном production flow.

## 7. Локальная генерация из Google Sheet

Установить или обновить Sheety:

```bash
dart pub global activate sheety_localization
```

Запустить генерацию:

```bash
dart pub global run sheety_localization:generate \
  --credentials=credentials.json \
  --sheet=REAL_SHEET_ID \
  --lib=lib \
  --arb=src/l10n \
  --gen=src/generated \
  --prefix=app \
  --no-last-modified \
  --format
```

Затем выполнить:

```bash
dart run lib/tool/validate_arb.dart lib/src/l10n/localization ru
dart run lib/tool/validate_plurals.dart lib/src/l10n/localization
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Проверки применяются к результату генерации. Sheety по умолчанию может пропустить
неполную строку Sheet, поэтому автоматическая validation не заменяет проверку
`localization.diff`. Особенно внимательно проверяйте неожиданные удаления ключей.

Проверить конкретный ключ:

```bash
rg "profileTitle" lib/src/l10n lib/src/generated
```

## 8. Использование generated API

Подключение приложения:

```dart
MaterialApp(
  supportedLocales: LocalizationLocalization.supportedLocales,
  localizationsDelegates:
      LocalizationLocalization.localizationsDelegates,
)
```

Получение локализации:

```dart
final l10n = LocalizationLocalization.of(context);
```

Использование строки:

```dart
Text(l10n.profileTitle)
```

Generated-классы не редактируются вручную. Если API отсутствует, исправьте Sheet
или ARB export flow и повторите генерацию.

## 9. Placeholders

Placeholder — часть строки, значение которой передаёт код приложения.

Пример:

```text
ru: Добро пожаловать, {userName}!
kk: Қош келдіңіз, {userName}!
en: Welcome, {userName}!
```

Имя placeholder должно полностью совпадать во всех локалях:

```text
{userName} != {username} != {name}
```

Нельзя переводить, удалять или добавлять placeholder только в одной локали.

При добавлении placeholder generated API меняется с getter на метод. Все места
использования необходимо обновить:

```dart
l10n.welcomeMessage(userName)
```

Метаданные placeholder хранятся в `meta` как валидный JSON. Структурные изменения
`meta` должен выполнять разработчик.

## 10. ICU plural

Пример для русского:

```text
{count, plural,
  one{{count} товар}
  few{{count} товара}
  many{{count} товаров}
  other{{count} товаров}
}
```

Пример для английского:

```text
{count, plural,
  one{{count} item}
  other{{count} items}
}
```

Текущие обязательные категории:

| Локаль | Категории |
|---|---|
| `ru` | `one`, `few`, `many`, `other` |
| `kk` | `other` |
| `en` | `one`, `other` |

Имя счётчика должно совпадать во всех локалях. Например, сочетание `{count}` и
`{cnt}` не пройдёт validation.

## 11. Автоматические проверки

### Validate localization

Запускается на каждом Pull Request и при push в `main`.

Публикует три check:

```text
ARB consistency
Plural forms
Flutter checks
```

`ARB consistency` проверяет:

- JSON;
- наличие базовой локали `ru`;
- отсутствующие ключи относительно `ru`;
- пустые значения в переводах;
- совпадение placeholders;
- запрещённые HTML/script-теги.

`Plural forms` проверяет обязательные ICU-категории.

`Flutter checks` запускает:

```text
flutter pub get
dart format
flutter analyze
flutter test
```

### Export ARB to Google Sheet

Запускается вручную. Перед обращением к Sheet повторно выполняет ARB и plural
validation.

Параметр:

```text
apply=false - только показать план
apply=true  - записать разрешённые изменения
```

GitHub workflow видит только закоммиченные и запушенные ARB.

### Publish localizations

Запускается вручную с параметрами:

```text
release_version - версия Shorebird release, например 1.0.0+1 или latest
track           - staging или stable
```

Рекомендуемое значение `track` — `staging`.

Workflow:

1. Проверяет secrets.
2. Генерирует ARB и Dart из Sheet.
3. Запускает validation, format, analyze и tests.
4. Создаёт `localization.diff`.
5. Загружает artifact `generated-localizations`.
6. Ожидает approval environment `production`.
7. Публикует Android Shorebird patch.

## 12. GitHub secrets и доступы

Repository secrets:

```text
GOOGLE_SERVICE_ACCOUNT_JSON
LOCALIZATION_SHEET_ID
SHOREBIRD_TOKEN
```

- `GOOGLE_SERVICE_ACCOUNT_JSON` — полное содержимое service account JSON.
- `LOCALIZATION_SHEET_ID` — часть URL между `/d/` и `/edit`.
- `SHOREBIRD_TOKEN` — API key Shorebird с правом release/patch.

Никогда не коммитьте:

```text
credentials.json
private keys
SHOREBIRD_TOKEN
```

Service account должен иметь:

- `Viewer` для генерации Sheet -> ARB;
- `Editor` для exporter ARB -> Sheet.

GitHub environment `production` должен иметь required reviewers.

## 13. Блокировка merge

Для `main` должен быть активен GitHub ruleset:

```text
Require a pull request before merging
Require status checks to pass before merging
```

Required checks:

```text
ARB consistency
Plural forms
Flutter checks
```

Рекомендуется также:

```text
Require branches to be up to date before merging
Require conversation resolution before merging
Do not allow bypassing the above settings
```

Если check красный или выполняется, Merge должен быть недоступен.

## 14. Shorebird release и patch

Первый patch нельзя создать без release.

Инициализация:

```bash
shorebird login
shorebird init --display-name "Automated Localization"
shorebird doctor
```

Файл `shorebird.yaml` должен быть закоммичен.

Создание первого release:

```bash
shorebird release android
```

Локальная установка release:

```bash
shorebird preview --release-version 1.0.0+1
```

После staging patch:

```bash
shorebird preview \
  --track staging \
  --release-version 1.0.0+1
```

При стандартном auto-update:

1. Первый запуск обнаруживает и скачивает patch.
2. Приложение нужно полностью закрыть.
3. На следующем запуске patch становится активным.

Не запускайте localization patch из ветки с посторонними Dart-изменениями:
Shorebird может включить в patch все отличия относительно release.

## 15. Удаление и переименование ключей

Удаление строки из Sheet удалит ключ из generated ARB и Dart при следующей
генерации. Если код всё ещё использует ключ, `flutter analyze` или tests упадут.

Полное удаление одного и того же ключа из всех локалей само по себе не является
ошибкой консистентности. Поэтому перед approval обязательно проверяйте
`localization.diff`.

Безопасное удаление:

1. Удалить использование ключа из Dart-кода.
2. Выпустить и проверить изменение кода.
3. Удалить строку из Sheet.
4. Запустить publish workflow.
5. Проверить diff, analyze и tests.

Переименование считается созданием нового ключа и удалением старого.

## 16. Известные ограничения validation

- Проверки работают с generated ARB, а не напрямую с каждой ячейкой Sheet.
- Неполная строка может быть пропущена Sheety до запуска ARB validation.
- Ключ, удалённый сразу из всех локалей, выглядит консистентно.
- Лишний ключ, которого нет в базовой `ru`, сейчас выводится как warning в
  `validate_arb.dart`; exporter при этом остановится, если ключ заполнен не во
  всех локалях.
- Автоматические проверки не оценивают смысл, терминологию и длину перевода в UI.

Поэтому обязательны:

```text
проверка заполненности Sheet
проверка localization.diff
staging-проверка на устройстве
```

## 17. Добавление локали

1. Согласовать locale code.
2. Добавить колонку в Sheet.
3. Заполнить все значения.
4. Добавить plural-категории в `requiredCategories`, если язык ещё не описан.
5. Запустить генерацию.
6. Проверить `supportedLocales` и `locales.dart`.
7. Проверить платформенные настройки Android/iOS.
8. Пройти Flutter tests и ручную проверку языка.

Пустая новая locale-колонка может привести к пропуску строк генератором.

## 18. Диагностика ошибок

### `Missing GOOGLE_SERVICE_ACCOUNT_JSON secret`

Добавьте Repository Secret в:

```text
Settings -> Secrets and variables -> Actions
```

### `Requested entity was not found` или `SpreadsheetNotFound`

Проверьте:

- используется реальный Sheet ID, а не `ТВОЙ_SHEET_ID`;
- таблица расшарена на `client_email` из credentials;
- service account имеет нужную роль;
- Google Sheets API включён.

### Python 3.9 EOL или LibreSSL warning

Это предупреждения локального Python, а не причина `404`. Используйте Python
3.12 или запускайте GitHub workflow, где настроен Python 3.12.

### Появился путь `localization/localization`

Проверьте параметры:

```text
--arb=src/l10n
--gen=src/generated
```

### `Missing shorebird.yaml`

Выполните `shorebird init` и закоммитьте созданный файл.

### Dry run показывает `append key`

Это ожидаемый план. Запустите exporter с `--apply`, затем повторите dry run.

### Dry run показывает `fill empty cell`

Ключ уже существует, но одна из Sheet-ячеек пуста. `--apply` заполнит только эту
пустую ячейку.

### Dry run показывает `no changes`

ARB и Sheet синхронизированы с точки зрения безопасного exporter.

## 19. Чек-лист Pull Request

- [ ] Новые ключи присутствуют в Sheet.
- [ ] Все локали заполнены.
- [ ] `description` объясняет контекст.
- [ ] Placeholders совпадают.
- [ ] Plural-категории корректны.
- [ ] Generated-файлы не редактировались вручную.
- [ ] `ARB consistency` зелёный.
- [ ] `Plural forms` зелёный.
- [ ] `Flutter checks` зелёный.
- [ ] В PR нет credentials и tokens.

## 20. Чек-лист публикации

- [ ] Переводы подтверждены переводчиками.
- [ ] `Publish localizations / Generate and validate` зелёный.
- [ ] `localization.diff` проверен.
- [ ] Нет неожиданных удалений ключей.
- [ ] Указана правильная `release_version`.
- [ ] Сначала выбран `staging`.
- [ ] Staging patch проверен на устройстве.
- [ ] После проверки patch переведён в stable.
