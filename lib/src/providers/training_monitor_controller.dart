import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chart_sample.dart';
import '../models/free_training_record.dart';
import '../models/training_plan.dart';
import '../models/training_record.dart';
import '../models/training_summary.dart';
import '../services/clock.dart';
import '../services/random_source.dart';
import 'free_training_record_provider.dart';
import 'system_providers.dart';
import 'training_monitor_state.dart';
import 'training_record_provider.dart';
import 'training_statistics_provider.dart';

final trainingMonitorControllerProvider =
    NotifierProvider.autoDispose.family<TrainingMonitorController, TrainingMonitorState, TrainingMonitorConfig>(
  TrainingMonitorController.new,
);

class TrainingMonitorController extends Notifier<TrainingMonitorState> {
  TrainingMonitorController(this._config);
  static const double sampleIntervalSeconds = 0.05;
  static const double idleMaxValue = 2.0;
  static const int prepareSeconds = 3;
  static const double emaAlpha = 0.25;
  static const double defaultChartMaxValue = 10.0;
  static const double freeTrainingWindowSeconds = 10.0;
  static const double freeTrainingMetricsWindowSeconds = 1.0;
  static const double freeTrainingQuantile = 0.99;
  static const double freeTrainingControlRatio = 0.95;

  late final RandomSource _randomSource;
  late final Clock _clock;
  Timer? _timer;

  final TrainingMonitorConfig _config;
  late int _freeTrainingMetricsWindowSampleCount;
  bool _recordSaved = false;
  bool _chartMaxFrozen = false;
  double _chartMaxValue = 0.0;
  bool _chartMaxLocked = false;
  double _chartMaxReachTime = 0.0;
  double _elapsedInPhase = 0.0;
  double _currentValue = 0.0;
  double _smoothedValue = 0.0;
  double _simulatedValue = 0.0;
  int _currentCycle = 1;
  double _workElapsedSeconds = 0.0;
  double _activeElapsedSeconds = 0.0;
  DateTime _trainingStartedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  final List<double> _workValues = <double>[];
  final List<TrainingSampleGroup> _groupedWorkSamples = <TrainingSampleGroup>[];
  List<TrainingSampleGroup>? _pendingGroupedSamples;

  double _vMax = 0.0;
  double _vMin = 0.0;
  int _stableCycleLimit = 0;
  double _instabilityRangeMin = 0.1;
  double _instabilityRangeMax = 0.2;
  bool _fatigueModeActive = false;
  bool _fatigueModeNext = false;
  double _cycleStartDuration = 0.0;
  double _cycleStartValue = 0.0;
  double _cycleUnstableStartTime = 0.0;
  bool _cycleHasUnstable = false;
  bool _fatigueWillDrop = false;
  double _fatigueDropStartTime = 0.0;
  double _fatigueDropDuration = 0.0;
  double _fatigueDropTarget = 0.0;
  double _fatigueDropStartValue = 0.0;
  bool _fatigueDropStarted = false;
  double _startupPendingDelta = 0.0;
  int _startupHoldRemaining = 0;
  double _descendingPendingDelta = 0.0;
  int _descendingHoldRemaining = 0;
  bool _unstableActive = false;

  List<ChartSample> _samples = <ChartSample>[];
  TrainingSummary? _summary;

  double _freeTrainingElapsedSeconds = 0.0;
  double _freeTrainingWindowStart = 0.0;
  double _freeTrainingMaxValue = 0.0;
  String _freeTrainingTitle = '自由训练';
  double _freeTrainingBaseValue = 0.0;
  double _freeTrainingNextBaseTime = 0.0;
  List<double> _freeTrainingAllSamples = <double>[];
  List<double> _freeTrainingWindowBuffer = <double>[];
  List<double> _freeTrainingWindowMeans = <double>[];
  List<double> _freeTrainingWindowDeltas = <double>[];
  double? _freeTrainingControlMaxValue;
  double? _freeTrainingLongestControlTimeSeconds;
  double? _freeTrainingCurrentWindowMeanValue;
  double? _freeTrainingCurrentWindowDeltaValue;
  double? _freeTrainingDeltaMaxValue;
  double? _freeTrainingDeltaMinValue;

