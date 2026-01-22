import 'package:flutter_test/flutter_test.dart';

import 'package:pullerbox/src/models/free_training_record.dart';

void main() {
  const totalSeconds = 12.5;
  const controlMaxValue = 22.0;
  const longestControlTimeSeconds = 3.5;
  const currentWindowMeanValue = 18.0;
  const currentWindowDeltaValue = -1.2;
  const deltaMaxValue = 2.0;
  const deltaMinValue = -2.0;
  const samples = <double>[10.0, 12.5, 11.0];

  test('FreeTrainingRecord round-trip preserves UTC timestamp', () {
    final startedAt = DateTime.utc(2025, 1, 1, 12, 0, 0);
    final record = FreeTrainingRecord(
      id: 'f1',
      title: 'Free Session',
      totalSeconds: totalSeconds,
      startedAt: startedAt,
      controlMaxValue: controlMaxValue,
      longestControlTimeSeconds: longestControlTimeSeconds,
      currentWindowMeanValue: currentWindowMeanValue,
      currentWindowDeltaValue: currentWindowDeltaValue,
      deltaMaxValue: deltaMaxValue,
      deltaMinValue: deltaMinValue,
      samples: samples,
    );

    final decoded = FreeTrainingRecord.fromJson(record.toJson());

    expect(decoded.id, 'f1');
    expect(decoded.title, 'Free Session');
    expect(decoded.totalSeconds, totalSeconds);
    expect(decoded.startedAt.toIso8601String(), startedAt.toIso8601String());
    expect(decoded.startedAt.isUtc, isTrue);
    expect(decoded.controlMaxValue, controlMaxValue);
    expect(decoded.longestControlTimeSeconds, longestControlTimeSeconds);
    expect(decoded.currentWindowMeanValue, currentWindowMeanValue);
    expect(decoded.currentWindowDeltaValue, currentWindowDeltaValue);
    expect(decoded.deltaMaxValue, deltaMaxValue);
    expect(decoded.deltaMinValue, deltaMinValue);
    expect(decoded.samples, samples);
  });

  test('FreeTrainingRecord.fromJson falls back to epoch timestamp when missing', () {
    final decoded = FreeTrainingRecord.fromJson(<String, dynamic>{});

    expect(decoded.startedAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
    expect(decoded.startedAt.isUtc, isTrue);
    expect(decoded.samples, isEmpty);
  });
}
