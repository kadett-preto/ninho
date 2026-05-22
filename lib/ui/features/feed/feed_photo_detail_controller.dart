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

  bool _actionBusy = false;
  bool get actionBusy => _actionBusy;

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

  Future<bool> report() {
    return _runAction(
      () => _repository.reportFeedEvent(eventId: eventId),
      fallback: 'Não foi possível registrar a denúncia.',
    );
  }

  Future<bool> deleteOwnPhoto() {
    return _runAction(
      () => _repository.moderateFeedEvent(
        eventId: eventId,
        action: FeedModerationAction.deletePhoto,
        reason: 'author_deleted_photo',
      ),
      fallback: 'Não foi possível remover esta foto.',
    );
  }

  Future<bool> hide() {
    return _runAction(
      () => _repository.moderateFeedEvent(
        eventId: eventId,
        action: FeedModerationAction.hide,
        reason: 'owner_hidden',
      ),
      fallback: 'Não foi possível ocultar este item.',
    );
  }

  Future<bool> delete() {
    return _runAction(
      () => _repository.moderateFeedEvent(
        eventId: eventId,
        action: FeedModerationAction.delete,
        reason: 'owner_deleted',
      ),
      fallback: 'Não foi possível deletar este item.',
    );
  }

  Future<bool> _runAction(
    Future<void> Function() action, {
    required String fallback,
  }) async {
    if (_actionBusy) return false;
    _actionBusy = true;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (_) {
      _error = fallback;
      return false;
    } finally {
      _actionBusy = false;
      notifyListeners();
    }
  }
}
