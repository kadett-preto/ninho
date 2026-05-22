import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/repositories/environments_repository.dart';
import '../../../data/repositories/feed_repository.dart';

enum FeedStatus { idle, loading, ready, error }

class FeedController extends ChangeNotifier {
  FeedController({
    EnvironmentsRepository? environmentsRepository,
    FeedRepository? repository,
    this.realtimeEnabled = true,
  }) : _envRepo = environmentsRepository ?? EnvironmentsRepository(),
       _repository = repository ?? const FeedRepository();

  final EnvironmentsRepository _envRepo;
  final FeedRepository _repository;
  final bool realtimeEnabled;
  RealtimeChannel? _channel;
  String? _environmentId;
  bool _refreshing = false;
  bool _disposed = false;

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
      _environmentId = envId;
      _environmentName = await _repository.fetchEnvironmentName(
        environmentId: envId,
      );
      _items = await _repository.fetchTimeline(environmentId: envId);
      _subscribe(envId);
      _status = FeedStatus.ready;
    } catch (_) {
      _status = FeedStatus.error;
      _error = 'Não foi possível carregar o mural agora.';
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshFromRealtime() async {
    final envId = _environmentId;
    if (envId == null || _refreshing || _disposed) return;
    _refreshing = true;
    try {
      _items = await _repository.fetchTimeline(environmentId: envId);
      if (!_disposed) notifyListeners();
    } catch (_) {
      // Realtime é incremental; se o refresh falhar, a próxima mudança ou
      // reload manual recupera a lista sem derrubar a tela já carregada.
    } finally {
      _refreshing = false;
    }
  }

  void _subscribe(String environmentId) {
    if (!realtimeEnabled || _channel != null) return;
    _channel = _repository.watchTimeline(
      environmentId: environmentId,
      onChange: () {
        unawaited(refreshFromRealtime());
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _channel?.unsubscribe();
    super.dispose();
  }
}
