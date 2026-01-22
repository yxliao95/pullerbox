import 'package:flutter_test/flutter_test.dart';

import 'package:pullerbox/src/models/training_record.dart';

void main() {
  const defaultEnterDurations = <double>[0.30, 0.20, 0.10, 0.05];
  const defaultFatigueDurationSeconds = 1.0;

  test('TrainingStatistics.fromJson falls back to legacy fields', () {
    final json = <String, dynamic>{
      'maxValue': 12.0,
      'medianValue': 9.0,
      'averageValue': 8.0,
      'cycleStatistics': <Map<String, dynamic>>[],
    };

    final stats = TrainingStatistics.fromJson(json);

    expect(stats.maxStrengthSession, 12.0);
    expect(stats.maxControlStrengthSession, 9.0);
    expect(stats.controlCycles, 0);
    expect(stats.enterDurations, defaultEnterDurations);
    expect(stats.fatigueDurationSeconds, defaultFatigueDurationSeconds);
  });

  test('TrainingRecordSnapshot round-trip keeps records', () {
    final startedAt = DateTime.utc(2025, 1, 1, 0, 0, 0);
    final record = TrainingRecord(
      id: 'r1',
      planName: 'Test Plan',
      workSeconds: 30,
      restSeconds: 10,
      cycles: 2,
      totalSeconds: 80,
      startedAt: startedAt,
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
        enterDurations: defaultEnterDurations,
        controlToleranceSeconds: 0.5,
        fatigueThresholdRatio: 0.8,
        fatigueDurationSeconds: defaultFatigueDurationSeconds,
        stableWindowSeconds: 1.0,
        stableWindowCv: 0.05,
        cycleStatistics: <TrainingCycleStatistics>[],
      ),
    );

    final snapshot = TrainingRecordSnapshot(records: <TrainingRecord>[record]);
    final decoded = TrainingRecordSnapshot.fromJson(snapshot.toJson());

    expect(decoded.records.length, 1);
    expect(decoded.records.first.id, 'r1');
    expect(decoded.records.first.planName, 'Test Plan');
    expect(decoded.records.first.startedAt.toIso8601String(), record.startedAt.toIso8601String());
    expect(decoded.records.first.startedAt.isUtc, isTrue);
  });
}
