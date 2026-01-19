import 'dart:math' as math;

import '../models/training_record.dart';

class TrainingStatisticsCalculator {
  static const String ruleVersion = 'v1';
  static const double quantileValue = 0.99;
  static const double thresholdRatio = 0.95;
  static const List<double> enterDurations = <double>[0.30, 0.20, 0.10, 0.05];
  static const double controlToleranceSeconds = 0.5;
  static const double fatigueThresholdRatio = 0.8;
  static const double fatigueDurationSeconds = 1.0;
  static const double stableWindowSeconds = 1.0;
  static const double stableWindowCv = 0.05;

  TrainingStatistics calculate({
    required List<TrainingSampleGroup> groupedSamples,
    required int workSeconds,
    double sampleIntervalSeconds = 0.05,
  }) {
    final requiredCounts = enterDurations
        .map((duration) => _samplesForDuration(duration, sampleIntervalSeconds))
        .toList(growable: false);
    final cycleSnapshots = <_CycleSnapshot>[];

    for (final group in groupedSamples) {
      final samples = List<TrainingSample>.from(group.samples)
        ..sort((a, b) => a.time.compareTo(b.time));
      if (samples.isEmpty) {
        cycleSnapshots.add(_CycleSnapshot.empty(cycle: group.cycle));
        continue;
      }

      final cycleStartTime = samples.first.time;
      final times = <double>[];
      final values = <double>[];
      for (final sample in samples) {
        final localTime = sample.time - cycleStartTime;
        if (localTime < 0) {
          continue;
        }
        if (workSeconds > 0 && localTime > workSeconds) {
          continue;
        }
        times.add(localTime);
        values.add(sample.value);
      }

      if (values.isEmpty) {
        cycleSnapshots.add(_CycleSnapshot.empty(cycle: group.cycle));
        continue;
      }

      final tempMax = _quantile(values, quantileValue);
      final tempThreshold = tempMax * thresholdRatio;
      final tempStart = _findStart(times, values, tempThreshold, requiredCounts);
      final tempStartIndex = tempStart?.index ?? 0;
      final tempValues = values.sublist(tempStartIndex);
      final maxStrength = _quantile(tempValues, quantileValue);

      final finalThreshold = maxStrength * thresholdRatio;
      final finalStart = _findStart(times, values, finalThreshold, requiredCounts);
      final startIndex = finalStart?.index ?? 0;
      final startTime = finalStart?.time ?? times[startIndex];
      final startValues = values.sublist(startIndex);
      final startTimes = times.sublist(startIndex);

      final controlGate = maxStrength * thresholdRatio;
      final controlValues = startValues.where((value) => value >= controlGate).toList();
      final controlStrength = controlValues.isEmpty ? 0.0 : _median(controlValues);
      final controlLower = controlStrength * thresholdRatio;
      final controlCount = startValues.where((value) => value >= controlLower).length;
      final outCount = startValues.where((value) => value < controlLower).length;
      final controlTime = controlCount * sampleIntervalSeconds;
      final outTime = outCount * sampleIntervalSeconds;
      final averageStrength = _mean(startValues);

      cycleSnapshots.add(
        _CycleSnapshot(
          cycle: group.cycle,
          cycleStartTime: cycleStartTime,
          startTime: startTime,
          values: startValues,
          times: startTimes,
          maxStrength: maxStrength,
          controlStrength: controlStrength,
          controlTime: controlTime,
          outTime: outTime,
          averageStrength: averageStrength,
          fallbackLevel: tempStart?.level ?? -1,
        ),
      );
    }

    if (cycleSnapshots.isEmpty) {
      return TrainingStatistics(
        maxStrengthSession: 0.0,
        maxControlStrengthSession: 0.0,
        controlCycles: 0,
        fatigueStartCycle: 0,
        fatigueStartTime: 0.0,
        fatigueStartTimestamp: 0.0,
        minControlStrength: 0.0,
        minControlStrengthMissing: true,
        dropMean: 0.0,
        dropMax: 0.0,
        dropStd: 0.0,
        ruleVersion: ruleVersion,
        quantile: quantileValue,
        thresholdRatio: thresholdRatio,
        enterDurations: enterDurations,
        controlToleranceSeconds: controlToleranceSeconds,
        fatigueThresholdRatio: fatigueThresholdRatio,
        fatigueDurationSeconds: fatigueDurationSeconds,
        stableWindowSeconds: stableWindowSeconds,
        stableWindowCv: stableWindowCv,
        cycleStatistics: const <TrainingCycleStatistics>[],
      );
    }

    final maxStrengthSession =
        cycleSnapshots.map((snapshot) => snapshot.maxStrength).fold(0.0, math.max);
    final maxControlStrengthSession =
        cycleSnapshots.map((snapshot) => snapshot.controlStrength).fold(0.0, math.max);
    final controlCycles = cycleSnapshots
        .where((snapshot) => snapshot.values.isNotEmpty && snapshot.outTime <= controlToleranceSeconds)
        .length;

    final baselineCandidates = cycleSnapshots.take(2).map((snapshot) => snapshot.maxStrength).toList();
    final baseline = _median(baselineCandidates);
    final fatigueThreshold = baseline * fatigueThresholdRatio;
    final failWindow = _samplesForDuration(fatigueDurationSeconds, sampleIntervalSeconds);
    final failFlags = List<bool>.filled(cycleSnapshots.length, false);
    final lowTimes = List<double?>.filled(cycleSnapshots.length, null);

    if (fatigueThreshold > 0) {
      for (var index = 0; index < cycleSnapshots.length; index++) {
        final snapshot = cycleSnapshots[index];
        final lowResult = _findConsecutiveBelow(snapshot.values, snapshot.times, fatigueThreshold, failWindow);
        if (lowResult != null) {
          failFlags[index] = true;
          lowTimes[index] = lowResult;
        }
      }
    }

    var fatigueStartCycle = 0;
    double fatigueStartTime = 0.0;
    double fatigueStartTimestamp = 0.0;
    for (var index = 0; index < failFlags.length - 1; index++) {
      if (failFlags[index] && failFlags[index + 1]) {
        fatigueStartCycle = cycleSnapshots[index].cycle;
        fatigueStartTime = lowTimes[index] ?? 0.0;
        fatigueStartTimestamp = cycleSnapshots[index].cycleStartTime + fatigueStartTime;
        break;
      }
    }

    var minControlStrength = 0.0;
    var minControlStrengthMissing = true;
    if (fatigueStartCycle > 0) {
      final windowSamples = _samplesForDuration(stableWindowSeconds, sampleIntervalSeconds);
      final omegaValues = <double>[];
      final startIndex = cycleSnapshots.indexWhere((snapshot) => snapshot.cycle == fatigueStartCycle);
      for (var index = startIndex; index < cycleSnapshots.length; index++) {
        final snapshot = cycleSnapshots[index];
        if (snapshot.values.isEmpty) {
          continue;
        }
        if (index == startIndex) {
          final cutIndex = snapshot.times.indexWhere((time) => time >= fatigueStartTime);
          if (cutIndex >= 0) {
            omegaValues.addAll(snapshot.values.sublist(cutIndex));
          }
        } else {
          omegaValues.addAll(snapshot.values);
        }
      }

      final stableMeans = _stableWindowMeans(omegaValues, windowSamples, stableWindowCv);
      if (stableMeans.isNotEmpty) {
        minControlStrength = stableMeans.reduce(math.min);
        minControlStrengthMissing = false;
      }
    }

    var dropMean = 0.0;
    var dropMax = 0.0;
    var dropStd = 0.0;
    if (fatigueStartCycle > 0 && maxControlStrengthSession > 0) {
      final drops = <double>[];
      final startIndex = cycleSnapshots.indexWhere((snapshot) => snapshot.cycle == fatigueStartCycle);
      for (var index = startIndex; index < cycleSnapshots.length; index++) {
        final drop = 1 - cycleSnapshots[index].averageStrength / maxControlStrengthSession;
        drops.add(drop);
      }
      dropMean = _mean(drops);
      dropMax = drops.fold(0.0, math.max);
      dropStd = _std(drops, dropMean);
    }

    final cycleStatistics = <TrainingCycleStatistics>[];
    for (var index = 0; index < cycleSnapshots.length; index++) {
      final snapshot = cycleSnapshots[index];
      cycleStatistics.add(
        TrainingCycleStatistics(
          cycle: snapshot.cycle,
          maxStrength: snapshot.maxStrength,
          controlStrength: snapshot.controlStrength,
          controlTime: snapshot.controlTime,
          outTime: snapshot.outTime,
          averageStrength: snapshot.averageStrength,
          fallbackLevel: snapshot.fallbackLevel,
          fail: failFlags[index],
          startTime: snapshot.startTime,
          lowTime: lowTimes[index],
        ),
      );
    }

    return TrainingStatistics(
      maxStrengthSession: maxStrengthSession,
      maxControlStrengthSession: maxControlStrengthSession,
      controlCycles: controlCycles,
      fatigueStartCycle: fatigueStartCycle,
      fatigueStartTime: fatigueStartTime,
      fatigueStartTimestamp: fatigueStartTimestamp,
      minControlStrength: minControlStrength,
      minControlStrengthMissing: minControlStrengthMissing,
      dropMean: dropMean,
      dropMax: dropMax,
      dropStd: dropStd,
      ruleVersion: ruleVersion,
      quantile: quantileValue,
      thresholdRatio: thresholdRatio,
      enterDurations: enterDurations,
      controlToleranceSeconds: controlToleranceSeconds,
      fatigueThresholdRatio: fatigueThresholdRatio,
      fatigueDurationSeconds: fatigueDurationSeconds,
      stableWindowSeconds: stableWindowSeconds,
      stableWindowCv: stableWindowCv,
      cycleStatistics: cycleStatistics,
    );
  }

