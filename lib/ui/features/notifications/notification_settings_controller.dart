import 'package:flutter/foundation.dart';

import '../../../data/repositories/notifications_repository.dart';

enum NotifSettingsStatus { idle, loading, ready, saving, error }

class NotificationSettingsController extends ChangeNotifier {
  NotificationSettingsController({NotificationsRepository? repository})
    : _repo = repository ?? const NotificationsRepository();

  final NotificationsRepository _repo;

  NotifSettingsStatus _status = NotifSettingsStatus.idle;
  NotifSettingsStatus get status => _status;

  String? _error;
  String? get error => _error;

  NotificationPreferences? _prefs;
  NotificationPreferences? get prefs => _prefs;

  Future<void> load() async {
    _status = NotifSettingsStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _prefs = await _repo.fetchPreferences();
      _status = NotifSettingsStatus.ready;
    } catch (e) {
      _status = NotifSettingsStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> _patch(
    NotificationPreferences Function(NotificationPreferences) mutator,
  ) async {
    final cur = _prefs;
    if (cur == null) return;
    final next = mutator(cur);
    _prefs = next;
    notifyListeners();
    _status = NotifSettingsStatus.saving;
    try {
      await _repo.updatePreferences(next);
      _status = NotifSettingsStatus.ready;
    } catch (e) {
      _prefs = cur;
      _status = NotifSettingsStatus.error;
      _error = _humanize(e);
    }
    notifyListeners();
  }

  Future<void> togglePushEnabled(bool value) =>
      _patch((p) => p.copyWith(pushEnabled: value));

  Future<void> setMorning(int minutes) =>
      _patch((p) => p.copyWith(morningTime: minutes));

  Future<void> setAfternoon(int minutes) =>
      _patch((p) => p.copyWith(afternoonTime: minutes));

  Future<void> setEvening(int minutes) =>
      _patch((p) => p.copyWith(eveningTime: minutes));

  Future<void> toggleEvent({
    bool? taskTransferred,
    bool? newMember,
    bool? feedPhoto,
    bool? streakRisk,
    bool? streakBroken,
    bool? shopPurchase,
  }) => _patch(
    (p) => p.copyWith(
      eventTaskTransferred: taskTransferred,
      eventNewMember: newMember,
      eventFeedPhoto: feedPhoto,
      eventStreakRisk: streakRisk,
      eventStreakBroken: streakBroken,
      eventShopPurchase: shopPurchase,
    ),
  );

  String _humanize(Object e) {
    if (e is StateError) return e.message;
    final msg = e.toString();
    if (msg.contains('42501')) return 'Sem permissão.';
    return 'Não foi possível atualizar agora.';
  }
}
