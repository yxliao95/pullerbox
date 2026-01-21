import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/free_training_record.dart';
import '../../../models/training_plan.dart';
import '../../../models/training_record.dart';
import '../../../provider/free_training_record_provider.dart';
import '../../../provider/training_plan_provider.dart';
import '../../../provider/training_record_provider.dart';
import '../../../provider/training_statistics_provider.dart';
import 'widgets/measure_size.dart';
import 'widgets/monitor_chart.dart';
import 'widgets/monitor_progress_bar.dart';
import 'widgets/monitor_summary_overlay.dart';
import 'widgets/monitor_toolbar.dart';
import 'widgets/free_training_data_panel.dart';
import 'widgets/free_training_summary_overlay.dart';

class TrainingMonitorPage extends ConsumerStatefulWidget {
  const TrainingMonitorPage({required this.isDeviceConnected, super.key});

  final bool isDeviceConnected;

  @override
  ConsumerState<TrainingMonitorPage> createState() => _TrainingMonitorPageState();
}

class _TrainingMonitorPageState extends ConsumerState<TrainingMonitorPage> with SingleTickerProviderStateMixin {
  static const double _sampleIntervalSeconds = 0.05;
  static const double _renderLagSeconds = 0.03;
  static const double _idleMaxValue = 2.0;
  static const int _prepareSeconds = 3;
  static const double _emaAlpha = 0.25;
  static const double _estimatedToolbarWidth = 136.0;
  static const double _defaultChartMaxValue = 10.0;
  static const double _chartMaxTweenSpeed = 6.0;
  static const double _freeTrainingWindowSeconds = 10.0;
  static const double _freeTrainingMetricsWindowSeconds = 1.0;
  static const double _freeTrainingQuantile = 0.99;
  static const double _freeTrainingControlRatio = 0.95;
  late final int _freeTrainingMetricsWindowSampleCount;
  final math.Random _random = math.Random();
  final ValueNotifier<double> _displayTime = ValueNotifier<double>(0.0);

  Timer? _timer;
  late final Ticker _ticker;
  Duration _lastFrameTimestamp = Duration.zero;
  bool _isPaused = false;
  bool _isSoundOn = true;
  bool _isPreparing = true;
  bool _isWorking = true;
  bool _isFinishPending = false;
  bool _isSummaryVisible = false;
  bool _recordSaved = false;
  bool _isFreeTraining = false;
  int _currentCycle = 1;
  double _elapsedInPhase = 0.0;
  double _currentValue = 0.0;
  double _smoothedValue = 0.0;
  double _simulatedValue = 0.0;
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
  double _chartMaxValue = 0.0;
  double _chartMaxAnimatedValue = 0.0;
  bool _chartMaxLocked = false;
  double _chartMaxReachTime = 0.0;
  bool _chartMaxFrozen = false;
  List<ChartSample> _samples = <ChartSample>[];
  List<double> _workValues = <double>[];
  List<TrainingSampleGroup> _groupedWorkSamples = <TrainingSampleGroup>[];
  List<TrainingSampleGroup>? _pendingGroupedSamples;
  TrainingSummary? _summary;
  double _toolbarHorizontalWidth = 0.0;
  double _exitButtonHeight = 0.0;
  double _freeTrainingPanelWidth = 160.0;
  double _workElapsedSeconds = 0.0;
  double _activeElapsedSeconds = 0.0;
  DateTime _trainingStartedAt = DateTime.now();
  double _freeTrainingElapsedSeconds = 0.0;
  double _freeTrainingWindowStart = 0.0;
  double _freeTrainingValueSum = 0.0;
  double _freeTrainingMaxValue = 0.0;
  int _freeTrainingSampleCount = 0;
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

