import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../providers/training_monitor_controller.dart';
import '../../../providers/training_monitor_state.dart';
import 'widgets/free_training_data_panel.dart';
import 'widgets/free_training_summary_overlay.dart';
import 'widgets/measure_size.dart';
import 'widgets/monitor_chart.dart';
import 'widgets/monitor_exit_button.dart';

class FreeTrainingView extends StatelessWidget {
  const FreeTrainingView({
    required this.state,
    required this.isDeviceConnected,
    required this.displayTimeListenable,
    required this.chartMaxAnimatedValue,
    required this.panelWidth,
    required this.onPanelSizeChange,
    required this.onExit,
    required this.onReset,
    required this.onTogglePause,
    required this.onExitWithoutSave,
    required this.onSaveAndExit,
    super.key,
  });

  final TrainingMonitorState state;
  final bool isDeviceConnected;
  final ValueListenable<double> displayTimeListenable;
  final double chartMaxAnimatedValue;
  final double panelWidth;
  final ValueChanged<Size> onPanelSizeChange;
  final VoidCallback onExit;
  final VoidCallback onReset;
  final VoidCallback onTogglePause;
  final VoidCallback onExitWithoutSave;
  final ValueChanged<String> onSaveAndExit;

  @override
  Widget build(BuildContext context) {
    const workColor = Color(0xFF2AC41F);
    const panelPadding = 16.0;
    const chartRightPadding = 16.0;
    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;
    final rightInset = (isPortrait ? 0.0 : panelWidth + panelPadding) + chartRightPadding;
    final chartStack = Stack(
      children: <Widget>[
        if (isDeviceConnected)
          Positioned.fill(
            child: RepaintBoundary(
              child: MonitorChartPanel(
                samples: state.samples,
                displayTimeListenable: displayTimeListenable,
                isPreparing: false,
                isWorking: true,
                targetMaxValue: chartMaxAnimatedValue,
                isMaxLineLocked: state.chartMaxLocked,
                maxLineLockTime: state.chartMaxReachTime,
                phaseDuration: TrainingMonitorController.freeTrainingWindowSeconds,
                rightInset: rightInset,
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
                                text: state.currentValue.toStringAsFixed(1),
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
                          '${state.chartMaxValue <= 0 ? 0 : (state.currentValue / state.chartMaxValue * 100).round()}%',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (!isDeviceConnected)
          const Center(
            child: Text(
              '自由训练',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: workColor),
            ),
          ),
        Positioned(top: 8, left: 16, child: MonitorExitButton(onPressed: onExit)),
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
                  totalSeconds: state.freeTrainingElapsedSeconds,
                  controlMaxValue: state.freeTrainingControlMaxValue,
                  longestControlTimeSeconds: state.freeTrainingLongestControlTimeSeconds,
                  currentWindowMeanValue: state.freeTrainingCurrentWindowMeanValue,
                  currentWindowDeltaValue: state.freeTrainingCurrentWindowDeltaValue,
                  deltaMaxValue: state.freeTrainingDeltaMaxValue,
                  deltaMinValue: state.freeTrainingDeltaMinValue,
                  isDeviceConnected: isDeviceConnected,
                  isPaused: state.isPaused,
                  onReset: onReset,
                  onTogglePause: onTogglePause,
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
                    onChange: onPanelSizeChange,
                    child: FreeTrainingDataPanel(
                      totalSeconds: state.freeTrainingElapsedSeconds,
                      controlMaxValue: state.freeTrainingControlMaxValue,
                      longestControlTimeSeconds: state.freeTrainingLongestControlTimeSeconds,
                      currentWindowMeanValue: state.freeTrainingCurrentWindowMeanValue,
                      currentWindowDeltaValue: state.freeTrainingCurrentWindowDeltaValue,
                      deltaMaxValue: state.freeTrainingDeltaMaxValue,
                      deltaMinValue: state.freeTrainingDeltaMinValue,
                      isDeviceConnected: isDeviceConnected,
                      isPaused: state.isPaused,
                      onReset: onReset,
                      onTogglePause: onTogglePause,
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
            if (state.isSummaryVisible)
              Positioned.fill(
                child: FreeTrainingSummaryOverlay(
                  defaultTitle: state.freeTrainingTitle,
                  totalSeconds: state.freeTrainingElapsedSeconds,
                  controlMaxValue: state.freeTrainingControlMaxValue,
                  longestControlTimeSeconds: state.freeTrainingLongestControlTimeSeconds,
                  currentWindowMeanValue: state.freeTrainingCurrentWindowMeanValue,
                  currentWindowDeltaValue: state.freeTrainingCurrentWindowDeltaValue,
                  deltaMaxValue: state.freeTrainingDeltaMaxValue,
                  deltaMinValue: state.freeTrainingDeltaMinValue,
                  onExitWithoutSave: onExitWithoutSave,
                  onSaveAndExit: onSaveAndExit,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
