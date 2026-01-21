part of 'training_statistics_calculator.dart';

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
