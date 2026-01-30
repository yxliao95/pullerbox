import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pullerbox/src/models/training_record.dart';
import 'package:pullerbox/src/providers/system_providers.dart';
import 'package:pullerbox/src/providers/training_compare_provider.dart';
import 'package:pullerbox/src/providers/training_record_provider.dart';
import 'package:pullerbox/src/services/clock.dart';

import '../helpers/fake_storages.dart';

TrainingRecord _buildRecord({
  required String id,
  required String planName,
  required DateTime startedAt,
  required double maxStrength,
}) {
  return TrainingRecord(
    id: id,
    planName: planName,
    workSeconds: 10,
    restSeconds: 5,
    cycles: 1,
    totalSeconds: 10,
    startedAt: startedAt,
    groupedSamples: const <TrainingSampleGroup>[
      TrainingSampleGroup(cycle: 1, samples: <TrainingSample>[TrainingSample(time: 0, value: 1)]),
    ],
    statistics: TrainingStatistics(
      maxStrengthSession: maxStrength,
      maxControlStrengthSession: maxStrength,
      controlCycles: 1,
      fatigueStartCycle: 1,
      fatigueStartTime: 1.0,
      fatigueStartTimestamp: 1.0,
      minControlStrength: maxStrength,
      minControlStrengthMissing: false,
      dropMean: 0.1,
      dropMax: 0.2,
      dropStd: 0.05,
      ruleVersion: 'v1',
      quantile: 0.99,
      thresholdRatio: 0.95,
      enterDurations: const <double>[0.30, 0.20, 0.10, 0.05],
      controlToleranceSeconds: 0.5,
      fatigueThresholdRatio: 0.8,
      fatigueDurationSeconds: 1.0,
      stableWindowSeconds: 1.0,
      stableWindowCv: 0.05,
      cycleStatistics: const <TrainingCycleStatistics>[],
    ),
  );
}

void main() {
  test('TrainingCompareFilterController defaults to recent three months', () {
    final fixedNow = DateTime(2026, 1, 30, 10, 0, 0);
    final container = ProviderContainer(
      overrides: [
        clockProvider.overrideWithValue(FixedClock(fixedNow)),
      ],
    );
    addTearDown(container.dispose);

    final filter = container.read(trainingCompareFilterProvider);
    expect(filter.startDate, DateTime(2025, 10, 30));
    expect(filter.endDate, DateTime(2026, 1, 30));
  });

  test('TrainingCompareResult computes max/min/last for each plan', () async {
    final storage = FakeTrainingRecordStorage(
      snapshot: TrainingRecordSnapshot(
        records: <TrainingRecord>[
          _buildRecord(
            id: 'r1',
            planName: 'Plan A',
            startedAt: DateTime(2025, 11, 1, 9, 0),
            maxStrength: 10,
          ),
          _buildRecord(
            id: 'r2',
            planName: 'Plan A',
            startedAt: DateTime(2025, 12, 1, 9, 0),
            maxStrength: 15,
          ),
          _buildRecord(
            id: 'r3',
            planName: 'Plan B',
            startedAt: DateTime(2025, 12, 5, 9, 0),
            maxStrength: 8,
          ),
        ],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        trainingRecordStorageProvider.overrideWithValue(storage),
        clockProvider.overrideWithValue(FixedClock(DateTime(2026, 1, 30))),
      ],
    );
    addTearDown(container.dispose);

    await Future<void>.microtask(() {});

    final controller = container.read(trainingCompareFilterProvider.notifier);
    controller.setLeftPlanName('Plan A');
    controller.setRightPlanName('Plan B');

    final result = container.read(trainingCompareResultProvider);
    expect(result.left.maxValue, 15);
    expect(result.left.minValue, 10);
    expect(result.left.lastValue, 15);
    expect(result.right.maxValue, 8);
    expect(result.right.minValue, 8);
    expect(result.right.lastValue, 8);
    expect(result.globalMaxValue, 15);
    expect(result.globalMinValue, 8);
  });
}