  bool _isPaused = false;
  bool _isPreparing = true;
  bool _isWorking = true;
  bool _isFinishPending = false;
  bool _isSummaryVisible = false;

  @override
  TrainingMonitorState build() {
    _randomSource = ref.read(randomSourceProvider);
    _clock = ref.read(clockProvider);
    _freeTrainingMetricsWindowSampleCount = (freeTrainingMetricsWindowSeconds / sampleIntervalSeconds).round();
    if (_config.isFreeTraining) {
      _startFreeTraining();
    } else {
      _startPreparePhase();
    }
    _timer = Timer.periodic(
      Duration(milliseconds: (sampleIntervalSeconds * 1000).round()),
      (_) => _tick(),
    );
    ref.onDispose(_dispose);
    return _snapshot();
  }

  void _dispose() {
    _timer?.cancel();
  }

  TrainingMonitorState _snapshot() {
    return TrainingMonitorState(
      isFreeTraining: _config.isFreeTraining,
      isPreparing: _isPreparing,
      isWorking: _isWorking,
      isPaused: _isPaused,
      isFinishPending: _isFinishPending,
      isSummaryVisible: _isSummaryVisible,
      currentCycle: _currentCycle,
      elapsedInPhase: _elapsedInPhase,
      currentValue: _currentValue,
      chartMaxValue: _chartMaxValue,
      chartMaxLocked: _chartMaxLocked,
      chartMaxReachTime: _chartMaxReachTime,
      samples: List<ChartSample>.from(_samples),
      summary: _summary,
      freeTrainingElapsedSeconds: _freeTrainingElapsedSeconds,
      freeTrainingTitle: _freeTrainingTitle,
      freeTrainingControlMaxValue: _freeTrainingControlMaxValue,
      freeTrainingLongestControlTimeSeconds: _freeTrainingLongestControlTimeSeconds,
      freeTrainingCurrentWindowMeanValue: _freeTrainingCurrentWindowMeanValue,
      freeTrainingCurrentWindowDeltaValue: _freeTrainingCurrentWindowDeltaValue,
      freeTrainingDeltaMaxValue: _freeTrainingDeltaMaxValue,
      freeTrainingDeltaMinValue: _freeTrainingDeltaMinValue,
    );
  }

  void _emit() {
    state = _snapshot();
  }

  bool get _isDeviceConnected => _config.isDeviceConnected;
  TrainingPlanState get _plan => _config.plan;

  void togglePause() {
    _isPaused = !_isPaused;
    _emit();
  }

  void showSummary() {
    if (!_isFinishPending) {
      return;
    }
    _isFinishPending = false;
    _isSummaryVisible = true;
    _emit();
  }

  void resetFreeTraining() {
    _resetFreeTraining();
    _emit();
  }

  void goToPreviousAction() {
    if (_isPreparing) {
      return;
    }
    if (_isWorking) {
      if (_currentCycle == 1) {
        return;
      }
      _currentCycle -= 1;
      _startPhase(isWorking: false);
    } else {
      _startPhase(isWorking: true);
    }
    _emit();
  }

  void goToNextAction() {
    _advancePhase(_plan);
    _emit();
  }

  void prepareExitSummary() {
    if (_isPreparing) {
      return;
    }
    final completedCycles = _isWorking ? math.max(0, _currentCycle - 1) : _currentCycle;
    final totalSeconds = _activeElapsedSeconds.ceil();
    final groupedSamples = _groupedWorkSamples.take(completedCycles).toList();
    if (_isWorking && _isDeviceConnected) {
      _ensureCycleGroup();
      final currentGroup = _groupedWorkSamples[_currentCycle - 1];
      groupedSamples.add(currentGroup);
    }
    _summary = _buildSummary(
      _plan,
      groupedSamples,
      completedCycles: completedCycles,
      totalSecondsOverride: totalSeconds,
    );
    _pendingGroupedSamples = groupedSamples;
    _isSummaryVisible = true;
    _isFinishPending = false;
    _timer?.cancel();
    _emit();
  }

  void showFreeTrainingSummary() {
    _isSummaryVisible = true;
    _emit();
  }

  void hideSummary() {
    _isSummaryVisible = false;
    _emit();
  }