  int _samplesForDuration(double durationSeconds, double sampleIntervalSeconds) {
    return math.max(1, (durationSeconds / sampleIntervalSeconds).round());
  }

  _StartResult? _findStart(
    List<double> times,
    List<double> values,
    double threshold,
    List<int> requiredCounts,
  ) {
    for (var level = 0; level < requiredCounts.length; level++) {
      final requiredCount = requiredCounts[level];
      final index = _findConsecutiveAtOrAbove(values, threshold, requiredCount);
      if (index != null) {
        return _StartResult(index: index, time: times[index], level: level);
      }
    }
    return null;
  }

  int? _findConsecutiveAtOrAbove(List<double> values, double threshold, int requiredCount) {
    if (values.length < requiredCount) {
      return null;
    }
    for (var index = 0; index <= values.length - requiredCount; index++) {
      var passed = true;
      for (var offset = 0; offset < requiredCount; offset++) {
        if (values[index + offset] < threshold) {
          passed = false;
          break;
        }
      }
      if (passed) {
        return index;
      }
    }
    return null;
  }

  double? _findConsecutiveBelow(
    List<double> values,
    List<double> times,
    double threshold,
    int requiredCount,
  ) {
    if (values.length < requiredCount) {
      return null;
    }
    for (var index = 0; index <= values.length - requiredCount; index++) {
      var passed = true;
      for (var offset = 0; offset < requiredCount; offset++) {
        if (values[index + offset] >= threshold) {
          passed = false;
          break;
        }
      }
      if (passed) {
        return times[index];
      }
    }
    return null;
  }

