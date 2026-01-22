import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pullerbox/src/models/training_record.dart';
import 'package:pullerbox/src/providers/training_record_provider.dart';

import '../helpers/fake_storages.dart';

void main() {
  const planName = 'Plan';
  const workSeconds = 10;
  const restSeconds = 5;
  const cycles = 1;
  const totalSeconds = 10;

  TrainingRecord buildRecord(String id) {
    return TrainingRecord(
      id: id,
      planName: planName,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
      cycles: cycles,
      totalSeconds: totalSeconds,
      startedAt: DateTime.utc(2025, 1, 1, 0, 0, 0),
      groupedSamples: const <TrainingSampleGroup>[],
      statistics: const TrainingStatistics(
        maxStrengthSession: 1.0,
        maxControlStrengthSession: 1.0,
        controlCycles: 0,
        fatigueStartCycle: 0,
        fatigueStartTime: 0.0,
        fatigueStartTimestamp: 0.0,
        minControlStrength: 0.0,
        minControlStrengthMissing: true,
        dropMean: 0.0,
        dropMax: 0.0,
        dropStd: 0.0,
        ruleVersion: 'v1',
        quantile: 0.99,
        thresholdRatio: 0.95,
        enterDurations: <double>[0.30, 0.20, 0.10, 0.05],
        controlToleranceSeconds: 0.5,
        fatigueThresholdRatio: 0.8,
        fatigueDurationSeconds: 1.0,
        stableWindowSeconds: 1.0,
        stableWindowCv: 0.05,
        cycleStatistics: <TrainingCycleStatistics>[],
      ),
    );
  }

  test('TrainingRecordController restores history from storage', () async {
    final storage = FakeTrainingRecordStorage(
      snapshot: TrainingRecordSnapshot(records: <TrainingRecord>[buildRecord('r1')]),
    );
    final container = ProviderContainer(
      overrides: [
        trainingRecordStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final initial = container.read(trainingRecordProvider);
    expect(initial.records, isEmpty);

    await Future<void>.microtask(() {});

    final restored = container.read(trainingRecordProvider);
    expect(restored.records.length, 1);
    expect(restored.records.first.id, 'r1');
  });

  test('TrainingRecordController add/remove updates state and persists', () async {
    final storage = FakeTrainingRecordStorage();
    final container = ProviderContainer(
      overrides: [
        trainingRecordStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(trainingRecordProvider.notifier);

    notifier.addRecord(buildRecord('r2'));
    await Future<void>.microtask(() {});
    expect(container.read(trainingRecordProvider).records.first.id, 'r2');
    expect(storage.savedSnapshot, isNotNull);

    notifier.removeRecord('r2');
    await Future<void>.microtask(() {});
    expect(container.read(trainingRecordProvider).records, isEmpty);
    expect(storage.savedSnapshot, isNotNull);
  });
}
