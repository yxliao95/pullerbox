import 'dart:math' as math;

import '../models/training_record.dart';

part 'training_statistics_helpers.dart';

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

    final baselineValues = <double>[];
    for (final snapshot in cycleSnapshots.take(2)) {
      if (snapshot.values.isEmpty) {
        continue;
      }
      final gate = snapshot.maxStrength * thresholdRatio;
      if (gate <= 0) {
        continue;
      }
      baselineValues.addAll(snapshot.values.where((value) => value >= gate));
    }
    final baselineCandidates = cycleSnapshots.take(2).map((snapshot) => snapshot.maxStrength).toList();
    final baseline = baselineValues.isEmpty ? _median(baselineCandidates) : _median(baselineValues);
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

}