  @override
  void initState() {
    super.initState();
    _freeTrainingTitle = '自由训练';
    _freeTrainingMetricsWindowSampleCount = (_freeTrainingMetricsWindowSeconds / _sampleIntervalSeconds).round();
    _isFreeTraining = ref.read(trainingPlanLibraryProvider).isFreeTraining;
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (_isFreeTraining) {
      _startFreeTraining();
    } else {
      _startPreparePhase();
    }
    _ticker = createTicker(_onFrame)..start();
    _timer = Timer.periodic(Duration(milliseconds: (_sampleIntervalSeconds * 1000).round()), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker.dispose();
    _displayTime.dispose();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    if (_isPaused) {
      _lastFrameTimestamp = Duration.zero;
      return;
    }
    if (_lastFrameTimestamp == Duration.zero) {
      _lastFrameTimestamp = elapsed;
      return;
    }
    final deltaSeconds = (elapsed - _lastFrameTimestamp).inMicroseconds / 1000000.0;
    _lastFrameTimestamp = elapsed;
    if (deltaSeconds <= 0) {
      return;
    }
    final lagSeconds = _isFinishPending ? 0.0 : _renderLagSeconds;
    final rawTargetTime = (_elapsedInPhase - lagSeconds).clamp(0.0, double.infinity);
    final targetTime = _isFreeTraining
        ? math.min(rawTargetTime, _freeTrainingWindowSeconds)
        : rawTargetTime.clamp(0.0, _elapsedInPhase);
    final nextDisplayTime = math.min(_displayTime.value + deltaSeconds, targetTime);
    if (nextDisplayTime != _displayTime.value) {
      _displayTime.value = nextDisplayTime;
    }
    if (_chartMaxAnimatedValue != _chartMaxValue) {
      final delta = _chartMaxValue - _chartMaxAnimatedValue;
      final step = delta * math.min(1.0, _chartMaxTweenSpeed * deltaSeconds);
      _chartMaxAnimatedValue += step;
      if ((_chartMaxValue - _chartMaxAnimatedValue).abs() < 0.01) {
        _chartMaxAnimatedValue = _chartMaxValue;
      }
      setState(() {});
    }
    if (_isFinishPending && _displayTime.value >= _elapsedInPhase) {
      setState(() {
        _isFinishPending = false;
        _isSummaryVisible = true;
      });
    }
  }

  void _tick() {
    if (_isFreeTraining) {
      _tickFreeTraining();
      return;
    }
    if (_isPaused || _isFinishPending || _isSummaryVisible) {
      return;
    }
    final isOfflineMode = !widget.isDeviceConnected;
    final plan = ref.read(trainingPlanProvider);
    final phaseDuration = _isPreparing ? _prepareSeconds : (_isWorking ? plan.workSeconds : plan.restSeconds);
    if (phaseDuration <= 0) {
      _advancePhase(plan);
      return;
    }

    _elapsedInPhase += _sampleIntervalSeconds;
    if (!_isPreparing) {
      _activeElapsedSeconds += _sampleIntervalSeconds;
    }
    final rawValue = isOfflineMode ? 0.0 : _nextSampleValue();
    _smoothedValue = isOfflineMode ? 0.0 : (_emaAlpha * rawValue + (1 - _emaAlpha) * _smoothedValue);
    _currentValue = _smoothedValue;
    if (!isOfflineMode && _isWorking && !_isPreparing) {
      _workValues.add(_currentValue);
      _workElapsedSeconds += _sampleIntervalSeconds;
      final sample = TrainingSample(time: _workElapsedSeconds, value: _currentValue);
      _ensureCycleGroup();
      _groupedWorkSamples.last.samples.add(sample);
    }
    if (!isOfflineMode && _isWorking && !_isPreparing) {
      if (_currentCycle == 1 && !_chartMaxFrozen && _currentValue > _chartMaxValue) {
        _chartMaxValue = _roundToTenth(_currentValue);
        if (_chartMaxAnimatedValue <= 0) {
          _chartMaxAnimatedValue = _chartMaxValue;
        }
        _chartMaxLocked = true;
        _chartMaxReachTime = _displayTime.value;
      }
    }
    if (!isOfflineMode) {
      _samples = <ChartSample>[..._samples, ChartSample(time: _elapsedInPhase, value: _currentValue)];
      if (_samples.length > 600) {
        _samples = _samples.sublist(_samples.length - 600);
      }
    }

    if (_elapsedInPhase >= phaseDuration) {
      _advancePhase(plan);
    }
    setState(() {});
  }

  void _tickFreeTraining() {
    if (_isPaused || _isSummaryVisible) {
      return;
    }
    final isOfflineMode = !widget.isDeviceConnected;
    _elapsedInPhase += _sampleIntervalSeconds;
    _freeTrainingElapsedSeconds += _sampleIntervalSeconds;

    if (!isOfflineMode) {
      final rawValue = _nextFreeTrainingSampleValue();
      _smoothedValue = _emaAlpha * rawValue + (1 - _emaAlpha) * _smoothedValue;
      _currentValue = _smoothedValue;
      _freeTrainingSampleCount += 1;
      _freeTrainingValueSum += _currentValue;
      if (_currentValue > _freeTrainingMaxValue) {
        _freeTrainingMaxValue = _currentValue;
      }
      _updateFreeTrainingMetrics(_currentValue);

      final windowStart = math.max(0.0, _freeTrainingElapsedSeconds - _freeTrainingWindowSeconds);
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
        if (_chartMaxAnimatedValue <= 0) {
          _chartMaxAnimatedValue = _chartMaxValue;
        }
        _chartMaxLocked = true;
        _chartMaxReachTime = _displayTime.value;
      }
    }
    setState(() {});
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
        _chartMaxReachTime = _displayTime.value;
        _chartMaxAnimatedValue = _chartMaxValue;
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
    final isOfflineMode = !widget.isDeviceConnected;
    _isPreparing = false;
    _isWorking = isWorking;
    _elapsedInPhase = 0.0;
    _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
    _displayTime.value = 0.0;
    _lastFrameTimestamp = Duration.zero;
    if (isWorking) {
      _prepareWorkSimulation(phaseDurationSeconds: ref.read(trainingPlanProvider).workSeconds.toDouble());
      if (!isOfflineMode) {
        _ensureCycleGroup();
      }
    }
    _currentValue = 0.0;
    _smoothedValue = 0.0;
    _simulatedValue = 0.0;
  }

