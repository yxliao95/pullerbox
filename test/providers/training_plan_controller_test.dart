import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pullerbox/src/models/training_plan.dart';
import 'package:pullerbox/src/providers/training_plan_controller.dart';

void main() {
  const defaultName = '默认';
  const defaultWork = 7;
  const defaultRest = 3;
  const defaultCycles = 20;

  test('TrainingPlanController initializes with defaults', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(trainingPlanProvider);

    expect(state.name, defaultName);
    expect(state.workSeconds, defaultWork);
    expect(state.restSeconds, defaultRest);
    expect(state.cycles, defaultCycles);
  });

  test('TrainingPlanController updates fields with actions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(trainingPlanProvider.notifier);

    notifier.updateName('Plan B');
    notifier.incrementWork();
    notifier.decrementRest();
    notifier.incrementCycles();

    final state = container.read(trainingPlanProvider);

    expect(state.name, 'Plan B');
    expect(state.workSeconds, defaultWork + 1);
    expect(state.restSeconds, defaultRest - 1);
    expect(state.cycles, defaultCycles + 1);
  });

  test('TrainingPlanController clamps values at zero', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(trainingPlanProvider.notifier);

    notifier.decrementWork();
    notifier.decrementRest();
    notifier.decrementCycles();

    final state = container.read(trainingPlanProvider);

    expect(state.workSeconds, defaultWork - 1);
    expect(state.restSeconds, defaultRest - 1);
    expect(state.cycles, defaultCycles - 1);

    const extraDecrements = 10;
    for (var i = 0; i < extraDecrements; i++) {
      notifier.decrementRest();
    }

    expect(container.read(trainingPlanProvider).restSeconds, 0);
  });

  test('TrainingPlanController applyPlan replaces state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(trainingPlanProvider.notifier);
    const plan = TrainingPlanState(name: 'Plan C', workSeconds: 5, restSeconds: 1, cycles: 3);

    notifier.applyPlan(plan);

    expect(container.read(trainingPlanProvider).name, 'Plan C');
    expect(container.read(trainingPlanProvider).workSeconds, 5);
    expect(container.read(trainingPlanProvider).restSeconds, 1);
    expect(container.read(trainingPlanProvider).cycles, 3);
  });
}
