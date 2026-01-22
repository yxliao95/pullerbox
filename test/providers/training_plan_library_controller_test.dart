import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pullerbox/src/models/training_plan.dart';
import 'package:pullerbox/src/providers/training_plan_controller.dart';
import 'package:pullerbox/src/providers/training_plan_library_controller.dart';

import '../helpers/fake_storages.dart';

void main() {
  const planA = TrainingPlanState(name: 'Plan A', workSeconds: 5, restSeconds: 2, cycles: 3);
  const planB = TrainingPlanState(name: 'Plan B', workSeconds: 8, restSeconds: 4, cycles: 2);

  test('TrainingPlanLibraryController restores snapshot and applies plan', () async {
    final storage = FakeTrainingPlanStorage(
      snapshot: const TrainingPlanLibrarySnapshot(
        plans: <TrainingPlanItem>[
          TrainingPlanItem(id: 'p1', plan: planA),
          TrainingPlanItem(id: 'p2', plan: planB),
        ],
        selectedPlanId: 'p2',
        isFreeTraining: false,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        trainingPlanStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final libraryState = container.read(trainingPlanLibraryProvider);
    expect(libraryState.selectedPlanId, 'default');

    await Future<void>.microtask(() {});

    final updatedLibrary = container.read(trainingPlanLibraryProvider);
    final planState = container.read(trainingPlanProvider);
    expect(updatedLibrary.selectedPlanId, 'p2');
    expect(updatedLibrary.plans.length, 2);
    expect(planState.name, planB.name);
    expect(planState.workSeconds, planB.workSeconds);
  });

  test('TrainingPlanLibraryController addPlan updates selection and persists', () {
    final storage = FakeTrainingPlanStorage();
    final container = ProviderContainer(
      overrides: [
        trainingPlanStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(trainingPlanLibraryProvider.notifier);

    final newPlanId = notifier.addPlan();

    final state = container.read(trainingPlanLibraryProvider);
    expect(state.selectedPlanId, newPlanId);
    expect(state.plans.any((plan) => plan.id == newPlanId), isTrue);
    expect(storage.savedSnapshot, isNotNull);
  });

  test('TrainingPlanLibraryController deleteSelected keeps at least one plan', () {
    final storage = FakeTrainingPlanStorage();
    final container = ProviderContainer(
      overrides: [
        trainingPlanStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(trainingPlanLibraryProvider.notifier);

    notifier.toggleEditing();
    notifier.selectAll();
    final removedAll = notifier.deleteSelected();

    final state = container.read(trainingPlanLibraryProvider);
    expect(removedAll, isTrue);
    expect(state.plans.length, 1);
    expect(state.selectedPlanId, state.plans.first.id);
  });
}
