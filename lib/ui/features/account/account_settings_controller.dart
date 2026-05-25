import 'package:flutter/foundation.dart';

import '../../../data/repositories/users_repository.dart';

enum AccountSettingsStatus { idle, loading, ready, saving, error }

class AccountSettingsController extends ChangeNotifier {
  AccountSettingsController({UsersRepository? usersRepository})
    : _users = usersRepository ?? UsersRepository();

  final UsersRepository _users;

  AccountSettingsStatus _status = AccountSettingsStatus.idle;
  AccountSettingsStatus get status => _status;

  String? _error;
  String? get error => _error;

  UserProfileSnapshot? _profile;
  UserProfileSnapshot? get profile => _profile;

  String? _avatarSignedUrl;
  String? get avatarSignedUrl => _avatarSignedUrl;

  Future<void> load() async {
    _status = AccountSettingsStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _profile = await _users.fetchSelf();
      await _refreshAvatarUrl();
      _status = AccountSettingsStatus.ready;
    } catch (e) {
      _status = AccountSettingsStatus.error;
      _error = _humanize(e);
    } finally {
      notifyListeners();
    }
  }

  Future<bool> updateLocale(String locale) async {
    return _patch(() async {
      await _users.updateProfile(locale: locale);
      _profile = _profile?._copyWith(locale: locale);
    });
  }

  Future<bool> updateDisplayName(String name) async {
    return _patch(() async {
      await _users.updateProfile(displayName: name);
      _profile = _profile?._copyWith(displayName: name.trim());
    });
  }

  // Aceita bytes JPEG já preparados (EXIF strip + resize) pelo serviço de foto.
  Future<bool> uploadAvatar(Uint8List jpegBytes) async {
    return _patch(() async {
      final path = await _users.uploadAvatar(jpegBytes);
      _profile = _profile?._copyWith(avatarPath: path);
      await _refreshAvatarUrl();
    });
  }

  Future<bool> removeAvatar() async {
    return _patch(() async {
      await _users.removeAvatar();
      _profile = _profile?._copyWith(avatarPath: null);
      _avatarSignedUrl = null;
    });
  }

  Future<bool> _patch(Future<void> Function() op) async {
    _status = AccountSettingsStatus.saving;
    _error = null;
    notifyListeners();
    try {
      await op();
      _status = AccountSettingsStatus.ready;
      notifyListeners();
      return true;
    } catch (e) {
      _status = AccountSettingsStatus.error;
      _error = _humanize(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> _refreshAvatarUrl() async {
    final path = _profile?.avatarPath;
    if (path == null) {
      _avatarSignedUrl = null;
      return;
    }
    _avatarSignedUrl = await _users.signedAvatarUrl(path);
  }

  String _humanize(Object e) {
    if (e is StateError) return e.message;
    if (e is ArgumentError) return e.message?.toString() ?? 'Dado inválido.';
    final msg = e.toString();
    if (msg.contains('42501')) return 'Sem permissão.';
    if (msg.contains('storage')) return 'Falha no upload da imagem.';
    return 'Não foi possível atualizar agora.';
  }
}

extension on UserProfileSnapshot {
  UserProfileSnapshot _copyWith({
    String? displayName,
    String? locale,
    Object? avatarPath = _sentinel,
  }) {
    return UserProfileSnapshot(
      id: id,
      displayName: displayName ?? this.displayName,
      email: email,
      locale: locale ?? this.locale,
      avatarPath: identical(avatarPath, _sentinel)
          ? this.avatarPath
          : avatarPath as String?,
    );
  }
}

const Object _sentinel = Object();
