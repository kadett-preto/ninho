import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/services/room_photo_service.dart';
import '../../../domain/models/room.dart';
import '../../../domain/models/room_size.dart';

// Estado do wizard de cadastro de ninho (3 passos). Vive durante a navegação
// entre as telas /setup/step1/2/3, fornecido por ShellRoute via Provider.
class SetupController extends ChangeNotifier {
  SetupController({
    EnvironmentsRepository? repo,
    RoomPhotoService? photoService,
  }) : _repo = repo ?? EnvironmentsRepository(),
       _photoService = photoService ?? ImagePickerRoomPhotoService();

  final EnvironmentsRepository _repo;
  final RoomPhotoService _photoService;

  String _name = '';
  List<Room> _rooms = List.of(DefaultRoomCatalog.presets);
  String _timezone = 'America/Sao_Paulo';
  bool _submitting = false;
  bool _pickingPhoto = false;
  String? _lastError;

  String get name => _name;
  List<Room> get rooms => List.unmodifiable(_rooms);
  String get timezone => _timezone;
  bool get submitting => _submitting;
  bool get pickingPhoto => _pickingPhoto;
  String? get lastError => _lastError;

  bool get canAdvanceFromStep1 => _name.trim().isNotEmpty;
  bool get canAdvanceFromStep2 => _rooms.isNotEmpty;

  void setName(String value) {
    _name = value;
    notifyListeners();
  }

  void toggleRoom(Room room) {
    final exists = _rooms.any((r) => r.name == room.name);
    if (exists) {
      _rooms = _rooms.where((r) => r.name != room.name).toList();
    } else {
      _rooms = [..._rooms, room];
    }
    notifyListeners();
  }

  void setRoomSize(String roomName, RoomSize size) {
    _rooms = _rooms
        .map((r) => r.name == roomName ? r.copyWith(size: size) : r)
        .toList();
    notifyListeners();
  }

  void addCustomRoom(String name, RoomSize size) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final duplicate = _rooms.any(
      (r) => r.name.toLowerCase() == trimmed.toLowerCase(),
    );
    if (duplicate) return;
    _rooms = [..._rooms, Room(name: trimmed, size: size)];
    notifyListeners();
  }

  void removeRoom(String name) {
    _rooms = _rooms.where((r) => r.name != name).toList();
    notifyListeners();
  }

  Future<bool> pickRoomPhoto(String roomName, RoomPhotoSource source) async {
    if (_pickingPhoto) return false;
    _pickingPhoto = true;
    _lastError = null;
    notifyListeners();

    try {
      final draft = await _photoService.pickAndPrepare(source);
      if (draft == null) return false;

      final roomIndex = _rooms.indexWhere((r) => r.name == roomName);
      if (roomIndex == -1) {
        _rooms = [
          ..._rooms,
          Room(name: roomName, size: RoomSize.m, photoDraft: draft),
        ];
      } else {
        _rooms = [
          for (final room in _rooms)
            if (room.name == roomName)
              room.copyWith(photoDraft: draft, photoPath: null)
            else
              room,
        ];
      }
      return true;
    } catch (e) {
      _lastError = e.toString();
      return false;
    } finally {
      _pickingPhoto = false;
      notifyListeners();
    }
  }

  void removeRoomPhoto(String roomName) {
    _rooms = _rooms
        .map((r) => r.name == roomName ? r.copyWith(photoDraft: null) : r)
        .toList();
    notifyListeners();
  }

  void setTimezone(String tz) {
    _timezone = tz;
    notifyListeners();
  }

  Future<String?> submit() async {
    if (_submitting) return null;
    _submitting = true;
    _lastError = null;
    notifyListeners();
    try {
      final id = await _repo.createEnvironment(
        name: _name.trim(),
        timezone: _timezone,
        rooms: _rooms,
      );
      return id;
    } catch (e) {
      _lastError = e.toString();
      return null;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
