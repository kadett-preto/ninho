import 'room_size.dart';

class Room {
  const Room({required this.name, required this.size, this.photoPath});

  final String name;
  final RoomSize size;
  final String? photoPath;

  Room copyWith({String? name, RoomSize? size, String? photoPath}) {
    return Room(
      name: name ?? this.name,
      size: size ?? this.size,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}
