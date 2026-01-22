import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pullerbox/src/models/training_plan.dart';
import 'package:pullerbox/src/providers/training_monitor_controller.dart';
import 'package:pullerbox/src/providers/training_monitor_state.dart';

void main() {
  const plan = TrainingPlanState(name: 'Plan', workSeconds: 1, restSeconds: 0, cycles: 1);
  const prepareDuration = Duration(seconds: 3);
  const workDuration = Duration(seconds: 1);
  const sampleInterval = Duration(milliseconds: 50);

  TrainingMonitorConfig buildConfig() {
    return const TrainingMonitorConfig(
      plan: plan,
      isDeviceConnected: false,
      isFreeTraining: false,
    );
  }

  test('TrainingMonitorController runs prepare -> running -> finished flow', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = buildConfig();
      final subscription = container.listen(
        trainingMonitorControllerProvider(config),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      var state = subscription.read();

      expect(state.isPreparing, isTrue);
      expect(state.isWorking, isTrue);
      expect(state.isFinishPending, isFalse);

      async.elapse(prepareDuration + sampleInterval);
      state = subscription.read();
      expect(state.isPreparing, isFalse);
      expect(state.isWorking, isTrue);

      async.elapse(workDuration + sampleInterval);
      state = subscription.read();
      expect(state.isFinishPending, isTrue);
      expect(state.summary, isNotNull);
    });
  });

  test('TrainingMonitorController ignores ticks while paused', () {
    fakeAsync((async) {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final config = buildConfig();
      final subscription = container.listen(
        trainingMonitorControllerProvider(config),
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      final notifier = container.read(trainingMonitorControllerProvider(config).notifier);
      notifier.togglePause();

      final paused = subscription.read();
      final elapsedBefore = paused.elapsedInPhase;

      async.elapse(const Duration(seconds: 1));
      final pausedAfter = subscription.read();
      expect(pausedAfter.elapsedInPhase, elapsedBefore);
    });
  });
}
