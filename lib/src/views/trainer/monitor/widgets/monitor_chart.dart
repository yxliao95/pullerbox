import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../models/chart_sample.dart';
import 'monitor_chart_painter.dart';

class MonitorChartPanel extends StatelessWidget {
  const MonitorChartPanel({
    required this.samples,
    required this.displayTimeListenable,
    required this.isPreparing,
    required this.isWorking,
    required this.targetMaxValue,
    required this.isMaxLineLocked,
    required this.maxLineLockTime,
    required this.phaseDuration,
    this.rightInset = 0.0,
    super.key,
  });

  final List<ChartSample> samples;
  final ValueListenable<double> displayTimeListenable;
  final bool isPreparing;
  final bool isWorking;
  final double targetMaxValue;
  final bool isMaxLineLocked;
  final double maxLineLockTime;
  final double phaseDuration;
  final double rightInset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MonitorChartPainter(
        samples: samples,
        displayTimeListenable: displayTimeListenable,
        isPreparing: isPreparing,
        isWorking: isWorking,
        targetMaxValue: targetMaxValue,
        isMaxLineLocked: isMaxLineLocked,
        maxLineLockTime: maxLineLockTime,
        phaseDuration: phaseDuration,
        rightInset: rightInset,
      ),
    );
  }
}
