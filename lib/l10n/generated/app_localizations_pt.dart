// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppL10nPt extends AppL10n {
  AppL10nPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Ninho';

  @override
  String get navHome => 'Início';

  @override
  String get navTasks => 'Tarefas';

  @override
  String get navFeed => 'Mural';

  @override
  String get navShop => 'Loja';

  @override
  String get navProfile => 'Perfil';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonSave => 'Salvar';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonRetry => 'Tentar de novo';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonSkip => 'Pular';

  @override
  String get commonShare => 'Compartilhar';

  @override
  String get commonComingSoon => 'Em breve.';

  @override
  String get splashTitle => 'Bem-vindo ao Ninho';

  @override
  String get splashSubtitle => 'Divisão de tarefas que cuida do lar.';

  @override
  String get loginGoogle => 'Entrar com Google';

  @override
  String get loginApple => 'Entrar com Apple';

  @override
  String get loginTermsAndPrivacy =>
      'Ao entrar você aceita nossos termos e a política de privacidade.';

  @override
  String get difficultyEasy => 'mamão';

  @override
  String get difficultyMedium => 'embaçada';

  @override
  String get difficultyHard => 'treta';

  @override
  String get roomSizeSmall => 'Pequeno';

  @override
  String get roomSizeMedium => 'Médio';

  @override
  String get roomSizeLarge => 'Grande';

  @override
  String get errorSessionExpired => 'Sessão expirada. Faça login de novo.';

  @override
  String get errorNoPermission => 'Sem permissão para essa ação.';

  @override
  String get errorGeneric =>
      'Não conseguimos completar agora. Tente outra vez.';
}
