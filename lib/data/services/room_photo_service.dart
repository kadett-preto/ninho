import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:image_picker/image_picker.dart';

import '../../domain/models/room_photo_draft.dart';

enum RoomPhotoSource { camera, gallery }

abstract class RoomPhotoService {
  Future<RoomPhotoDraft?> pickAndPrepare(RoomPhotoSource source);
}

class RoomPhotoValidationException implements Exception {
  const RoomPhotoValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ImagePickerRoomPhotoService implements RoomPhotoService {
  ImagePickerRoomPhotoService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const maxOriginalBytes = 8 * 1024 * 1024;
  static const maxPixels = 25 * 1000 * 1000;
  static const maxSide = 1600;

  final ImagePicker _picker;

  @override
  Future<RoomPhotoDraft?> pickAndPrepare(RoomPhotoSource source) async {
    final file = await _picker.pickImage(
      source: switch (source) {
        RoomPhotoSource.camera => ImageSource.camera,
        RoomPhotoSource.gallery => ImageSource.gallery,
      },
      maxWidth: maxSide.toDouble(),
      maxHeight: maxSide.toDouble(),
      imageQuality: 88,
      requestFullMetadata: false,
    );
    if (file == null) return null;

    final extension = _extensionFromName(file.name);
    if (extension != 'jpg' && extension != 'jpeg' && extension != 'png') {
      throw const RoomPhotoValidationException('Use uma foto em JPG ou PNG.');
    }

    final originalBytes = await file.readAsBytes();
    if (originalBytes.length > maxOriginalBytes) {
      throw const RoomPhotoValidationException('A foto precisa ter até 8 MB.');
    }

    final decoded = image_lib.decodeImage(originalBytes);
    if (decoded == null) {
      throw const RoomPhotoValidationException(
        'Não foi possível ler essa imagem.',
      );
    }
    if (decoded.width * decoded.height > maxPixels) {
      throw const RoomPhotoValidationException(
        'A foto é grande demais. Escolha uma imagem menor.',
      );
    }

    final oriented = image_lib.bakeOrientation(decoded);
    final resized = _resizeIfNeeded(oriented);
    final strippedBytes = Uint8List.fromList(
      image_lib.encodeJpg(resized, quality: 86),
    );

    return RoomPhotoDraft(
      bytes: strippedBytes,
      contentType: 'image/jpeg',
      extension: 'jpg',
    );
  }

  String _extensionFromName(String name) {
    final lastDot = name.lastIndexOf('.');
    if (lastDot == -1) return '';
    return name.substring(lastDot + 1).toLowerCase();
  }

  image_lib.Image _resizeIfNeeded(image_lib.Image source) {
    final largestSide = source.width > source.height
        ? source.width
        : source.height;
    if (largestSide <= maxSide) return source;
    if (source.width >= source.height) {
      return image_lib.copyResize(source, width: maxSide);
    }
    return image_lib.copyResize(source, height: maxSide);
  }
}
