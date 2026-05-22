import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../repositories/notifications_repository.dart';
import 'supabase_client.dart';

// Wrapper de firebase_messaging + register/revoke do token no backend.
//
// IDEA.md §5.6 + §7.8:
//   - Token só é enviado via RPC SECURITY DEFINER (register_push_token).
//   - Logout revoga o token local (revoke_push_token) — Edge Functions
//     param de fanout filtram tokens revoked_at not null.
//   - Plataforma é inferida (android/ios/web). Não armazena PII no
//     deviceLabel — default null. Pode receber label opcional do usuário
//     no futuro (ex.: "Galaxy S24 da Marina").
class PushNotificationsService {
  PushNotificationsService._();

  static bool _initialized = false;
  static String? _currentToken;

  static String? get currentToken => _currentToken;
  static bool get isInitialized => _initialized;

  // Inicializa Firebase + escuta refresh de token. Idempotente.
  // Em ambiente sem google-services.json/GoogleService-Info.plist,
  // engole o erro e marca como não inicializado (não quebra o app).
  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      if (kDebugMode) {
        // Esperado em ambientes sem config — sinaliza no log mas não
        // propaga (Fase 8.1: aguardando google-services.json).
        debugPrint('PushNotificationsService init skipped: $e');
      }
      return;
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      _currentToken = newToken;
      // Só registra se já houver sessão. RPC exige authenticated.
      if (SupabaseService.client.auth.currentSession == null) return;
      try {
        await const NotificationsRepository().registerPushToken(
          token: newToken,
          platform: _platform(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('register on refresh failed: $e');
      }
    });
  }

  // Pede permissão (iOS) e registra o token atual no backend. Chamada
  // recomendada após login + aceite LGPD. Idempotente.
  static Future<void> requestPermissionAndRegister({
    String? deviceLabel,
  }) async {
    if (!_initialized) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.length < 32) return;
      _currentToken = token;
      await const NotificationsRepository().registerPushToken(
        token: token,
        platform: _platform(),
        deviceLabel: deviceLabel,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('requestPermissionAndRegister failed: $e');
    }
  }

  // Logout: revoga token corrente + dropa local. Não falha se já estiver
  // sem token (logout pode acontecer várias vezes).
  static Future<void> revokeCurrentToken() async {
    final token = _currentToken;
    if (token == null) return;
    try {
      await const NotificationsRepository().revokePushToken(token);
    } catch (e) {
      if (kDebugMode) debugPrint('revoke failed: $e');
    }
    _currentToken = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {
      // Sem Firebase config, deleteToken explode — ignoramos.
    }
  }

  static PushPlatform _platform() {
    if (kIsWeb) return PushPlatform.web;
    if (Platform.isAndroid) return PushPlatform.android;
    if (Platform.isIOS) return PushPlatform.ios;
    return PushPlatform.web;
  }
}