  double _mean(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    var total = 0.0;
    for (final value in values) {
      total += value;
    }
    return total / values.length;
  }

  double _std(List<double> values, double mean) {
    if (values.isEmpty) {
      return 0.0;
    }
    var total = 0.0;
    for (final value in values) {
      final delta = value - mean;
      total += delta * delta;
    }
    return math.sqrt(total / values.length);
  }

  double _median(List<double> values) {
    if (values.isEmpty) {
      return 0.0;
    }
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }

  double _quantile(List<double> values, double quantile) {
    if (values.isEmpty) {
      return 0.0;
    }
    final sorted = List<double>.from(values)..sort();
    final index = (quantile * (sorted.length - 1)).clamp(0.0, sorted.length - 1.0);
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) {
      return sorted[lower];
    }
    final weight = index - lower;
    return sorted[lower] * (1 - weight) + sorted[upper] * weight;
  }

  List<double> _stableWindowMeans(List<double> values, int windowSamples, double cvThreshold) {
    final results = <double>[];
    if (values.length < windowSamples || windowSamples <= 0) {
      return results;
    }
    for (var index = 0; index <= values.length - windowSamples; index++) {
      final window = values.sublist(index, index + windowSamples);
      final mean = _mean(window);
      if (mean <= 0) {
        continue;
      }
      final std = _std(window, mean);
      final cv = std / mean;
      if (cv <= cvThreshold) {
        results.add(mean);
      }
    }
    return results;
  }
}

class _StartResult {
  const _StartResult({required this.index, required this.time, required this.level});

  final int index;
  final double time;
  final int level;
}

class _CycleSnapshot {
  const _CycleSnapshot({
    required this.cycle,
    required this.cycleStartTime,
    required this.startTime,
    required this.values,
    required this.times,
    required this.maxStrength,
    required this.controlStrength,
    required this.controlTime,
    required this.outTime,
    required this.averageStrength,
    required this.fallbackLevel,
  });

  const _CycleSnapshot.empty({required this.cycle})
      : cycleStartTime = 0.0,
        startTime = 0.0,
        values = const <double>[],
        times = const <double>[],
        maxStrength = 0.0,
        controlStrength = 0.0,
        controlTime = 0.0,
        outTime = 0.0,
        averageStrength = 0.0,
        fallbackLevel = -1;

  final int cycle;
  final double cycleStartTime;
  final double startTime;
  final List<double> values;
  final List<double> times;
  final double maxStrength;
  final double controlStrength;
  final double controlTime;
  final double outTime;
  final double averageStrength;
  final int fallbackLevel;
}
