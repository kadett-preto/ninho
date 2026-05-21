import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Configuração de observabilidade (IDEA.md §6.5 e §7.5).
//
// Política de PII: nunca enviar e-mail, nome, IP ou username de usuário para o
// Sentry. `sendDefaultPii = false` cobre IP/cookies; `beforeSend` anula
// quaisquer campos de identificação que terceiros possam ter populado.
class SentryService {
  SentryService._();

  static Future<void> init({required Future<void> Function() appRunner}) async {
    final dsn = dotenv.env['SENTRY_DSN'];
    final env = dotenv.env['SENTRY_ENV'] ?? 'dev';

    if (dsn == null || dsn.isEmpty) {
      // Sem DSN, segue direto sem Sentry (ex.: tests, dev sem rede).
      await appRunner();
      return;
    }

    await SentryFlutter.init((options) {
      options.dsn = dsn;
      options.environment = env;
      options.tracesSampleRate = 0.2;
      options.sendDefaultPii = false;
      options.debug = kDebugMode;
      options.beforeSend = _scrubPii;
    }, appRunner: appRunner);
  }

  static SentryEvent? _scrubPii(SentryEvent event, Hint hint) {
    final user = event.user;
    if (user == null) return event;

    user.email = null;
    user.ipAddress = null;
    user.name = null;
    user.username = null;
    return event;
  }
}