  void saveAndExit() {
    if (_summary == null) {
      return;
    }
    final groupedSamples = _pendingGroupedSamples ?? _groupedWorkSamples;
    _saveTrainingRecord(_plan, _summary!, groupedSamples: groupedSamples);
  }

  void saveFreeTraining(String title) {
    _saveFreeTrainingRecord(title);
  }

  void _tick() {
    if (_config.isFreeTraining) {
      _tickFreeTraining();
      return;
    }
    if (_isPaused || _isFinishPending || _isSummaryVisible) {
      return;
    }
    final plan = _plan;
    final phaseDuration = _isPreparing ? prepareSeconds : (_isWorking ? plan.workSeconds : plan.restSeconds);
    if (phaseDuration <= 0) {
      _advancePhase(plan);
      _emit();
      return;
    }

    _elapsedInPhase += sampleIntervalSeconds;
    if (!_isPreparing) {
      _activeElapsedSeconds += sampleIntervalSeconds;
    }
    final rawValue = _isDeviceConnected ? _nextSampleValue() : 0.0;
    _smoothedValue =
        _isDeviceConnected ? (emaAlpha * rawValue + (1 - emaAlpha) * _smoothedValue) : 0.0;
    _currentValue = _smoothedValue;
    if (_isDeviceConnected && _isWorking && !_isPreparing) {
      _workValues.add(_currentValue);
      _workElapsedSeconds += sampleIntervalSeconds;
      final sample = TrainingSample(time: _workElapsedSeconds, value: _currentValue);
      _ensureCycleGroup();
      _groupedWorkSamples.last.samples.add(sample);
    }
    if (_isDeviceConnected && _isWorking && !_isPreparing) {
      if (_currentCycle == 1 && !_chartMaxFrozen && _currentValue > _chartMaxValue) {
        _chartMaxValue = _roundToTenth(_currentValue);
        _chartMaxLocked = true;
        _chartMaxReachTime = _elapsedInPhase;
      }
    }
    if (_isDeviceConnected) {
      _samples = <ChartSample>[..._samples, ChartSample(time: _elapsedInPhase, value: _currentValue)];
      if (_samples.length > 600) {
        _samples = _samples.sublist(_samples.length - 600);
      }
    }

    if (_elapsedInPhase >= phaseDuration) {
      _advancePhase(plan);
    }
    _emit();
  }

  void _tickFreeTraining() {
    if (_isPaused || _isSummaryVisible) {
      return;
    }
    _elapsedInPhase += sampleIntervalSeconds;
    _freeTrainingElapsedSeconds += sampleIntervalSeconds;

    if (_isDeviceConnected) {
      final rawValue = _nextFreeTrainingSampleValue();
      _smoothedValue = emaAlpha * rawValue + (1 - emaAlpha) * _smoothedValue;
      _currentValue = _smoothedValue;
      if (_currentValue > _freeTrainingMaxValue) {
        _freeTrainingMaxValue = _currentValue;
      }
      _updateFreeTrainingMetrics(_currentValue);

      final windowStart = math.max(0.0, _freeTrainingElapsedSeconds - freeTrainingWindowSeconds);
      final windowShift = windowStart - _freeTrainingWindowStart;
      if (windowShift > 0) {
        _samples = _samples
            .map((sample) => ChartSample(time: sample.time - windowShift, value: sample.value))
            .where((sample) => sample.time >= 0)
            .toList();
        _freeTrainingWindowStart = windowStart;
      }
      _samples = <ChartSample>[
        ..._samples,
        ChartSample(time: _freeTrainingElapsedSeconds - windowStart, value: _currentValue),
      ];
      if (_samples.length > 300) {
        _samples = _samples.sublist(_samples.length - 300);
      }
      if (_currentValue > _chartMaxValue) {
        _chartMaxValue = _roundToTenth(_currentValue);
        _chartMaxLocked = true;
        _chartMaxReachTime = _elapsedInPhase;
      }
    }
    _emit();
  }

  void _advancePhase(TrainingPlanState plan) {
    final totalCycles = math.max(1, plan.cycles);
    if (_isPreparing) {
      _startPhase(isWorking: true);
      return;
    }
    if (_isWorking) {
      if (_currentCycle == 1 && !_chartMaxFrozen) {
        _chartMaxFrozen = true;
        _chartMaxLocked = true;
        _chartMaxReachTime = _elapsedInPhase;
      }
      if (_currentCycle >= totalCycles) {
        _completeTraining(plan);
        return;
      }
      if (plan.restSeconds > 0) {
        _startPhase(isWorking: false);
      } else {
        _finishCycle(plan);
      }
    } else {
      _finishCycle(plan);
    }
  }

