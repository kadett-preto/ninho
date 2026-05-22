import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/data/services/room_photo_service.dart';
import 'package:ninho/domain/models/room.dart';
import 'package:ninho/domain/models/room_photo_draft.dart';
import 'package:ninho/domain/models/room_size.dart';
import 'package:ninho/ui/features/setup/setup_controller.dart';

class _FakeRoomPhotoService implements RoomPhotoService {
  _FakeRoomPhotoService({this.draft, this.error});

  final RoomPhotoDraft? draft;
  final Object? error;

  @override
  Future<RoomPhotoDraft?> pickAndPrepare(RoomPhotoSource source) async {
    if (error != null) throw error!;
    return draft;
  }
}

void main() {
  group('SetupController', () {
    test('starts with default room catalog', () {
      final c = SetupController();
      expect(c.rooms.length, greaterThanOrEqualTo(4));
      expect(c.canAdvanceFromStep1, isFalse);
      expect(c.canAdvanceFromStep2, isTrue);
    });

    test('setName toggles step1 advance', () {
      final c = SetupController();
      c.setName('Nosso apê');
      expect(c.canAdvanceFromStep1, isTrue);
    });

    test('toggleRoom removes preset by name', () {
      final c = SetupController();
      final preset = c.rooms.first;
      c.toggleRoom(preset);
      expect(c.rooms.any((r) => r.name == preset.name), isFalse);
    });

    test('setRoomSize muda apenas o cômodo alvo', () {
      final c = SetupController();
      final target = c.rooms.first;
      c.setRoomSize(target.name, RoomSize.g);
      final updated = c.rooms.firstWhere((r) => r.name == target.name);
      expect(updated.size, RoomSize.g);
    });

    test('addCustomRoom ignora duplicados case-insensitive', () {
      final c = SetupController();
      c.addCustomRoom('Sala', RoomSize.g);
      final salaCount = c.rooms.where((r) => r.name == 'Sala').length;
      expect(salaCount, 1);
    });

    test('addCustomRoom adiciona novo cômodo', () {
      final c = SetupController();
      c.addCustomRoom('Quintal', RoomSize.m);
      expect(c.rooms.any((r) => r.name == 'Quintal'), isTrue);
    });

    test('removeRoom apaga por nome', () {
      final c = SetupController();
      c.addCustomRoom('Quintal', RoomSize.m);
      c.removeRoom('Quintal');
      expect(c.rooms.any((r) => r.name == 'Quintal'), isFalse);
    });

    test('Room.copyWith mantém imutabilidade', () {
      const r = Room(name: 'A', size: RoomSize.p);
      final r2 = r.copyWith(size: RoomSize.g);
      expect(r.size, RoomSize.p);
      expect(r2.size, RoomSize.g);
    });

    test('pickRoomPhoto anexa draft ao cômodo existente', () async {
      final draft = RoomPhotoDraft(
        bytes: Uint8List.fromList([1, 2, 3]),
        contentType: 'image/jpeg',
        extension: 'jpg',
      );
      final c = SetupController(
        photoService: _FakeRoomPhotoService(draft: draft),
      );

      final ok = await c.pickRoomPhoto('Sala', RoomPhotoSource.gallery);

      expect(ok, isTrue);
      expect(c.rooms.firstWhere((r) => r.name == 'Sala').photoDraft, draft);
      expect(c.lastError, isNull);
    });

    test('pickRoomPhoto registra erro de validação', () async {
      final c = SetupController(
        photoService: _FakeRoomPhotoService(
          error: const RoomPhotoValidationException('Foto inválida'),
        ),
      );

      final ok = await c.pickRoomPhoto('Sala', RoomPhotoSource.gallery);

      expect(ok, isFalse);
      expect(c.lastError, 'Foto inválida');
    });

    test('removeRoomPhoto limpa draft sem remover cômodo', () async {
      final draft = RoomPhotoDraft(
        bytes: Uint8List.fromList([1]),
        contentType: 'image/jpeg',
        extension: 'jpg',
      );
      final c = SetupController(
        photoService: _FakeRoomPhotoService(draft: draft),
      );
      await c.pickRoomPhoto('Sala', RoomPhotoSource.gallery);

      c.removeRoomPhoto('Sala');

      final room = c.rooms.firstWhere((r) => r.name == 'Sala');
      expect(room.photoDraft, isNull);
    });
  });
}
