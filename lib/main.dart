import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'data/services/push_notifications_service.dart';
import 'data/services/sentry_service.dart';
import 'data/services/supabase_client.dart';
import 'ui/core/app.dart';

Future<void> main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load();
      await SupabaseService.init();
      // Push: no-op silencioso enquanto google-services.json/APNs não
      // estão configurados. Falha sem quebrar o app (Fase 8.1).
      await PushNotificationsService.initialize();
      await SentryService.init(appRunner: () async => runApp(const NinhoApp()));
    },
    (error, stackTrace) async {
      await Sentry.captureException(error, stackTrace: stackTrace);
    },
  );
}
