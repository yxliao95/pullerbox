import '../models/training_record.dart';
import '../services/random_source.dart';
import '../services/training_statistics_calculator.dart';

enum FakeCurvePattern { linearRise, step, randomWalk }

class TrainingRecordSeedBuilder {
  TrainingRecordSeedBuilder({
    required this.calculator,
    required this.randomSource,
    required this.sampleIntervalSeconds,
    required this.noiseStrength,
    required this.maxStrength,
    required this.pattern,
  });

  final TrainingStatisticsCalculator calculator;
  final RandomSource randomSource;
  final double sampleIntervalSeconds;
  final double noiseStrength;
  final double maxStrength;
  final FakeCurvePattern pattern;

  List<TrainingRecord> buildMonthlyPlanRecords({
    required int year,
    required int month,
    required int daysToPick,
    required List<String> planNames,
    required int workSeconds,
    required int restSeconds,
    required int cycles,
  }) {
    if (planNames.isEmpty || daysToPick <= 0) {
      return const <TrainingRecord>[];
    }
    final pickedDays = _pickDays(year: year, month: month, count: daysToPick);
    final records = <TrainingRecord>[];
    for (final day in pickedDays) {
      for (int index = 0; index < planNames.length; index++) {
        final recordSeed = _mixSeed(randomSource.nextInt(1 << 31), day, index);
        final recordRandom = SeededRandomSource(seed: recordSeed);
        final startedAt = _randomStartTime(year, month, day, index, recordRandom);
        final groupedSamples = _buildGroupedSamples(
          cycles: cycles,
          workSeconds: workSeconds,
          recordRandom: recordRandom,
        );
        final statistics = calculator.calculate(
          groupedSamples: groupedSamples,
          workSeconds: workSeconds,
          sampleIntervalSeconds: sampleIntervalSeconds,
        );
        final totalSeconds = workSeconds * cycles + restSeconds * (cycles - 1);
        records.add(
          TrainingRecord(
            id: startedAt.microsecondsSinceEpoch.toString(),
            planName: planNames[index],
            workSeconds: workSeconds,
            restSeconds: restSeconds,
            cycles: cycles,
            totalSeconds: totalSeconds,
            startedAt: startedAt,
            groupedSamples: groupedSamples,
            statistics: statistics,
          ),
        );
      }
    }
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return records;
  }

  List<TrainingRecord> buildPlanRecordsForDate({
    required DateTime date,
    required List<String> planNames,
    required int workSeconds,
    required int restSeconds,
    required int cycles,
  }) {
    if (planNames.isEmpty) {
      return const <TrainingRecord>[];
    }
    final records = <TrainingRecord>[];
    for (int index = 0; index < planNames.length; index++) {
      final recordSeed = _mixSeed(randomSource.nextInt(1 << 31), date.day, index);
      final recordRandom = SeededRandomSource(seed: recordSeed);
      final startedAt = _randomStartTime(date.year, date.month, date.day, index, recordRandom);
      final groupedSamples = _buildGroupedSamples(
        cycles: cycles,
        workSeconds: workSeconds,
        recordRandom: recordRandom,
      );
      final statistics = calculator.calculate(
        groupedSamples: groupedSamples,
        workSeconds: workSeconds,
        sampleIntervalSeconds: sampleIntervalSeconds,
      );
      final totalSeconds = workSeconds * cycles + restSeconds * (cycles - 1);
      records.add(
        TrainingRecord(
          id: startedAt.microsecondsSinceEpoch.toString(),
          planName: planNames[index],
          workSeconds: workSeconds,
          restSeconds: restSeconds,
          cycles: cycles,
          totalSeconds: totalSeconds,
          startedAt: startedAt,
          groupedSamples: groupedSamples,
          statistics: statistics,
        ),
      );
    }
    records.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return records;
  }

  int _mixSeed(int baseSeed, int day, int planIndex) {
    final mixed = baseSeed ^ (day * 1009) ^ (planIndex * 7919);
    return mixed & 0x7fffffff;
  }

