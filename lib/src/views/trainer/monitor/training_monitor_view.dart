import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../providers/training_monitor_state.dart';
import 'widgets/monitor_chart.dart';
import 'widgets/monitor_header_bar.dart';
import 'widgets/monitor_progress_bar.dart';
import 'widgets/monitor_summary_overlay.dart';

class TrainingMonitorView extends StatelessWidget {
  const TrainingMonitorView({
    required this.state,
    required this.isDeviceConnected,
    required this.totalCycles,
    required this.phaseDuration,
    required this.phaseColor,
    required this.displayTimeListenable,
    required this.chartMaxAnimatedValue,
    required this.isSoundOn,
    required this.toolbarHorizontalWidth,
    required this.estimatedToolbarWidth,
    required this.exitButtonHeight,
    required this.onExitSizeChange,
    required this.onToolbarSizeChange,
    required this.onExit,
    required this.onToggleSound,
    required this.onPrevious,
    required this.onTogglePause,
    required this.onNext,
    required this.onExitWithoutSave,
    required this.onSaveAndExit,
    super.key,
  });

  final TrainingMonitorState state;
  final bool isDeviceConnected;
  final int totalCycles;
  final int phaseDuration;
  final Color phaseColor;
  final ValueListenable<double> displayTimeListenable;
  final double chartMaxAnimatedValue;
  final bool isSoundOn;
  final double toolbarHorizontalWidth;
  final double estimatedToolbarWidth;
  final double exitButtonHeight;
  final ValueChanged<Size> onExitSizeChange;
  final ValueChanged<Size> onToolbarSizeChange;
  final VoidCallback onExit;
  final VoidCallback onToggleSound;
  final VoidCallback onPrevious;
  final VoidCallback onTogglePause;
  final VoidCallback onNext;
  final VoidCallback onExitWithoutSave;
  final VoidCallback onSaveAndExit;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
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
                      if (isDeviceConnected)
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: MonitorChartPanel(
                              samples: state.samples,
                              displayTimeListenable: displayTimeListenable,
                              isPreparing: state.isPreparing,
                              isWorking: state.isWorking,
                              targetMaxValue: chartMaxAnimatedValue,
                              isMaxLineLocked: state.chartMaxLocked,
                              maxLineLockTime: state.chartMaxReachTime,
                              phaseDuration: phaseDuration.toDouble(),
                              rightInset: 8.0,
                            ),
                          ),
                        ),
                      if (isDeviceConnected)
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
                                            text: state.currentValue.toStringAsFixed(1),
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
                                      '${state.chartMaxValue <= 0 ? 0 : (state.currentValue / state.chartMaxValue * 100).round()}%',
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
                      if (!isDeviceConnected && state.isWorking && !state.isPreparing)
                        const Center(
                          child: Text(
                            '锻炼',
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Color(0xFF2AC41F)),
                          ),
                        ),
                      if (state.isPreparing)
                        const Center(
                          child: Text(
                            '准备',
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Color(0xFF3B7CFF)),
                          ),
                        )
                      else if (!state.isWorking)
                        const Center(
                          child: Text(
                            '休息',
                            style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: Color(0xFFFF4B4B)),
                          ),
                        ),
                    ],
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: displayTimeListenable,
                  builder: (context, displayTime, _) {
                    final clampedTime = displayTime.clamp(0.0, state.elapsedInPhase);
                    final phaseProgress =
                        phaseDuration <= 0 ? 0.0 : (clampedTime / phaseDuration).clamp(0.0, 1.0);
                    final remainingSeconds = phaseDuration <= 0
                        ? 0
                        : (phaseDuration - clampedTime).ceil().clamp(0, phaseDuration);
                    return MonitorProgressBar(
                      progress: phaseProgress,
                      color: phaseColor,
                      label: '$remainingSeconds 秒',
                    );
                  },
                ),
              ],
            ),
            if (state.isSummaryVisible && summary != null)
              Positioned.fill(
                child: MonitorSummaryOverlay(
                  summary: summary,
                  showStatistics: isDeviceConnected,
                  onExitWithoutSave: onExitWithoutSave,
                  onSaveAndExit: onSaveAndExit,
                ),
              )
            else
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: MonitorHeaderBar(
                  titleText: '循环 ${state.currentCycle} / $totalCycles',
                  isSoundOn: isSoundOn,
                  isPaused: state.isPaused,
                  toolbarHorizontalWidth: toolbarHorizontalWidth,
                  estimatedToolbarWidth: estimatedToolbarWidth,
                  exitButtonHeight: exitButtonHeight,
                  onExitSizeChange: onExitSizeChange,
                  onToolbarSizeChange: onToolbarSizeChange,
                  onExit: onExit,
                  onToggleSound: onToggleSound,
                  onPrevious: onPrevious,
                  onTogglePause: onTogglePause,
                  onNext: onNext,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
