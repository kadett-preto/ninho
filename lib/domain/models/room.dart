import 'room_size.dart';
import 'room_photo_draft.dart';

const _keep = Object();

class Room {
  const Room({
    required this.name,
    required this.size,
    this.photoPath,
    this.photoDraft,
  });

  final String name;
  final RoomSize size;
  final String? photoPath;
  final RoomPhotoDraft? photoDraft;

  Room copyWith({
    String? name,
    RoomSize? size,
    Object? photoPath = _keep,
    Object? photoDraft = _keep,
  }) {
    return Room(
      name: name ?? this.name,
      size: size ?? this.size,
      photoPath: identical(photoPath, _keep)
          ? this.photoPath
          : photoPath as String?,
      photoDraft: identical(photoDraft, _keep)
          ? this.photoDraft
          : photoDraft as RoomPhotoDraft?,
    );
  }
}
