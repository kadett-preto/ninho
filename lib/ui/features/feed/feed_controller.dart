import 'package:flutter/foundation.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/feed_repository.dart';

enum FeedStatus { idle, loading, ready, error }

class FeedController extends ChangeNotifier {
  FeedController({
    EnvironmentsRepository? environmentsRepository,
    FeedRepository? repository,
  }) : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
       _repository = repository ?? const FeedRepository();

  final EnvironmentsRepository _envRepo;
  final FeedRepository _repository;

  FeedStatus _status = FeedStatus.idle;
  FeedStatus get status => _status;

  String? _error;
  String? get error => _error;

  String _environmentName = 'Seu ninho';
  String get environmentName => _environmentName;

  List<FeedTimelineItem> _items = const [];
  List<FeedTimelineItem> get items => _items;

  Future<void> load() async {
    _status = FeedStatus.loading;
    _error = null;
    notifyListeners();
    try {
      final envId = await _envRepo.fetchCurrentEnvironmentId();
      if (envId == null) {
        throw StateError('Você precisa cadastrar um ninho primeiro.');
      }
      _environmentName = await _repository.fetchEnvironmentName(
        environmentId: envId,
      );
      _items = await _repository.fetchTimeline(environmentId: envId);
      _status = FeedStatus.ready;
    } catch (_) {
      _status = FeedStatus.error;
      _error = 'Não foi possível carregar o mural agora.';
    } finally {
      notifyListeners();
    }
  }
}
