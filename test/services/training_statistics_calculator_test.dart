import 'package:flutter_test/flutter_test.dart';

import 'package:pullerbox/src/models/training_record.dart';
import 'package:pullerbox/src/services/training_statistics_calculator.dart';

TrainingSampleGroup _buildGroup({
  required int cycle,
  required double startTime,
  required List<double> values,
  required double interval,
}) {
  final samples = <TrainingSample>[];
  for (var index = 0; index < values.length; index++) {
    samples.add(
      TrainingSample(time: startTime + index * interval, value: values[index]),
    );
  }
  return TrainingSampleGroup(cycle: cycle, samples: samples);
}

void main() {
  const sampleInterval = 0.1;
  const workSeconds = 2;
  const strongValue = 10.0;
  const weakValue = 6.0;
  const cycleCount = 4;
  const groupsStartOffset = 5.0;
  const fatigueStartCycle = 3;
  const fatigueStartTimestamp = 10.0;
  const expectedDrop = 0.4;

  test('TrainingStatisticsCalculator returns defaults for empty input', () {
    final calculator = TrainingStatisticsCalculator();

    final stats = calculator.calculate(
      groupedSamples: const <TrainingSampleGroup>[],
      workSeconds: 0,
      sampleIntervalSeconds: sampleInterval,
    );

    expect(stats.maxStrengthSession, 0.0);
    expect(stats.maxControlStrengthSession, 0.0);
    expect(stats.controlCycles, 0);
    expect(stats.fatigueStartCycle, 0);
    expect(stats.minControlStrengthMissing, isTrue);
    expect(stats.cycleStatistics, isEmpty);
    expect(stats.ruleVersion, TrainingStatisticsCalculator.ruleVersion);
    expect(stats.quantile, TrainingStatisticsCalculator.quantileValue);
    expect(stats.thresholdRatio, TrainingStatisticsCalculator.thresholdRatio);
  });

  test('TrainingStatisticsCalculator detects fatigue after consecutive drops', () {
    final calculator = TrainingStatisticsCalculator();
    final strongValues = List<double>.filled(12, strongValue);
    final weakValues = List<double>.filled(12, weakValue);

    final groups = <TrainingSampleGroup>[
      _buildGroup(cycle: 1, startTime: 0.0, values: strongValues, interval: sampleInterval),
      _buildGroup(
        cycle: 2,
        startTime: groupsStartOffset,
        values: strongValues,
        interval: sampleInterval,
      ),
      _buildGroup(
        cycle: 3,
        startTime: groupsStartOffset * 2,
        values: weakValues,
        interval: sampleInterval,
      ),
      _buildGroup(
        cycle: 4,
        startTime: groupsStartOffset * 3,
        values: weakValues,
        interval: sampleInterval,
      ),
    ];

    final stats = calculator.calculate(
      groupedSamples: groups,
      workSeconds: workSeconds,
      sampleIntervalSeconds: sampleInterval,
    );

    expect(stats.maxStrengthSession, strongValue);
    expect(stats.maxControlStrengthSession, strongValue);
    expect(stats.controlCycles, cycleCount);
    expect(stats.fatigueStartCycle, fatigueStartCycle);
    expect(stats.fatigueStartTime, 0.0);
    expect(stats.fatigueStartTimestamp, fatigueStartTimestamp);
    expect(stats.minControlStrengthMissing, isFalse);
    expect(stats.minControlStrength, weakValue);
    expect(stats.dropMean, closeTo(expectedDrop, 1e-6));
    expect(stats.dropMax, closeTo(expectedDrop, 1e-6));
    expect(stats.dropStd, closeTo(0.0, 1e-6));
    expect(stats.cycleStatistics.length, cycleCount);
  });
}
