import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/data/repositories/environments_repository.dart';
import 'package:ninho/data/repositories/feed_repository.dart';
import 'package:ninho/data/repositories/suggestions_repository.dart'
    show TaskDifficulty;
import 'package:ninho/ui/features/feed/feed_controller.dart';

class _FakeEnvRepo extends EnvironmentsRepository {
  @override
  Future<String?> fetchCurrentEnvironmentId() async => 'env-1';
}

class _FakeFeedRepo extends FeedRepository {
  List<FeedTimelineItem> nextItems = [_item('initial')];
  int fetchTimelineCalls = 0;

  @override
  Future<String> fetchEnvironmentName({required String environmentId}) async {
    return 'Ninho teste';
  }

  @override
  Future<List<FeedTimelineItem>> fetchTimeline({
    required String environmentId,
    int limit = 30,
  }) async {
    fetchTimelineCalls++;
    return nextItems;
  }
}

FeedTimelineItem _item(String id) {
  return FeedTimelineItem(
    id: id,
    eventType: 'task.completed',
    actorId: 'user-1',
    actorLabel: 'Marina',
    createdAt: DateTime(2026, 5, 22, 10, 30),
    title: id,
    caption: 'ok',
    difficulty: TaskDifficulty.mamao,
    photoUrl: null,
    heartCount: 0,
    celebrationCount: 0,
    summary: null,
    memberName: null,
    streakCount: null,
  );
}

void main() {
  test('refreshFromRealtime recarrega timeline carregada', () async {
    final repo = _FakeFeedRepo();
    final controller = FeedController(
      environmentsRepository: _FakeEnvRepo(),
      repository: repo,
      realtimeEnabled: false,
    );

    await controller.load();
    expect(controller.status, FeedStatus.ready);
    expect(controller.items.single.id, 'initial');

    repo.nextItems = [_item('updated')];
    await controller.refreshFromRealtime();

    expect(repo.fetchTimelineCalls, 2);
    expect(controller.items.single.id, 'updated');
  });
}
