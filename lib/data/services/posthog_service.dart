import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

// Analytics + feature flags (IDEA.md §6.5).
//
// Conformidade LGPD (§3.10, §5.10): PostHog NÃO é inicializado no boot.
// `setupIfConsented` deve ser chamado apenas após o usuário aceitar o
// consentimento explícito no onboarding (Fase 2).
//
// Configuração defensiva:
//  - sem session replay (privacidade + custo)
//  - sem autocapture (evita coletar inputs de texto com PII)
//  - sem captura de lifecycle por padrão (Posthog não decide eventos sozinho)
//  - person profiles 'identifiedOnly' (não cria perfil pra anônimo)
//
// Próximo passo (Fase 2):
//  1. Após o usuário marcar "aceito" no consentimento LGPD, persistir flag e
//     chamar `PosthogService.setupIfConsented(consented: true)`.
//  2. Adicionar `<meta-data android:name="com.posthog.posthog.AUTO_INIT"
//     android:value="false" />` ao AndroidManifest.xml e o equivalente no
//     Info.plist (PHGAutoInit = false) para garantir que o SDK nativo
//     não auto-inicialize antes do consentimento.
class PosthogService {
  PosthogService._();

  static bool _initialized = false;

  static Future<void> setupIfConsented({required bool consented}) async {
    if (!consented || _initialized) return;

    final apiKey = dotenv.env['POSTHOG_API_KEY'];
    final host = dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';

    if (apiKey == null || apiKey.isEmpty) return;

    final config = PostHogConfig(apiKey)
      ..host = host
      ..debug = kDebugMode
      ..captureApplicationLifecycleEvents = false
      ..sessionReplay = false
      ..personProfiles = PostHogPersonProfiles.identifiedOnly;

    await Posthog().setup(config);
    _initialized = true;
  }

  // Chamar quando usuário revogar consentimento ou deletar conta (§5.10).
  static Future<void> optOutAndReset() async {
    if (!_initialized) return;
    await Posthog().disable();
    await Posthog().reset();
    _initialized = false;
  }
}
