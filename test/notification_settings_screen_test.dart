import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ninho/data/repositories/notifications_repository.dart';
import 'package:ninho/ui/core/theme.dart';
import 'package:ninho/ui/features/notifications/notification_settings_screen.dart';

class _FakeRepo extends NotificationsRepository {
  _FakeRepo({this.loadError});
  Object? loadError;
  NotificationPreferences? lastSaved;
  int saveCount = 0;

  @override
  Future<NotificationPreferences> fetchPreferences() async {
    if (loadError != null) throw loadError!;
    return NotificationPreferences.fromJson({
          'push_enabled': true,
          'morning_time': '09:00:00',
          'afternoon_time': '15:00:00',
          'evening_time': '20:00:00',
          'event_task_transferred': true,
          'event_new_member': true,
          'event_feed_photo': true,
          'event_streak_risk': true,
          'event_streak_broken': true,
          'event_shop_purchase': true,
        });
  }

  @override
  Future<void> updatePreferences(NotificationPreferences prefs) async {
    saveCount++;
    lastSaved = prefs;
  }
}

void _setMobile(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(NotificationSettingsScreen screen) {
  final router = GoRouter(
    initialLocation: '/test',
    routes: [
      GoRoute(path: '/test', builder: (_, _) => screen),
    ],
  );
  return MaterialApp.router(theme: NinhoTheme.light(), routerConfig: router);
}

void main() {
  testWidgets('renders defaults from repo', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(NotificationSettingsScreen(repository: _FakeRepo())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notificações'), findsOneWidget);
    expect(find.text('09:00'), findsOneWidget);
    expect(find.text('15:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
  });

  testWidgets('master toggle desativa tudo e desabilita eventos', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _wrap(NotificationSettingsScreen(repository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('notif_toggle_master')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.saveCount, 1);
    expect(repo.lastSaved?.pushEnabled, false);

    // Switch de evento agora deve estar disabled (onChanged == null)
    final sw = tester.widget<Switch>(
      find.descendant(
        of: find.byKey(const Key('notif_event_task_transferred')),
        matching: find.byType(Switch),
      ),
    );
    expect(sw.onChanged, isNull);
  });

  testWidgets('toggle de evento persiste no repo', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _wrap(NotificationSettingsScreen(repository: repo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('notif_event_streak_broken')),
        matching: find.byType(Switch),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.saveCount, 1);
    expect(repo.lastSaved?.eventStreakBroken, false);
  });

  testWidgets('erro de load mostra mensagem', (tester) async {
    _setMobile(tester);
    await tester.pumpWidget(
      _wrap(
        NotificationSettingsScreen(
          repository: _FakeRepo(loadError: Exception('boom')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notif_settings_error')), findsOneWidget);
  });
}
