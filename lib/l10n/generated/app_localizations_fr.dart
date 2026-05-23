// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppL10nFr extends AppL10n {
  AppL10nFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Ninho';

  @override
  String get navHome => 'Accueil';

  @override
  String get navTasks => 'Tâches';

  @override
  String get navFeed => 'Mur';

  @override
  String get navShop => 'Boutique';

  @override
  String get navProfile => 'Profil';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonSkip => 'Passer';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonComingSoon => 'Bientôt disponible.';

  @override
  String get splashTitle => 'Bienvenue sur Ninho';

  @override
  String get splashSubtitle => 'Partage des tâches qui prend soin du foyer.';

  @override
  String get loginGoogle => 'Se connecter avec Google';

  @override
  String get loginApple => 'Se connecter avec Apple';

  @override
  String get loginTermsAndPrivacy =>
      'En vous connectant, vous acceptez nos conditions et notre politique de confidentialité.';

  @override
  String get difficultyEasy => 'facile';

  @override
  String get difficultyMedium => 'moyen';

  @override
  String get difficultyHard => 'lourd';

  @override
  String get roomSizeSmall => 'Petit';

  @override
  String get roomSizeMedium => 'Moyen';

  @override
  String get roomSizeLarge => 'Grand';

  @override
  String get errorSessionExpired =>
      'Session expirée. Veuillez vous reconnecter.';

  @override
  String get errorNoPermission => 'Permission refusée.';

  @override
  String get errorGeneric => 'Impossible de terminer maintenant. Réessayez.';
}
