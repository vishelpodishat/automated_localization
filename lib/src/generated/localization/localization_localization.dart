// This file is generated, do not edit it manually!
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'localization_localization_en.dart';
import 'localization_localization_kk.dart';
import 'localization_localization_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of LocalizationLocalization
/// returned by `LocalizationLocalization.of(context)`.
///
/// Applications need to include `LocalizationLocalization.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'localization/localization_localization.dart';
///
/// return MaterialApp(
///   localizationsDelegates: LocalizationLocalization.localizationsDelegates,
///   supportedLocales: LocalizationLocalization.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the LocalizationLocalization.supportedLocales
/// property.
abstract class LocalizationLocalization {
  LocalizationLocalization(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static LocalizationLocalization of(BuildContext context) {
    return Localizations.of<LocalizationLocalization>(
      context,
      LocalizationLocalization,
    )!;
  }

  static const LocalizationsDelegate<LocalizationLocalization> delegate =
      _LocalizationLocalizationDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
  ];

  /// Приветствие на главном экране
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcomeMessage;

  /// тест на юзера
  ///
  /// In en, this message translates to:
  /// **'User one'**
  String get user;

  /// новый
  ///
  /// In en, this message translates to:
  /// **'Protection'**
  String get newChanges;

  /// No description provided for @changes.
  ///
  /// In en, this message translates to:
  /// **'changes'**
  String get changes;
}

class _LocalizationLocalizationDelegate
    extends LocalizationsDelegate<LocalizationLocalization> {
  const _LocalizationLocalizationDelegate();

  @override
  Future<LocalizationLocalization> load(Locale locale) {
    return SynchronousFuture<LocalizationLocalization>(
      lookupLocalizationLocalization(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_LocalizationLocalizationDelegate old) => false;
}

LocalizationLocalization lookupLocalizationLocalization(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return LocalizationLocalizationEn();
    case 'kk':
      return LocalizationLocalizationKk();
    case 'ru':
      return LocalizationLocalizationRu();
  }

  throw FlutterError(
    'LocalizationLocalization.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
