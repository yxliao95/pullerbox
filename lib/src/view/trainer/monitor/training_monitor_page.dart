import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/training_plan.dart';
import '../../../models/training_record.dart';
import '../../../provider/training_plan_provider.dart';
import '../../../provider/training_record_provider.dart';
import 'widgets/measure_size.dart';
import 'widgets/monitor_chart.dart';
import 'widgets/monitor_progress_bar.dart';
import 'widgets/monitor_summary_overlay.dart';
import 'widgets/monitor_toolbar.dart';

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
  double _workElapsedSeconds = 0.0;
  double _activeElapsedSeconds = 0.0;
  DateTime _trainingStartedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _startPreparePhase();
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
    final targetTime = (_elapsedInPhase - lagSeconds).clamp(0.0, _elapsedInPhase);
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
    _summary = _buildSummary(plan, totalSecondsOverride: totalSeconds);
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

  TrainingSummary _buildSummary(TrainingPlanState plan, {int? completedCycles, int? totalSecondsOverride}) {
    final resolvedCycles = completedCycles ?? plan.cycles;
    final values = List<double>.from(_workValues);
    values.sort();
    final maxValue = values.isEmpty ? 0.0 : values.last;
    final averageValue = values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    final medianValue = values.isEmpty
        ? 0.0
        : (values.length.isOdd
              ? values[values.length ~/ 2]
              : (values[values.length ~/ 2 - 1] + values[values.length ~/ 2]) / 2);
    final restCycles = resolvedCycles > 0 ? resolvedCycles - 1 : 0;
    final totalSeconds = totalSecondsOverride ?? plan.workSeconds * resolvedCycles + plan.restSeconds * restCycles;
    return TrainingSummary(
      planName: plan.name,
      workSeconds: plan.workSeconds,
      restSeconds: plan.restSeconds,
      cycles: resolvedCycles,
      totalSeconds: totalSeconds,
      maxValue: maxValue,
      averageValue: averageValue,
      medianValue: medianValue,
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
      statistics: TrainingStatistics(
        maxValue: summary.maxValue,
        averageValue: summary.averageValue,
        medianValue: summary.medianValue,
      ),
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
    final summary = _buildSummary(plan, completedCycles: completedCycles, totalSecondsOverride: totalSeconds);
    final groupedSamples = _groupedWorkSamples.take(completedCycles).toList();
    if (_isWorking && widget.isDeviceConnected) {
      _ensureCycleGroup();
      final currentGroup = _groupedWorkSamples[_currentCycle - 1];
      groupedSamples.add(currentGroup);
    }
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