  void _finishCycle(TrainingPlanState plan) {
    _currentCycle += 1;
    _startPhase(isWorking: true);
  }

  void _completeTraining(TrainingPlanState plan) {
    final totalSeconds = _activeElapsedSeconds.ceil();
    _summary = _buildSummary(plan, _groupedWorkSamples, totalSecondsOverride: totalSeconds);
    _pendingGroupedSamples = List<TrainingSampleGroup>.from(_groupedWorkSamples);
    _isFinishPending = true;
    _timer?.cancel();
  }

  void _startPhase({required bool isWorking}) {
    _isPreparing = false;
    _isWorking = isWorking;
    _elapsedInPhase = 0.0;
    _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
    if (isWorking) {
      _prepareWorkSimulation(phaseDurationSeconds: _plan.workSeconds.toDouble());
      if (_isDeviceConnected) {
        _ensureCycleGroup();
      }
    }
    _currentValue = 0.0;
    _smoothedValue = 0.0;
    _simulatedValue = 0.0;
  }

  void _startPreparePhase() {
    final plan = _plan;
    _isPreparing = true;
    _isWorking = true;
    _elapsedInPhase = 0.0;
    _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
    _currentValue = 0.0;
    _smoothedValue = 0.0;
    _simulatedValue = 0.0;
    _workValues.clear();
    _groupedWorkSamples.clear();
    _summary = null;
    _pendingGroupedSamples = null;
    _isFinishPending = false;
    _isSummaryVisible = false;
    _recordSaved = false;
    _workElapsedSeconds = 0.0;
    _activeElapsedSeconds = 0.0;
    _trainingStartedAt = _clock.now();
    _chartMaxValue = defaultChartMaxValue;
    _chartMaxLocked = true;
    _chartMaxReachTime = 0.0;
    _chartMaxFrozen = false;
    final totalCycles = math.max(1, plan.cycles);
    _prepareSessionSimulation(totalCycles: totalCycles);
  }

  void _startFreeTraining() {
    _isPreparing = false;
    _isWorking = true;
    _elapsedInPhase = 0.0;
    _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
    _currentValue = 0.0;
    _smoothedValue = 0.0;
    _simulatedValue = 0.0;
    _workValues.clear();
    _groupedWorkSamples.clear();
    _summary = null;
    _pendingGroupedSamples = null;
    _isFinishPending = false;
    _isSummaryVisible = false;
    _recordSaved = false;
    _workElapsedSeconds = 0.0;
    _activeElapsedSeconds = 0.0;
    _trainingStartedAt = _clock.now();
    _chartMaxValue = defaultChartMaxValue;
    _chartMaxLocked = true;
    _chartMaxReachTime = 0.0;
    _chartMaxFrozen = false;
    _freeTrainingElapsedSeconds = 0.0;
    _freeTrainingWindowStart = 0.0;
    _freeTrainingMaxValue = 0.0;
    _freeTrainingTitle = '自由训练';
    _freeTrainingBaseValue = 0.0;
    _freeTrainingNextBaseTime = 0.0;
    _resetFreeTrainingMetrics();
    _prepareSessionSimulation(totalCycles: 1);
    _prepareWorkSimulation(phaseDurationSeconds: freeTrainingWindowSeconds);
  }

  void _resetFreeTraining() {
    _elapsedInPhase = 0.0;
    _currentValue = 0.0;
    _smoothedValue = 0.0;
    _simulatedValue = 0.0;
    _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
    _freeTrainingElapsedSeconds = 0.0;
    _freeTrainingWindowStart = 0.0;
    _freeTrainingMaxValue = 0.0;
    _freeTrainingTitle = '自由训练';
    _freeTrainingBaseValue = 0.0;
    _freeTrainingNextBaseTime = 0.0;
    _resetFreeTrainingMetrics();
    _chartMaxValue = defaultChartMaxValue;
    _chartMaxLocked = true;
    _chartMaxReachTime = 0.0;
    _prepareWorkSimulation(phaseDurationSeconds: freeTrainingWindowSeconds);
  }

