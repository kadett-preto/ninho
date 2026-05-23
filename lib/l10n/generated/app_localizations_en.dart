// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Ninho';

  @override
  String get navHome => 'Home';

  @override
  String get navTasks => 'Tasks';

  @override
  String get navFeed => 'Wall';

  @override
  String get navShop => 'Shop';

  @override
  String get navProfile => 'Profile';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonShare => 'Share';

  @override
  String get commonComingSoon => 'Coming soon.';

  @override
  String get splashTitle => 'Welcome to Ninho';

  @override
  String get splashSubtitle => 'Chore sharing that takes care of your home.';

  @override
  String get loginGoogle => 'Sign in with Google';

  @override
  String get loginApple => 'Sign in with Apple';

  @override
  String get loginTermsAndPrivacy =>
      'By signing in you accept our terms and privacy policy.';

  @override
  String get difficultyEasy => 'easy';

  @override
  String get difficultyMedium => 'tricky';

  @override
  String get difficultyHard => 'heavy';

  @override
  String get roomSizeSmall => 'Small';

  @override
  String get roomSizeMedium => 'Medium';

  @override
  String get roomSizeLarge => 'Large';

  @override
  String get errorSessionExpired => 'Session expired. Please log in again.';

  @override
  String get errorNoPermission => 'You don\'t have permission for that.';

  @override
  String get errorGeneric => 'We couldn\'t finish that. Try again.';
}