  List<int> _pickDays({required int year, required int month, required int count}) {
    final totalDays = DateTime(year, month + 1, 0).day;
    final days = List<int>.generate(totalDays, (index) => index + 1);
    for (int index = days.length - 1; index > 0; index--) {
      final swapIndex = randomSource.nextInt(index + 1);
      final temp = days[index];
      days[index] = days[swapIndex];
      days[swapIndex] = temp;
    }
    return days.take(count.clamp(0, totalDays)).toList()..sort();
  }

  DateTime _randomStartTime(int year, int month, int day, int planIndex, RandomSource recordRandom) {
    final baseHour = planIndex == 0 ? 9 : 18;
    final hour = baseHour + recordRandom.nextInt(3);
    final minute = recordRandom.nextInt(60);
    final second = recordRandom.nextInt(60);
    return DateTime(year, month, day, hour, minute, second);
  }

  List<TrainingSampleGroup> _buildGroupedSamples({
    required int cycles,
    required int workSeconds,
    required RandomSource recordRandom,
  }) {
    final simulator = _BluetoothPullerSimulator(
      randomSource: recordRandom,
      sampleIntervalSeconds: sampleIntervalSeconds,
      noiseStrength: noiseStrength,
      maxStrength: maxStrength,
      pattern: pattern,
    );
    return simulator.buildGroupedSamples(cycles: cycles, workSeconds: workSeconds);
  }

}

class _BluetoothPullerSimulator {
  _BluetoothPullerSimulator({
    required this.randomSource,
    required this.sampleIntervalSeconds,
    required this.noiseStrength,
    required this.maxStrength,
    required this.pattern,
  });

  final RandomSource randomSource;
  final double sampleIntervalSeconds;
  final double noiseStrength;
  final double maxStrength;
  final FakeCurvePattern pattern;

  double _elapsedInPhase = 0.0;
  double _simulatedValue = 0.0;
  double _cycleStartDuration = 0.0;
  double _cycleStartValue = 0.0;
  double _cycleUnstableStartTime = 0.0;
  bool _cycleHasUnstable = false;
  bool _unstableActive = false;
  double _startupPendingDelta = 0.0;
  int _startupHoldRemaining = 0;
  double _descendingPendingDelta = 0.0;
  int _descendingHoldRemaining = 0;
  double _vMax = 0.0;
  double _vMin = 0.0;
  int _stableCycleLimit = 0;
  double _instabilityRangeMin = 0.1;
  double _instabilityRangeMax = 0.2;
  bool _fatigueModeActive = false;
  bool _fatigueModeNext = false;
  bool _fatigueWillDrop = false;
  bool _fatigueDropStarted = false;
  double _fatigueDropStartTime = 0.0;
  double _fatigueDropDuration = 0.0;
  double _fatigueDropTarget = 0.0;
  double _fatigueDropStartValue = 0.0;

  List<TrainingSampleGroup> buildGroupedSamples({required int cycles, required int workSeconds}) {
    final groups = <TrainingSampleGroup>[];
    _prepareSessionSimulation(totalCycles: cycles);
    for (int cycle = 1; cycle <= cycles; cycle++) {
      _elapsedInPhase = 0.0;
      _prepareWorkSimulation(phaseDurationSeconds: workSeconds.toDouble(), currentCycle: cycle);
      final samples = <TrainingSample>[];
      final sampleCount = _sampleCount(workSeconds);
      for (int index = 0; index < sampleCount; index++) {
        _elapsedInPhase += sampleIntervalSeconds;
        final value = _nextSampleValue();
        samples.add(TrainingSample(time: (index + 1) * sampleIntervalSeconds, value: value));
      }
      groups.add(TrainingSampleGroup(cycle: cycle, samples: samples));
    }
    return groups;
  }

  int _sampleCount(int workSeconds) {
    final count = (workSeconds / sampleIntervalSeconds).round();
    return count <= 0 ? 1 : count;
  }

  double _nextSampleValue() {
    final value = _fatigueModeActive ? _nextFatigueValue() : _nextWorkingValue();
    final noisy = (value + _randomNoise()).clamp(0.0, maxStrength);
    _simulatedValue = noisy;
    return _roundToTenth(noisy);
  }

