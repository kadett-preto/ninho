import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/domain/models/room.dart';
import 'package:ninho/domain/models/room_size.dart';
import 'package:ninho/ui/features/setup/setup_controller.dart';

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
  });
}
