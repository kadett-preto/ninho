// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppL10nEs extends AppL10n {
  AppL10nEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Ninho';

  @override
  String get navHome => 'Inicio';

  @override
  String get navTasks => 'Tareas';

  @override
  String get navFeed => 'Muro';

  @override
  String get navShop => 'Tienda';

  @override
  String get navProfile => 'Perfil';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonSkip => 'Saltar';

  @override
  String get commonShare => 'Compartir';

  @override
  String get commonComingSoon => 'Próximamente.';

  @override
  String get splashTitle => 'Bienvenido a Ninho';

  @override
  String get splashSubtitle => 'Reparto de tareas que cuida del hogar.';

  @override
  String get loginGoogle => 'Entrar con Google';

  @override
  String get loginApple => 'Entrar con Apple';

  @override
  String get loginTermsAndPrivacy =>
      'Al entrar aceptas nuestros términos y política de privacidad.';

  @override
  String get difficultyEasy => 'fácil';

  @override
  String get difficultyMedium => 'regular';

  @override
  String get difficultyHard => 'pesado';

  @override
  String get roomSizeSmall => 'Pequeño';

  @override
  String get roomSizeMedium => 'Mediano';

  @override
  String get roomSizeLarge => 'Grande';

  @override
  String get errorSessionExpired => 'Sesión expirada. Inicia sesión de nuevo.';

  @override
  String get errorNoPermission => 'Sin permiso para esa acción.';

  @override
  String get errorGeneric => 'No pudimos completar ahora. Inténtalo de nuevo.';
}
