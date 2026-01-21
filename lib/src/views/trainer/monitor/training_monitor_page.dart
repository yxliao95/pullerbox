import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/training_plan.dart';
import '../../../providers/training_monitor_controller.dart';
import '../../../providers/training_monitor_state.dart';
import '../../../providers/training_plan_controller.dart';
import '../../../providers/training_plan_library_controller.dart';
import 'free_training_view.dart';
import 'training_monitor_view.dart';
class TrainingMonitorPage extends ConsumerStatefulWidget {
  const TrainingMonitorPage({required this.isDeviceConnected, super.key});

  final bool isDeviceConnected;

  @override
  ConsumerState<TrainingMonitorPage> createState() => _TrainingMonitorPageState();
}

class _TrainingMonitorPageState extends ConsumerState<TrainingMonitorPage> with SingleTickerProviderStateMixin {
  static const double _renderLagSeconds = 0.03;
  static const double _chartMaxTweenSpeed = 6.0;
  static const double _estimatedToolbarWidth = 136.0;
  static const double _freeTrainingPanelFallbackWidth = 160.0;

  late final TrainingPlanState _plan;
  late final bool _isFreeTraining;
  late final TrainingMonitorConfig _monitorConfig;
  late final Ticker _ticker;
  final ValueNotifier<double> _displayTime = ValueNotifier<double>(0.0);
  Duration _lastFrameTimestamp = Duration.zero;

  bool _isSoundOn = true;
  double _chartMaxAnimatedValue = 0.0;
  double _toolbarHorizontalWidth = 0.0;
  double _exitButtonHeight = 0.0;
  double _freeTrainingPanelWidth = _freeTrainingPanelFallbackWidth;
  TrainingMonitorState? _latestState;

  @override
  void initState() {
    super.initState();
    _plan = ref.read(trainingPlanProvider);
    _isFreeTraining = ref.read(trainingPlanLibraryProvider).isFreeTraining;
    _monitorConfig = TrainingMonitorConfig(
      plan: _plan,
      isDeviceConnected: widget.isDeviceConnected,
      isFreeTraining: _isFreeTraining,
    );
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _ticker = createTicker(_onFrame)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _displayTime.dispose();
    SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _onFrame(Duration elapsed) {
    final monitorState = _latestState;
    if (monitorState == null) {
      return;
    }
    if (monitorState.isPaused) {
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
    final lagSeconds = monitorState.isFinishPending ? 0.0 : _renderLagSeconds;
    final rawTargetTime = (monitorState.elapsedInPhase - lagSeconds).clamp(0.0, double.infinity);
    final targetTime = monitorState.isFreeTraining
        ? math.min(rawTargetTime, TrainingMonitorController.freeTrainingWindowSeconds)
        : rawTargetTime.clamp(0.0, monitorState.elapsedInPhase);
    final nextDisplayTime = math.min(_displayTime.value + deltaSeconds, targetTime);
    if (nextDisplayTime != _displayTime.value) {
      _displayTime.value = nextDisplayTime;
    }
    if (_chartMaxAnimatedValue != monitorState.chartMaxValue) {
      if (_chartMaxAnimatedValue <= 0 && monitorState.chartMaxValue > 0) {
        _chartMaxAnimatedValue = monitorState.chartMaxValue;
      } else {
        final delta = monitorState.chartMaxValue - _chartMaxAnimatedValue;
        final step = delta * math.min(1.0, _chartMaxTweenSpeed * deltaSeconds);
        _chartMaxAnimatedValue += step;
        if ((monitorState.chartMaxValue - _chartMaxAnimatedValue).abs() < 0.01) {
          _chartMaxAnimatedValue = monitorState.chartMaxValue;
        }
      }
      setState(() {});
    }
    if (monitorState.isFinishPending && _displayTime.value >= monitorState.elapsedInPhase) {
      ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).showSummary();
    }
  }

  void _togglePause() {
    final wasPaused = _latestState?.isPaused ?? false;
    ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).togglePause();
    if (wasPaused) {
      _lastFrameTimestamp = Duration.zero;
    }
  }