  void _prepareSessionSimulation({required int totalCycles}) {
    final minMax = _patternRange(min: 18.0, max: maxStrength);
    _vMax = _randomInRange(minMax.min, minMax.max);
    final minRatio = _patternRange(min: 0.3, max: 0.5);
    _vMin = _vMax * _randomInRange(minRatio.min, minRatio.max);
    final unstableRatio = _randomInRange(0.4, 0.6);
    _stableCycleLimit = totalCycles > 0 ? (totalCycles * unstableRatio).round().clamp(1, totalCycles) : 1;
    _instabilityRangeMin = 0.1;
    _instabilityRangeMax = 0.2;
    _fatigueModeActive = false;
    _fatigueModeNext = false;
  }

  void _prepareWorkSimulation({required double phaseDurationSeconds, required int currentCycle}) {
    _fatigueModeActive = _fatigueModeNext;
    _cycleStartDuration = _randomInRange(0.7, 1.3);
    _cycleStartValue = _fatigueModeActive ? _randomInRange(0.0, 0.5) : _randomInRange(0.0, idleMaxValue);
    _cycleHasUnstable = !_fatigueModeActive && currentCycle > _stableCycleLimit;
    _cycleUnstableStartTime = 0.0;
    _startupPendingDelta = 0.0;
    _startupHoldRemaining = 0;
    _descendingPendingDelta = 0.0;
    _descendingHoldRemaining = 0;
    _unstableActive = false;
    if (_cycleHasUnstable && phaseDurationSeconds > 0) {
      final ratio = _randomInRange(_instabilityRangeMin, _instabilityRangeMax);
      final unstableDuration = ratio * phaseDurationSeconds;
      _cycleUnstableStartTime = (phaseDurationSeconds - unstableDuration).clamp(
        _cycleStartDuration,
        phaseDurationSeconds,
      );
      if (ratio > 0.5) {
        _fatigueModeNext = true;
      }
    }
    if (_cycleHasUnstable) {
      _advanceInstabilityRange();
    }
    _prepareFatigueDrop(phaseDurationSeconds);
  }

  void _advanceInstabilityRange() {
    final delta = _randomInRange(0.1, 0.2);
    _instabilityRangeMax = (_instabilityRangeMax + delta).clamp(_instabilityRangeMin, 1.0);
  }

  void _prepareFatigueDrop(double phaseDurationSeconds) {
    _fatigueWillDrop = _fatigueModeActive && randomSource.nextDouble() < 0.3;
    _fatigueDropStarted = false;
    _fatigueDropStartValue = 0.0;
    if (!_fatigueWillDrop) {
      _fatigueDropStartTime = 0.0;
      _fatigueDropDuration = 0.0;
      _fatigueDropTarget = 0.0;
      return;
    }
    final dropWindowSeconds = _randomInRange(1.0, 3.0);
    _fatigueDropDuration = _randomInRange(0.2, 0.5);
    _fatigueDropTarget = _randomInRange(0.0, 1.0);
    var dropStart = phaseDurationSeconds - dropWindowSeconds;
    dropStart = dropStart.clamp(_cycleStartDuration, phaseDurationSeconds);
    if (dropStart + _fatigueDropDuration > phaseDurationSeconds) {
      dropStart = (phaseDurationSeconds - _fatigueDropDuration).clamp(_cycleStartDuration, phaseDurationSeconds);
    }
    _fatigueDropStartTime = dropStart;
  }

  double _nextWorkingValue() {
    final time = _elapsedInPhase;
    if (time <= _cycleStartDuration && _cycleStartDuration > 0) {
      return _nextStartupSample(targetValue: _vMax);
    }
    if (_cycleHasUnstable && time >= _cycleUnstableStartTime) {
      if (!_unstableActive) {
        _unstableActive = true;
        _descendingPendingDelta = 0.0;
        _descendingHoldRemaining = 0;
      }
      final nextValue = (_simulatedValue - _randomInRange(0.3, 1.2)).clamp(_vMin, _vMax);
      if (nextValue <= _vMin) {
        return (_vMin + _randomInRange(-1.5, 1.5)).clamp(0.0, _vMax);
      }
      return _nextDescendingSample(targetValue: nextValue);
    }
    return (_vMax + _randomInRange(-1.5, 1.5)).clamp(0.0, _vMax);
  }

