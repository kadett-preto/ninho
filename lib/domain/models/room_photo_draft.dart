import 'dart:typed_data';

class RoomPhotoDraft {
  const RoomPhotoDraft({
    required this.bytes,
    required this.contentType,
    required this.extension,
  });

  final Uint8List bytes;
  final String contentType;
  final String extension;
}
