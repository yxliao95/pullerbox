import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pullerbox/src/models/free_training_record.dart';
import 'package:pullerbox/src/services/free_training_record_storage.dart';

void main() {
  const storageKey = FreeTrainingRecordStorage.storageKey;
  const recordId = 'f1';
  const title = 'Free Session';

  FreeTrainingRecord buildRecord() {
    return FreeTrainingRecord(
      id: recordId,
      title: title,
      totalSeconds: 12.5,
      startedAt: DateTime.utc(2025, 1, 1, 0, 0, 0),
      controlMaxValue: 10.0,
      longestControlTimeSeconds: 2.5,
      currentWindowMeanValue: 8.0,
      currentWindowDeltaValue: -0.5,
      deltaMaxValue: 1.0,
      deltaMinValue: -1.0,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loadHistory returns null when storage is empty', () async {
    final storage = FreeTrainingRecordStorage();

    final snapshot = await storage.loadHistory();

    expect(snapshot, isNull);
  });

  test('saveHistory persists and loadHistory restores records', () async {
    final storage = FreeTrainingRecordStorage();
    final snapshot = FreeTrainingRecordSnapshot(records: <FreeTrainingRecord>[buildRecord()]);

    await storage.saveHistory(snapshot);
    final restored = await storage.loadHistory();

    expect(restored, isNotNull);
    expect(restored!.records.length, 1);
    expect(restored.records.first.id, recordId);
    expect(restored.records.first.title, title);
  });

  test('loadHistory returns null when stored payload is invalid', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{storageKey: '[]'});
    final storage = FreeTrainingRecordStorage();

    final snapshot = await storage.loadHistory();

    expect(snapshot, isNull);
  });
}