  double _nextFatigueValue() {
    final time = _elapsedInPhase;
    if (time <= _cycleStartDuration && _cycleStartDuration > 0) {
      return _nextStartupSample(targetValue: _vMin);
    }
    if (_fatigueWillDrop && time >= _fatigueDropStartTime) {
      if (!_fatigueDropStarted) {
        _fatigueDropStarted = true;
        _fatigueDropStartValue = _simulatedValue;
        _descendingPendingDelta = 0.0;
        _descendingHoldRemaining = 0;
      }
      final dropProgress = ((time - _fatigueDropStartTime) / _fatigueDropDuration).clamp(0.0, 1.0);
      if (dropProgress >= 1.0) {
        return _randomInRange(0.0, _fatigueDropTarget);
      }
      final nextProgress =
          ((time + sampleIntervalSeconds - _fatigueDropStartTime) / _fatigueDropDuration).clamp(0.0, 1.0);
      final nextValue = _lerpValue(_fatigueDropStartValue, _fatigueDropTarget, nextProgress);
      return _nextDescendingSample(targetValue: nextValue);
    }
    return (_vMin + _randomInRange(-1.5, 1.5)).clamp(0.0, _vMin);
  }

  double _nextStartupSample({required double targetValue}) {
    if (_cycleStartDuration <= 0) {
      return targetValue;
    }
    if (_startupHoldRemaining == 0) {
      _startupHoldRemaining = randomSource.nextInt(4);
    }
    final nextTime = (_elapsedInPhase + sampleIntervalSeconds).clamp(0.0, _cycleStartDuration);
    final ratio = (nextTime / _cycleStartDuration).clamp(0.0, 1.0);
    final baselineNext = _lerpValue(_cycleStartValue, targetValue, ratio);
    final baselineDelta = baselineNext - _simulatedValue;
    final totalDelta = baselineDelta + _startupPendingDelta;
    double appliedDelta;
    if (_startupHoldRemaining > 0) {
      final scale = _randomInRange(0.1, 0.3);
      appliedDelta = totalDelta * scale;
      _startupPendingDelta = totalDelta - appliedDelta;
      _startupHoldRemaining -= 1;
    } else {
      appliedDelta = totalDelta;
      _startupPendingDelta = 0.0;
    }
    final minValue = _minValue(_simulatedValue, targetValue);
    final maxValue = _maxValue(_simulatedValue, targetValue);
    return (_simulatedValue + appliedDelta).clamp(minValue, maxValue);
  }

  double _nextDescendingSample({required double targetValue}) {
    if (_descendingHoldRemaining == 0) {
      _descendingHoldRemaining = randomSource.nextInt(4);
    }
    final baselineDelta = targetValue - _simulatedValue;
    final totalDelta = baselineDelta + _descendingPendingDelta;
    double appliedDelta;
    if (_descendingHoldRemaining > 0) {
      final scale = _randomInRange(0.1, 0.3);
      appliedDelta = totalDelta * scale;
      _descendingPendingDelta = totalDelta - appliedDelta;
      _descendingHoldRemaining -= 1;
    } else {
      appliedDelta = totalDelta;
      _descendingPendingDelta = 0.0;
    }
    final minValue = _minValue(_simulatedValue, targetValue);
    final maxValue = _maxValue(_simulatedValue, targetValue);
    return (_simulatedValue + appliedDelta).clamp(minValue, maxValue);
  }

  _Range _patternRange({required double min, required double max}) {
    switch (pattern) {
      case FakeCurvePattern.linearRise:
        return _Range(min, max);
      case FakeCurvePattern.step:
        return _Range(min + 2.0, max);
      case FakeCurvePattern.randomWalk:
        return _Range(min - 2.0, max);
    }
  }

  double _randomInRange(double min, double max) {
    if (max <= min) {
      return min;
    }
    return min + randomSource.nextDouble() * (max - min);
  }

  double _randomNoise() {
    return (randomSource.nextDouble() * 2 - 1) * noiseStrength;
  }

  double _roundToTenth(double value) {
    return (value * 10).roundToDouble() / 10;
  }

  double _lerpValue(double start, double end, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return start + (end - start) * clampedT;
  }

  double _minValue(double left, double right) => left < right ? left : right;

  double _maxValue(double left, double right) => left > right ? left : right;
}

class _Range {
  const _Range(this.min, this.max);

  final double min;
  final double max;
}

const double idleMaxValue = 1.5;