  void _toggleSound() {
    setState(() {
      _isSoundOn = !_isSoundOn;
    });
  }

  void _goToPreviousAction() {
    ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).goToPreviousAction();
  }

  void _goToNextAction() {
    ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).goToNextAction();
  }

  void _resetFreeTraining() {
    ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).resetFreeTraining();
    _displayTime.value = 0.0;
    _lastFrameTimestamp = Duration.zero;
  }

  void _handleExit(TrainingMonitorState monitorState) {
    if (_isFreeTraining) {
      if (monitorState.isSummaryVisible) {
        _exitWithoutSave();
        return;
      }
      ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).showFreeTrainingSummary();
      return;
    }
    if (monitorState.isSummaryVisible || monitorState.isPreparing) {
      _exitWithoutSave();
      return;
    }
    ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).prepareExitSummary();
  }

  void _exitWithoutSave() {
    Navigator.of(context).maybePop();
  }

  void _saveAndExit() {
    ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).saveAndExit();
    Navigator.of(context).maybePop();
  }

  void _saveFreeTrainingAndExit(String title) {
    ref.read(trainingMonitorControllerProvider(_monitorConfig).notifier).saveFreeTraining(title);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(trainingMonitorControllerProvider(_monitorConfig));
    _latestState = monitorState;
    if (_displayTime.value > monitorState.elapsedInPhase) {
      _displayTime.value = 0.0;
      _lastFrameTimestamp = Duration.zero;
    }

    if (_isFreeTraining) {
      return FreeTrainingView(
        state: monitorState,
        isDeviceConnected: widget.isDeviceConnected,
        displayTimeListenable: _displayTime,
        chartMaxAnimatedValue: _chartMaxAnimatedValue,
        panelWidth: _freeTrainingPanelWidth,
        onPanelSizeChange: (size) {
          if (size.width != _freeTrainingPanelWidth) {
            setState(() {
              _freeTrainingPanelWidth = size.width;
            });
          }
        },
        onExit: () => _handleExit(monitorState),
        onReset: _resetFreeTraining,
        onTogglePause: _togglePause,
        onExitWithoutSave: _exitWithoutSave,
        onSaveAndExit: _saveFreeTrainingAndExit,
      );
    }

    final totalCycles = math.max(1, _plan.cycles);
    final phaseDuration = monitorState.isPreparing
        ? TrainingMonitorController.prepareSeconds
        : (monitorState.isWorking ? _plan.workSeconds : _plan.restSeconds);
    const workColor = Color(0xFF2AC41F);
    const restColor = Color(0xFFFF4B4B);
    const prepareColor = Color(0xFF3B7CFF);
    final phaseColor =
        monitorState.isPreparing ? prepareColor : (monitorState.isWorking ? workColor : restColor);

    return TrainingMonitorView(
      state: monitorState,
      isDeviceConnected: widget.isDeviceConnected,
      totalCycles: totalCycles,
      phaseDuration: phaseDuration,
      phaseColor: phaseColor,
      displayTimeListenable: _displayTime,
      chartMaxAnimatedValue: _chartMaxAnimatedValue,
      isSoundOn: _isSoundOn,
      toolbarHorizontalWidth: _toolbarHorizontalWidth,
      estimatedToolbarWidth: _estimatedToolbarWidth,
      exitButtonHeight: _exitButtonHeight,
      onExitSizeChange: (size) {
        if (size.height != _exitButtonHeight) {
          setState(() {
            _exitButtonHeight = size.height;
          });
        }
      },
      onToolbarSizeChange: (size) {
        if (size.width != _toolbarHorizontalWidth) {
          setState(() {
            _toolbarHorizontalWidth = size.width;
          });
        }
      },
      onExit: () => _handleExit(monitorState),
      onToggleSound: _toggleSound,
      onPrevious: _goToPreviousAction,
      onTogglePause: _togglePause,
      onNext: _goToNextAction,
      onExitWithoutSave: _exitWithoutSave,
      onSaveAndExit: _saveAndExit,
    );
  }
}
