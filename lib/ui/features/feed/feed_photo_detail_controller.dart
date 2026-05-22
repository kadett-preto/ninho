import 'package:flutter/foundation.dart';

import '../../../data/repositories/feed_repository.dart';

enum FeedPhotoDetailStatus { idle, loading, ready, error }

class FeedPhotoDetailController extends ChangeNotifier {
  FeedPhotoDetailController({required this.eventId, FeedRepository? repository})
    : _repository = repository ?? const FeedRepository();

  final String eventId;
  final FeedRepository _repository;

  FeedPhotoDetailStatus _status = FeedPhotoDetailStatus.idle;
  FeedPhotoDetailStatus get status => _status;

  FeedPhotoDetail? _detail;
  FeedPhotoDetail? get detail => _detail;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _status = FeedPhotoDetailStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _detail = await _repository.fetchPhotoDetail(eventId: eventId);
      _status = FeedPhotoDetailStatus.ready;
    } catch (_) {
      _status = FeedPhotoDetailStatus.error;
      _error = 'Não foi possível abrir esta foto do mural.';
    } finally {
      notifyListeners();
    }
  }
}
