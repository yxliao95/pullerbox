import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pullerbox/src/models/free_training_record.dart';
import 'package:pullerbox/src/providers/free_training_record_provider.dart';

import '../helpers/fake_storages.dart';

void main() {
  const title = 'Free';
  const totalSeconds = 12.5;

  FreeTrainingRecord buildRecord(String id) {
    return FreeTrainingRecord(
      id: id,
      title: title,
      totalSeconds: totalSeconds,
      startedAt: DateTime.utc(2025, 1, 1, 0, 0, 0),
      controlMaxValue: 10.0,
      longestControlTimeSeconds: 2.5,
      currentWindowMeanValue: 8.0,
      currentWindowDeltaValue: -0.5,
      deltaMaxValue: 1.0,
      deltaMinValue: -1.0,
    );
  }

  test('FreeTrainingRecordController restores history from storage', () async {
    final storage = FakeFreeTrainingRecordStorage(
      snapshot: FreeTrainingRecordSnapshot(records: <FreeTrainingRecord>[buildRecord('f1')]),
    );
    final container = ProviderContainer(
      overrides: [
        freeTrainingRecordStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);

    final initial = container.read(freeTrainingRecordProvider);
    expect(initial.records, isEmpty);

    await Future<void>.microtask(() {});

    final restored = container.read(freeTrainingRecordProvider);
    expect(restored.records.length, 1);
    expect(restored.records.first.id, 'f1');
  });

  test('FreeTrainingRecordController add/remove updates state and persists', () async {
    final storage = FakeFreeTrainingRecordStorage();
    final container = ProviderContainer(
      overrides: [
        freeTrainingRecordStorageProvider.overrideWithValue(storage),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(freeTrainingRecordProvider.notifier);

    notifier.addRecord(buildRecord('f2'));
    await Future<void>.microtask(() {});
    expect(container.read(freeTrainingRecordProvider).records.first.id, 'f2');
    expect(storage.savedSnapshot, isNotNull);

    notifier.removeRecord('f2');
    await Future<void>.microtask(() {});
    expect(container.read(freeTrainingRecordProvider).records, isEmpty);
    expect(storage.savedSnapshot, isNotNull);
  });
}
