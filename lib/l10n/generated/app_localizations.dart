import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
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
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n? of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n);
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

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
    Locale('pt'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
  ];

  /// Nome do produto. Sempre 'Ninho' em qualquer locale.
  ///
  /// In pt, this message translates to:
  /// **'Ninho'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In pt, this message translates to:
  /// **'Início'**
  String get navHome;

  /// No description provided for @navTasks.
  ///
  /// In pt, this message translates to:
  /// **'Tarefas'**
  String get navTasks;

  /// No description provided for @navFeed.
  ///
  /// In pt, this message translates to:
  /// **'Mural'**
  String get navFeed;

  /// No description provided for @navShop.
  ///
  /// In pt, this message translates to:
  /// **'Loja'**
  String get navShop;

  /// No description provided for @navProfile.
  ///
  /// In pt, this message translates to:
  /// **'Perfil'**
  String get navProfile;

  /// No description provided for @commonCancel.
  ///
  /// In pt, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In pt, this message translates to:
  /// **'Salvar'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In pt, this message translates to:
  /// **'Excluir'**
  String get commonDelete;

  /// No description provided for @commonRetry.
  ///
  /// In pt, this message translates to:
  /// **'Tentar de novo'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In pt, this message translates to:
  /// **'Fechar'**
  String get commonClose;

  /// No description provided for @commonContinue.
  ///
  /// In pt, this message translates to:
  /// **'Continuar'**
  String get commonContinue;

  /// No description provided for @commonSkip.
  ///
  /// In pt, this message translates to:
  /// **'Pular'**
  String get commonSkip;

  /// No description provided for @commonShare.
  ///
  /// In pt, this message translates to:
  /// **'Compartilhar'**
  String get commonShare;

  /// No description provided for @commonComingSoon.
  ///
  /// In pt, this message translates to:
  /// **'Em breve.'**
  String get commonComingSoon;

  /// No description provided for @splashTitle.
  ///
  /// In pt, this message translates to:
  /// **'Bem-vindo ao Ninho'**
  String get splashTitle;

  /// No description provided for @splashSubtitle.
  ///
  /// In pt, this message translates to:
  /// **'Divisão de tarefas que cuida do lar.'**
  String get splashSubtitle;

  /// No description provided for @loginGoogle.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com Google'**
  String get loginGoogle;

  /// No description provided for @loginApple.
  ///
  /// In pt, this message translates to:
  /// **'Entrar com Apple'**
  String get loginApple;

  /// No description provided for @loginTermsAndPrivacy.
  ///
  /// In pt, this message translates to:
  /// **'Ao entrar você aceita nossos termos e a política de privacidade.'**
  String get loginTermsAndPrivacy;

  /// No description provided for @difficultyEasy.
  ///
  /// In pt, this message translates to:
  /// **'mamão'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In pt, this message translates to:
  /// **'embaçada'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In pt, this message translates to:
  /// **'treta'**
  String get difficultyHard;

  /// No description provided for @roomSizeSmall.
  ///
  /// In pt, this message translates to:
  /// **'Pequeno'**
  String get roomSizeSmall;

  /// No description provided for @roomSizeMedium.
  ///
  /// In pt, this message translates to:
  /// **'Médio'**
  String get roomSizeMedium;

  /// No description provided for @roomSizeLarge.
  ///
  /// In pt, this message translates to:
  /// **'Grande'**
  String get roomSizeLarge;

  /// No description provided for @errorSessionExpired.
  ///
  /// In pt, this message translates to:
  /// **'Sessão expirada. Faça login de novo.'**
  String get errorSessionExpired;

  /// No description provided for @errorNoPermission.
  ///
  /// In pt, this message translates to:
  /// **'Sem permissão para essa ação.'**
  String get errorNoPermission;

  /// No description provided for @errorGeneric.
  ///
  /// In pt, this message translates to:
  /// **'Não conseguimos completar agora. Tente outra vez.'**
  String get errorGeneric;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'es':
      return AppL10nEs();
    case 'fr':
      return AppL10nFr();
    case 'pt':
      return AppL10nPt();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