  double _nextSampleValue() {
    if (_isPreparing || !_isWorking) {
      final value = _randomInRange(0.0, idleMaxValue);
      _simulatedValue = value;
      return _roundToTenth(value);
    }
    final value = _fatigueModeActive ? _nextFatigueValue() : _nextWorkingValue();
    _simulatedValue = value;
    return _roundToTenth(value);
  }

  double _randomInRange(double min, double max) {
    if (max <= min) {
      return min;
    }
    return min + _randomSource.nextDouble() * (max - min);
  }

  double _roundToTenth(double value) {
    return (value * 10).roundToDouble() / 10;
  }

  void _prepareSessionSimulation({required int totalCycles}) {
    _vMax = _randomInRange(15.0, 50.0);
    _vMin = _vMax * _randomInRange(0.3, 0.5);
    final unstableRatio = _randomInRange(0.4, 0.6);
    _stableCycleLimit = math.max(1, (totalCycles * unstableRatio).round());
    _instabilityRangeMin = 0.1;
    _instabilityRangeMax = 0.2;
    _fatigueModeActive = false;
    _fatigueModeNext = false;
    _chartMaxValue = defaultChartMaxValue;
    _chartMaxLocked = true;
    _chartMaxReachTime = 0.0;
    _chartMaxFrozen = false;
  }