  void _startPreparePhase() {
    final plan = ref.read(trainingPlanProvider);
    _isPreparing = true;
    _isWorking = true;
    _elapsedInPhase = 0.0;
    _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
    _displayTime.value = 0.0;
    _lastFrameTimestamp = Duration.zero;
    _currentValue = 0.0;
    _smoothedValue = 0.0;
    _simulatedValue = 0.0;
    _workValues = <double>[];
    _groupedWorkSamples = <TrainingSampleGroup>[];
    _summary = null;
    _pendingGroupedSamples = null;
    _isFinishPending = false;
    _isSummaryVisible = false;
    _recordSaved = false;
    _workElapsedSeconds = 0.0;
    _activeElapsedSeconds = 0.0;
    _trainingStartedAt = DateTime.now();
    _chartMaxValue = _defaultChartMaxValue;
    _chartMaxAnimatedValue = _chartMaxValue;
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
    _displayTime.value = 0.0;
    _lastFrameTimestamp = Duration.zero;
    _currentValue = 0.0;
    _smoothedValue = 0.0;
    _simulatedValue = 0.0;
    _workValues = <double>[];
    _groupedWorkSamples = <TrainingSampleGroup>[];
    _summary = null;
    _pendingGroupedSamples = null;
    _isFinishPending = false;
    _isSummaryVisible = false;
    _recordSaved = false;
    _workElapsedSeconds = 0.0;
    _activeElapsedSeconds = 0.0;
    _trainingStartedAt = DateTime.now();
    _chartMaxValue = _defaultChartMaxValue;
    _chartMaxAnimatedValue = _chartMaxValue;
    _chartMaxLocked = true;
    _chartMaxReachTime = 0.0;
    _chartMaxFrozen = false;
    _freeTrainingElapsedSeconds = 0.0;
    _freeTrainingWindowStart = 0.0;
    _freeTrainingValueSum = 0.0;
    _freeTrainingMaxValue = 0.0;
    _freeTrainingSampleCount = 0;
    _freeTrainingTitle = '自由训练';
    _freeTrainingBaseValue = 0.0;
    _freeTrainingNextBaseTime = 0.0;
    _resetFreeTrainingMetrics();
    _prepareSessionSimulation(totalCycles: 1);
    _prepareWorkSimulation(phaseDurationSeconds: _freeTrainingWindowSeconds);
  }

