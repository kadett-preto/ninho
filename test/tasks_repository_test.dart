import 'package:flutter_test/flutter_test.dart';
import 'package:ninho/data/repositories/tasks_repository.dart';

void main() {
  test('CompleteTaskResult.fromJson parses RPC payload', () {
    final result = CompleteTaskResult.fromJson({
      'completion_id': 'aaaaaaaa-0000-0000-0000-000000000001',
      'already_completed': true,
      'reward_delta': 5,
      'notification_suppressed_count': 2,
      'feed_event_id': 'bbbbbbbb-0000-0000-0000-000000000001',
    });

    expect(result.completionId, 'aaaaaaaa-0000-0000-0000-000000000001');
    expect(result.alreadyCompleted, isTrue);
    expect(result.rewardDelta, 5);
    expect(result.notificationSuppressedCount, 2);
    expect(result.feedEventId, 'bbbbbbbb-0000-0000-0000-000000000001');
  });
}