  void _prepareWorkSimulation({required double phaseDurationSeconds}) {
    _fatigueModeActive = _fatigueModeNext;
    _cycleStartDuration = _randomInRange(0.7, 1.3);
    _cycleStartValue = _fatigueModeActive ? _randomInRange(0.0, 0.5) : _randomInRange(0.0, idleMaxValue);
    _cycleHasUnstable = !_fatigueModeActive && _currentCycle > _stableCycleLimit;
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
    _fatigueWillDrop = _fatigueModeActive && _randomSource.nextDouble() < 0.3;
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
      final nextValue = math.max(_vMin, _simulatedValue - _randomInRange(0.3, 1.2));
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

  double _lerpValue(double start, double end, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return start + (end - start) * clampedT;
  }

  double _nextStartupSample({required double targetValue}) {
    if (_cycleStartDuration <= 0) {
      return targetValue;
    }
    if (_startupHoldRemaining == 0) {
      _startupHoldRemaining = _randomSource.nextInt(4);
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
    final minValue = math.min(_simulatedValue, targetValue);
    final maxValue = math.max(_simulatedValue, targetValue);
    return (_simulatedValue + appliedDelta).clamp(minValue, maxValue);
  }

  double _nextDescendingSample({required double targetValue}) {
    if (_descendingHoldRemaining == 0) {
      _descendingHoldRemaining = _randomSource.nextInt(4);
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
    final minValue = math.min(_simulatedValue, targetValue);
    final maxValue = math.max(_simulatedValue, targetValue);
    return (_simulatedValue + appliedDelta).clamp(minValue, maxValue);
  }

  double _nextFreeTrainingSampleValue() {
    const baseMin = 10.0;
    const baseMax = 60.0;
    const baseIntervalSeconds = 5.0;
    if (_freeTrainingBaseValue <= 0) {
      _freeTrainingBaseValue = _randomInRange(baseMin, baseMax);
      _freeTrainingNextBaseTime = baseIntervalSeconds;
      _simulatedValue = _freeTrainingBaseValue;
    }
    while (_freeTrainingElapsedSeconds >= _freeTrainingNextBaseTime) {
      _freeTrainingBaseValue = _randomInRange(baseMin, baseMax);
      _freeTrainingNextBaseTime += baseIntervalSeconds;
    }
    if (_freeTrainingNextBaseTime <= _freeTrainingElapsedSeconds) {
      _freeTrainingNextBaseTime = _freeTrainingElapsedSeconds + baseIntervalSeconds;
    }
    final rangeMin = _freeTrainingBaseValue * 0.8;
    final rangeMax = _freeTrainingBaseValue * 1.2;
    final targetValue = _randomInRange(rangeMin, rangeMax);
    final previousValue = _simulatedValue > 0 ? _simulatedValue : _freeTrainingBaseValue;
    final maxStep = previousValue * 0.05;
    double nextValue;
    if ((targetValue - previousValue).abs() <= maxStep) {
      nextValue = targetValue;
    } else {
      nextValue = previousValue + (targetValue > previousValue ? maxStep : -maxStep);
    }
    nextValue = nextValue.clamp(rangeMin, rangeMax);
    _simulatedValue = nextValue;
    return _roundToTenth(nextValue);
  }

  void _resetFreeTrainingMetrics() {
    _freeTrainingAllSamples = <double>[];
    _freeTrainingWindowBuffer = <double>[];
    _freeTrainingWindowMeans = <double>[];
    _freeTrainingWindowDeltas = <double>[];
    _freeTrainingControlMaxValue = null;
    _freeTrainingLongestControlTimeSeconds = null;
    _freeTrainingCurrentWindowMeanValue = null;
    _freeTrainingCurrentWindowDeltaValue = null;
    _freeTrainingDeltaMaxValue = null;
    _freeTrainingDeltaMinValue = null;
  }

  void _updateFreeTrainingMetrics(double value) {
    _freeTrainingAllSamples.add(value);
    _freeTrainingWindowBuffer.add(value);
    if (_freeTrainingWindowBuffer.length < _freeTrainingMetricsWindowSampleCount) {
      return;
    }
    final windowSum = _freeTrainingWindowBuffer.fold<double>(0.0, (sum, item) => sum + item);
    final windowMean = windowSum / _freeTrainingWindowBuffer.length;
    _freeTrainingWindowMeans.add(windowMean);
    _freeTrainingCurrentWindowMeanValue = windowMean;
    if (_freeTrainingWindowMeans.length > 1) {
      final previousMean = _freeTrainingWindowMeans[_freeTrainingWindowMeans.length - 2];
      final delta = windowMean - previousMean;
      _freeTrainingWindowDeltas.add(delta);
      _freeTrainingCurrentWindowDeltaValue = delta;
    }
    _freeTrainingWindowBuffer.clear();
    _recalculateFreeTrainingMetrics();
  }

  void _recalculateFreeTrainingMetrics() {
    if (_freeTrainingAllSamples.isEmpty) {
      _resetFreeTrainingMetrics();
      return;
    }
    final sortedAllSamples = List<double>.from(_freeTrainingAllSamples)..sort();
    final robustMaxValue = _quantileSorted(sortedAllSamples, freeTrainingQuantile);
    final controlThreshold = robustMaxValue * freeTrainingControlRatio;
    final controlSamples = _freeTrainingAllSamples.where((value) => value >= controlThreshold).toList();
    if (controlSamples.isEmpty) {
      _freeTrainingControlMaxValue = null;
      _freeTrainingLongestControlTimeSeconds = null;
    } else {
      final sortedControlSamples = List<double>.from(controlSamples)..sort();
      final controlMax = _medianSorted(sortedControlSamples);
      _freeTrainingControlMaxValue = controlMax;
      final controlFloor = controlMax * freeTrainingControlRatio;
      final longestControlTimeSeconds = _resolveMaxConsecutiveSeconds(_freeTrainingAllSamples, controlFloor);
      _freeTrainingLongestControlTimeSeconds = longestControlTimeSeconds;
    }

    if (_freeTrainingWindowDeltas.isEmpty) {
      _freeTrainingDeltaMaxValue = null;
      _freeTrainingDeltaMinValue = null;
    } else {
      final sortedDeltas = List<double>.from(_freeTrainingWindowDeltas)..sort();
      _freeTrainingDeltaMaxValue = sortedDeltas.last;
      _freeTrainingDeltaMinValue = sortedDeltas.first;
    }
  }

  double _medianSorted(List<double> sortedValues) {
    final count = sortedValues.length;
    if (count == 0) {
      return 0.0;
    }
    final mid = count ~/ 2;
    if (count.isOdd) {
      return sortedValues[mid];
    }
    return (sortedValues[mid - 1] + sortedValues[mid]) / 2;
  }

  double _quantileSorted(List<double> sortedValues, double quantile) {
    if (sortedValues.isEmpty) {
      return 0.0;
    }
    final position = (sortedValues.length - 1) * quantile;
    final lowerIndex = position.floor();
    final upperIndex = position.ceil();
    if (lowerIndex == upperIndex) {
      return sortedValues[lowerIndex];
    }
    final lower = sortedValues[lowerIndex];
    final upper = sortedValues[upperIndex];
    final weight = position - lowerIndex;
    return lower + (upper - lower) * weight;
  }

  double _resolveMaxConsecutiveSeconds(List<double> samples, double threshold) {
    var longest = 0;
    var current = 0;
    for (final value in samples) {
      if (value >= threshold) {
        current += 1;
        if (current > longest) {
          longest = current;
        }
      } else {
        current = 0;
      }
    }
    return longest * sampleIntervalSeconds;
  }

  TrainingSummary _buildSummary(
    TrainingPlanState plan,
    List<TrainingSampleGroup> groupedSamples, {
    int? completedCycles,
    int? totalSecondsOverride,
  }) {
    final resolvedCycles = completedCycles ?? plan.cycles;
    final calculator = ref.read(trainingStatisticsCalculatorProvider);
    final statistics = calculator.calculate(
      groupedSamples: groupedSamples,
      workSeconds: plan.workSeconds,
      sampleIntervalSeconds: sampleIntervalSeconds,
    );
    final restCycles = resolvedCycles > 0 ? resolvedCycles - 1 : 0;
    final totalSeconds = totalSecondsOverride ?? plan.workSeconds * resolvedCycles + plan.restSeconds * restCycles;
    return TrainingSummary(
      planName: plan.name,
      workSeconds: plan.workSeconds,
      restSeconds: plan.restSeconds,
      cycles: resolvedCycles,
      totalSeconds: totalSeconds,
      statistics: statistics,
      hasStatistics: groupedSamples.isNotEmpty,
    );
  }

  void _saveTrainingRecord(
    TrainingPlanState plan,
    TrainingSummary summary, {
    List<TrainingSampleGroup>? groupedSamples,
  }) {
    if (_recordSaved) {
      return;
    }
    final resolvedGroups = groupedSamples ?? _groupedWorkSamples;
    final record = TrainingRecord(
      id: _trainingStartedAt.microsecondsSinceEpoch.toString(),
      planName: plan.name,
      workSeconds: plan.workSeconds,
      restSeconds: plan.restSeconds,
      cycles: summary.cycles,
      totalSeconds: summary.totalSeconds,
      startedAt: _trainingStartedAt,
      groupedSamples: List<TrainingSampleGroup>.from(resolvedGroups),
      statistics: summary.statistics,
    );
    ref.read(trainingRecordProvider.notifier).addRecord(record);
    _recordSaved = true;
  }

  void _saveFreeTrainingRecord(String title) {
    final record = FreeTrainingRecord(
      id: _trainingStartedAt.microsecondsSinceEpoch.toString(),
      title: title,
      totalSeconds: _freeTrainingElapsedSeconds,
      startedAt: _trainingStartedAt,
      controlMaxValue: _freeTrainingControlMaxValue,
      longestControlTimeSeconds: _freeTrainingLongestControlTimeSeconds,
      currentWindowMeanValue: _freeTrainingCurrentWindowMeanValue,
      currentWindowDeltaValue: _freeTrainingCurrentWindowDeltaValue,
      deltaMaxValue: _freeTrainingDeltaMaxValue,
      deltaMinValue: _freeTrainingDeltaMinValue,
      samples: _downsampleFreeTrainingSamples(_freeTrainingAllSamples),
    );
    ref.read(freeTrainingRecordProvider.notifier).addRecord(record);
  }

  List<double> _downsampleFreeTrainingSamples(List<double> samples, {int maxPoints = 120}) {
    if (samples.isEmpty) {
      return <double>[];
    }
    if (samples.length <= maxPoints) {
      return List<double>.from(samples);
    }
    final step = (samples.length - 1) / (maxPoints - 1);
    final output = <double>[];
    for (int i = 0; i < maxPoints; i++) {
      final index = (i * step).round().clamp(0, samples.length - 1);
      output.add(samples[index]);
    }
    return output;
  }

  void _ensureCycleGroup() {
    if (_groupedWorkSamples.length >= _currentCycle) {
      return;
    }
    _groupedWorkSamples.add(TrainingSampleGroup(cycle: _currentCycle, samples: <TrainingSample>[]));
  }
}
