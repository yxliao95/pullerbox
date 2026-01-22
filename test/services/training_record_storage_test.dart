import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pullerbox/src/models/training_record.dart';
import 'package:pullerbox/src/services/training_record_storage.dart';

void main() {
  const storageKey = TrainingRecordStorage.storageKey;
  const planName = 'Plan A';
  const recordId = 'r1';

  TrainingRecord buildRecord() {
    return TrainingRecord(
      id: recordId,
      planName: planName,
      workSeconds: 10,
      restSeconds: 5,
      cycles: 1,
      totalSeconds: 10,
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

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loadHistory returns null when storage is empty', () async {
    final storage = TrainingRecordStorage();

    final snapshot = await storage.loadHistory();

    expect(snapshot, isNull);
  });

  test('saveHistory persists and loadHistory restores records', () async {
    final storage = TrainingRecordStorage();
    final snapshot = TrainingRecordSnapshot(records: <TrainingRecord>[buildRecord()]);

    await storage.saveHistory(snapshot);
    final restored = await storage.loadHistory();

    expect(restored, isNotNull);
    expect(restored!.records.length, 1);
    expect(restored.records.first.id, recordId);
    expect(restored.records.first.planName, planName);
  });

  test('loadHistory returns null when stored payload is invalid', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{storageKey: '[]'});
    final storage = TrainingRecordStorage();

    final snapshot = await storage.loadHistory();

    expect(snapshot, isNull);
  });
}