  double _nextSampleValue() {
    if (_isPreparing || !_isWorking) {
      final value = _randomInRange(0.0, _idleMaxValue);
      _simulatedValue = value;
      return _roundToTenth(value);
    }
    final value = _fatigueModeActive ? _nextFatigueValue() : _nextWorkingValue();
    _simulatedValue = value;
    return _roundToTenth(value);
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

  double _randomInRange(double min, double max) {
    if (max <= min) {
      return min;
    }
    return min + _random.nextDouble() * (max - min);
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
    _chartMaxValue = _defaultChartMaxValue;
    _chartMaxAnimatedValue = _chartMaxValue;
    _chartMaxLocked = true;
    _chartMaxReachTime = 0.0;
    _chartMaxFrozen = false;
  }

  void _prepareWorkSimulation({required double phaseDurationSeconds}) {
    _fatigueModeActive = _fatigueModeNext;
    _cycleStartDuration = _randomInRange(0.7, 1.3);
    _cycleStartValue = _fatigueModeActive ? _randomInRange(0.0, 0.5) : _randomInRange(0.0, _idleMaxValue);
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
    _fatigueWillDrop = _fatigueModeActive && _random.nextDouble() < 0.3;
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
      final nextProgress = ((time + _sampleIntervalSeconds - _fatigueDropStartTime) / _fatigueDropDuration).clamp(
        0.0,
        1.0,
      );
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
      _startupHoldRemaining = _random.nextInt(4);
    }
    final nextTime = (_elapsedInPhase + _sampleIntervalSeconds).clamp(0.0, _cycleStartDuration);
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
      _descendingHoldRemaining = _random.nextInt(4);
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

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
    if (!_isPaused) {
      _lastFrameTimestamp = Duration.zero;
    }
  }

