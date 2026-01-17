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
  static const double _sampleIntervalSeconds = 0.1;
  static const double _renderLagSeconds = 0.03;
  static const double _restMaxValue = 1.0;
  static const int _prepareSeconds = 3;
  static const double _emaAlpha = 0.25;
  static const double _estimatedToolbarWidth = 136.0;
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
  double _maxValue = 0.0;
  List<ChartSample> _samples = <ChartSample>[];
  List<double> _workSecondLimits = <double>[];
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
    if (!isOfflineMode) {
      _samples = <ChartSample>[..._samples, ChartSample(time: _elapsedInPhase, value: _currentValue)];
      if (_samples.length > 600) {
        _samples = _samples.sublist(_samples.length - 600);
      }
      if (_currentValue >= _maxValue) {
        _maxValue = _currentValue;
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
    _maxValue = 0.0;
    _displayTime.value = 0.0;
    _lastFrameTimestamp = Duration.zero;
    if (isWorking) {
      _workSecondLimits = <double>[_randomInRange(35.0, 70.0)];
      if (!isOfflineMode) {
        _ensureCycleGroup();
      }
    } else {
      _workSecondLimits = <double>[];
    }
    _currentValue = 0.0;
    _smoothedValue = 0.0;
  }

  void _startPreparePhase() {
    _isPreparing = true;
    _isWorking = true;
    _elapsedInPhase = 0.0;
    _samples = const <ChartSample>[ChartSample(time: 0.0, value: 0.0)];
    _maxValue = 0.0;
    _displayTime.value = 0.0;
    _lastFrameTimestamp = Duration.zero;
    _currentValue = 0.0;
    _smoothedValue = 0.0;
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
  }

  double _nextSampleValue() {
    if (_isPreparing) {
      return 0.0;
    }
    if (!_isWorking) {
      return _roundToTenth(_random.nextDouble() * _restMaxValue);
    }
    final second = _elapsedInPhase.floor();
    final nextSecond = second + 1;
    final currentLimit = _limitForSecond(second);
    final nextLimit = _limitForSecond(nextSecond);
    double minLimit = math.min(currentLimit, nextLimit);
    double maxLimit = math.max(currentLimit, nextLimit);
    if (_elapsedInPhase < 1.0) {
      final progress = _elapsedInPhase.clamp(0.0, 1.0);
      maxLimit = currentLimit * progress;
      minLimit = 0.0;
    }
    return _roundToTenth(_randomInRange(minLimit, maxLimit));
  }

  double _limitForSecond(int second) {
    if (second < 0) {
      return 0.0;
    }
    if (second < _workSecondLimits.length) {
      return _workSecondLimits[second];
    }
    for (var i = _workSecondLimits.length; i <= second; i++) {
      final previous = _workSecondLimits.last;
      final decay = _randomInRange(0.7, 0.9);
      _workSecondLimits.add(previous * decay);
    }
    return _workSecondLimits[second];
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
                              maxValue: _maxValue,
                              phaseDuration: phaseDuration.toDouble(),
                            ),
                          ),
                        ),
                      if (!isOfflineMode)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(
                              '实时拉力：${_currentValue.toStringAsFixed(1)} KG',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
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