  void _resetFreeTraining() {
    setState(() {
      _elapsedInPhase = 0.0;
      _displayTime.value = 0.0;
      _lastFrameTimestamp = Duration.zero;
      _currentValue = 0.0;
      _smoothedValue = 0.0;
      _simulatedValue = 0.0;
      _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
      _freeTrainingElapsedSeconds = 0.0;
      _freeTrainingWindowStart = 0.0;
      _freeTrainingValueSum = 0.0;
      _freeTrainingMaxValue = 0.0;
      _freeTrainingSampleCount = 0;
      _freeTrainingTitle = '自由训练';
      _freeTrainingBaseValue = 0.0;
      _freeTrainingNextBaseTime = 0.0;
      _resetFreeTrainingMetrics();
      _chartMaxValue = _defaultChartMaxValue;
      _chartMaxAnimatedValue = _chartMaxValue;
      _chartMaxLocked = true;
      _chartMaxReachTime = 0.0;
      _prepareWorkSimulation(phaseDurationSeconds: _freeTrainingWindowSeconds);
    });
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
    final robustMaxValue = _quantileSorted(sortedAllSamples, _freeTrainingQuantile);
    final controlThreshold = robustMaxValue * _freeTrainingControlRatio;
    final controlSamples = _freeTrainingAllSamples.where((value) => value >= controlThreshold).toList();
    if (controlSamples.isEmpty) {
      _freeTrainingControlMaxValue = null;
      _freeTrainingLongestControlTimeSeconds = null;
    } else {
      final sortedControlSamples = List<double>.from(controlSamples)..sort();
      final controlMax = _medianSorted(sortedControlSamples);
      _freeTrainingControlMaxValue = controlMax;
      final controlFloor = controlMax * _freeTrainingControlRatio;
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
    return longest * _sampleIntervalSeconds;
  }

  void _toggleSound() {
    setState(() {
      _isSoundOn = !_isSoundOn;
    });
  }

  void _goToPreviousAction() {
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
    setState(() {});
  }

  void _goToNextAction() {
    final plan = ref.read(trainingPlanProvider);
    _advancePhase(plan);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_isFreeTraining) {
      return _buildFreeTraining(context);
    }
    final plan = ref.watch(trainingPlanProvider);
    final totalCycles = math.max(1, plan.cycles);
    final phaseDuration = _isPreparing ? _prepareSeconds : (_isWorking ? plan.workSeconds : plan.restSeconds);
    const workColor = Color(0xFF2AC41F);
    const restColor = Color(0xFFFF4B4B);
    const prepareColor = Color(0xFF3B7CFF);
    final progressColor = _isWorking ? workColor : restColor;
    final phaseColor = _isPreparing ? prepareColor : progressColor;

    final isOfflineMode = !widget.isDeviceConnected;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      if (!isOfflineMode)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: MonitorChartPanel(
                              samples: _samples,
                              displayTimeListenable: _displayTime,
                              isPreparing: _isPreparing,
                              isWorking: _isWorking,
                              targetMaxValue: _chartMaxAnimatedValue,
                              isMaxLineLocked: _chartMaxLocked,
                              maxLineLockTime: _chartMaxReachTime,
                              phaseDuration: phaseDuration.toDouble(),
                              rightInset: 8.0,
                            ),
                          ),
                        ),
                      if (!isOfflineMode)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              width: 110,
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                              child: Align(
                                alignment: Alignment.center,
                                heightFactor: 1,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    RichText(
                                      text: TextSpan(
                                        children: <TextSpan>[
                                          TextSpan(
                                            text: _currentValue.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.black,
                                            ),
                                          ),
                                          TextSpan(
                                            text: ' kg',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_chartMaxValue <= 0 ? 0 : (_currentValue / _chartMaxValue * 100).round()}%',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (isOfflineMode && _isWorking && !_isPreparing)
                        const Center(
                          child: Text(
                            '锻炼',
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: workColor),
                          ),
                        ),
                      if (_isPreparing)
                        const Center(
                          child: Text(
                            '准备',
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: prepareColor),
                          ),
                        )
                      else if (!_isWorking)
                        const Center(
                          child: Text(
                            '休息',
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: restColor),
                          ),
                        ),
                    ],
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: _displayTime,
                  builder: (context, displayTime, _) {
                    final clampedTime = displayTime.clamp(0.0, _elapsedInPhase);
                    final phaseProgress = phaseDuration <= 0 ? 0.0 : (clampedTime / phaseDuration).clamp(0.0, 1.0);
                    final remainingSeconds = phaseDuration <= 0
                        ? 0
                        : (phaseDuration - clampedTime).ceil().clamp(0, phaseDuration);
                    return MonitorProgressBar(progress: phaseProgress, color: phaseColor, label: '$remainingSeconds 秒');
                  },
                ),
              ],
            ),
            if (_isSummaryVisible && _summary != null)
              Positioned.fill(
                child: MonitorSummaryOverlay(
                  summary: _summary!,
                  showStatistics: !isOfflineMode,
                  onExitWithoutSave: _exitWithoutSave,
                  onSaveAndExit: _saveAndExit,
                ),
              )
            else
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const exitButtonWidth = 36.0;
                      const minTitleGap = 8.0;
                      final titleText = '循环 $_currentCycle / $totalCycles';
                      final textScaler = MediaQuery.textScalerOf(context);
                      final titlePainter = TextPainter(
                        text: TextSpan(
                          text: titleText,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        textDirection: TextDirection.ltr,
                        textScaler: textScaler,
                      )..layout();
                      final resolvedToolbarWidth = _toolbarHorizontalWidth > 0
                          ? _toolbarHorizontalWidth
                          : _estimatedToolbarWidth;
                      final maxReserved = math.max(exitButtonWidth, resolvedToolbarWidth);
                      final availableCenterWidth = (constraints.maxWidth - 2 * maxReserved - minTitleGap * 2).clamp(
                        0.0,
                        constraints.maxWidth,
                      );
                      final isToolbarVertical = titlePainter.width > availableCenterWidth;
                      final resolvedExitHeight = _exitButtonHeight > 0 ? _exitButtonHeight : exitButtonWidth;
                      return Stack(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: MeasureSize(
                              onChange: (size) {
                                if (size.height != _exitButtonHeight) {
                                  setState(() {
                                    _exitButtonHeight = size.height;
                                  });
                                }
                              },
                              child: _ExitButton(onPressed: _handleExit),
                            ),
                          ),
                          Center(
                            child: SizedBox(
                              height: resolvedExitHeight,
                              child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                  titleText,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: isToolbarVertical
                                ? MonitorToolbar(
                                    isSoundOn: _isSoundOn,
                                    isPaused: _isPaused,
                                    isVertical: true,
                                    onToggleSound: _toggleSound,
                                    onPrevious: _goToPreviousAction,
                                    onTogglePause: _togglePause,
                                    onNext: _goToNextAction,
                                  )
                                : MeasureSize(
                                    onChange: (size) {
                                      if (size.width != _toolbarHorizontalWidth) {
                                        setState(() {
                                          _toolbarHorizontalWidth = size.width;
                                        });
                                      }
                                    },
                                    child: MonitorToolbar(
                                      isSoundOn: _isSoundOn,
                                      isPaused: _isPaused,
                                      isVertical: false,
                                      onToggleSound: _toggleSound,
                                      onPrevious: _goToPreviousAction,
                                      onTogglePause: _togglePause,
                                      onNext: _goToNextAction,
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFreeTraining(BuildContext context) {
    const workColor = Color(0xFF2AC41F);
    const fallbackPanelWidth = 160.0;
    const panelPadding = 16.0;
    const chartRightPadding = 16.0;
    final isOfflineMode = !widget.isDeviceConnected;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final panelWidth = _freeTrainingPanelWidth > 0 ? _freeTrainingPanelWidth : fallbackPanelWidth;
    final rightInset = (isPortrait ? 0.0 : panelWidth + panelPadding) + chartRightPadding;
    final chartStack = Stack(
      children: <Widget>[
        if (!isOfflineMode)
          Positioned.fill(
            child: RepaintBoundary(
              child: MonitorChartPanel(
                samples: _samples,
                displayTimeListenable: _displayTime,
                isPreparing: false,
                isWorking: true,
                targetMaxValue: _chartMaxAnimatedValue,
                isMaxLineLocked: _chartMaxLocked,
                maxLineLockTime: _chartMaxReachTime,
                phaseDuration: _freeTrainingWindowSeconds,
                rightInset: rightInset,
              ),
            ),
          ),
        if (!isOfflineMode)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: 110,
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: Align(
                  alignment: Alignment.center,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        RichText(
                          text: TextSpan(
                            children: <TextSpan>[
                              TextSpan(
                                text: _currentValue.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
                              ),
                              TextSpan(
                                text: ' kg',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_chartMaxValue <= 0 ? 0 : (_currentValue / _chartMaxValue * 100).round()}%',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (isOfflineMode)
          const Center(
            child: Text(
              '自由训练',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: workColor),
            ),
          ),
        Positioned(top: 8, left: 16, child: _ExitButton(onPressed: _handleExit)),
      ],
    );
    final mainContent = isPortrait
        ? Column(
            children: <Widget>[
              Expanded(child: chartStack),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FreeTrainingDataPanel(
                  width: double.infinity,
                  totalSeconds: _freeTrainingElapsedSeconds,
                  controlMaxValue: _freeTrainingControlMaxValue,
                  longestControlTimeSeconds: _freeTrainingLongestControlTimeSeconds,
                  currentWindowMeanValue: _freeTrainingCurrentWindowMeanValue,
                  currentWindowDeltaValue: _freeTrainingCurrentWindowDeltaValue,
                  deltaMaxValue: _freeTrainingDeltaMaxValue,
                  deltaMinValue: _freeTrainingDeltaMinValue,
                  isDeviceConnected: widget.isDeviceConnected,
                  isPaused: _isPaused,
                  onReset: _resetFreeTraining,
                  onTogglePause: _togglePause,
                ),
              ),
            ],
          )
        : Stack(
            children: <Widget>[
              Positioned.fill(child: chartStack),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: panelPadding),
                  child: MeasureSize(
                    onChange: (size) {
                      if (size.width != _freeTrainingPanelWidth) {
                        setState(() {
                          _freeTrainingPanelWidth = size.width;
                        });
                      }
                    },
                    child: FreeTrainingDataPanel(
                      totalSeconds: _freeTrainingElapsedSeconds,
                      controlMaxValue: _freeTrainingControlMaxValue,
                      longestControlTimeSeconds: _freeTrainingLongestControlTimeSeconds,
                      currentWindowMeanValue: _freeTrainingCurrentWindowMeanValue,
                      currentWindowDeltaValue: _freeTrainingCurrentWindowDeltaValue,
                      deltaMaxValue: _freeTrainingDeltaMaxValue,
                      deltaMinValue: _freeTrainingDeltaMinValue,
                      isDeviceConnected: widget.isDeviceConnected,
                      isPaused: _isPaused,
                      onReset: _resetFreeTraining,
                      onTogglePause: _togglePause,
                    ),
                  ),
                ),
              ),
            ],
          );
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            mainContent,
            if (_isSummaryVisible)
              Positioned.fill(
                child: FreeTrainingSummaryOverlay(
                  defaultTitle: _freeTrainingTitle,
                  totalSeconds: _freeTrainingElapsedSeconds,
                  controlMaxValue: _freeTrainingControlMaxValue,
                  longestControlTimeSeconds: _freeTrainingLongestControlTimeSeconds,
                  currentWindowMeanValue: _freeTrainingCurrentWindowMeanValue,
                  currentWindowDeltaValue: _freeTrainingCurrentWindowDeltaValue,
                  deltaMaxValue: _freeTrainingDeltaMaxValue,
                  deltaMinValue: _freeTrainingDeltaMinValue,
                  onExitWithoutSave: _exitWithoutSave,
                  onSaveAndExit: _saveFreeTrainingAndExit,
                ),
              ),
          ],
        ),
      ),
    );
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
      sampleIntervalSeconds: _sampleIntervalSeconds,
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

  void _ensureCycleGroup() {
    if (_groupedWorkSamples.length >= _currentCycle) {
      return;
    }
    _groupedWorkSamples.add(TrainingSampleGroup(cycle: _currentCycle, samples: <TrainingSample>[]));
  }

  void _handleExit() {
    if (_isFreeTraining) {
      if (_isSummaryVisible) {
        _exitWithoutSave();
        return;
      }
      setState(() {
        _isSummaryVisible = true;
      });
      return;
    }
    if (_isSummaryVisible) {
      _exitWithoutSave();
      return;
    }
    if (_isPreparing) {
      _exitWithoutSave();
      return;
    }
    final plan = ref.read(trainingPlanProvider);
    final completedCycles = _isWorking ? math.max(0, _currentCycle - 1) : _currentCycle;
    final totalSeconds = _activeElapsedSeconds.ceil();
    final groupedSamples = _groupedWorkSamples.take(completedCycles).toList();
    if (_isWorking && widget.isDeviceConnected) {
      _ensureCycleGroup();
      final currentGroup = _groupedWorkSamples[_currentCycle - 1];
      groupedSamples.add(currentGroup);
    }
    final summary = _buildSummary(
      plan,
      groupedSamples,
      completedCycles: completedCycles,
      totalSecondsOverride: totalSeconds,
    );
    setState(() {
      _summary = summary;
      _pendingGroupedSamples = groupedSamples;
      _isSummaryVisible = true;
      _isFinishPending = false;
    });
    _timer?.cancel();
  }

  void _exitWithoutSave() {
    Navigator.of(context).maybePop();
  }

  void _saveAndExit() {
    if (_summary == null) {
      Navigator.of(context).maybePop();
      return;
    }
    final plan = ref.read(trainingPlanProvider);
    final groupedSamples = _pendingGroupedSamples ?? _groupedWorkSamples;
    _saveTrainingRecord(plan, _summary!, groupedSamples: groupedSamples);
    Navigator.of(context).maybePop();
  }

  void _saveFreeTrainingAndExit(String title) {
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
    );
    ref.read(freeTrainingRecordProvider.notifier).addRecord(record);
    Navigator.of(context).maybePop();
  }
}

class _ExitButton extends StatelessWidget {
  const _ExitButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.close, color: Colors.black87),
      splashRadius: 18,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}
