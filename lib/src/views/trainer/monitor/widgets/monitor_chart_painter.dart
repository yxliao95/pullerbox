import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../models/chart_sample.dart';
import 'monitor_chart_painter_utils.dart';

class MonitorChartPainter extends CustomPainter {
  MonitorChartPainter({
    required this.samples,
    required this.displayTimeListenable,
    required this.isPreparing,
    required this.isWorking,
    required this.targetMaxValue,
    required this.isMaxLineLocked,
    required this.maxLineLockTime,
    required this.phaseDuration,
    required this.rightInset,
  }) : super(repaint: displayTimeListenable);

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
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) {
      return;
    }
    final chartRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final contentWidth = (size.width - rightInset).clamp(0.0, size.width);
    const backgroundColor = Color(0xFFF2F2F2);
    canvas.drawRect(chartRect, Paint()..color = backgroundColor);
    if (samples.isEmpty) {
      return;
    }

    final maxValueOnChart = resolveYAxisMax(
      targetMaxValue: targetMaxValue,
      isWorking: isWorking,
      currentMaxValue: resolveSamplesMax(samples),
    );
    final displayTime = resolveDisplayTime(
      samples: samples,
      displayTimeListenable: displayTimeListenable,
    );
    final path = Path();
    double firstX = 0.0;
    double firstY = size.height;
    double lastX = 0.0;
    double lastY = 0.0;
    var hasPoint = false;
    ChartSample? previous;
    final firstSample = samples.first;
    if (firstSample.time > 0) {
      final anchorSample = ChartSample(time: 0, value: firstSample.value);
      appendPoint(
        path: path,
        sample: anchorSample,
        maxValueOnChart: maxValueOnChart,
        size: size,
        hasPointValue: hasPoint,
        firstX: (value) => firstX = value,
        firstY: (value) => firstY = value,
        lastX: (value) => lastX = value,
        lastY: (value) => lastY = value,
        hasPoint: (value) => hasPoint = value,
        contentWidth: contentWidth,
        phaseDuration: phaseDuration,
      );
      previous = anchorSample;
    }
    for (final sample in samples) {
      if (sample.time > displayTime) {
        if (previous != null) {
          final interpolated = interpolateSample(previous, sample, displayTime);
          appendPoint(
            path: path,
            sample: interpolated,
            maxValueOnChart: maxValueOnChart,
            size: size,
            hasPointValue: hasPoint,
            firstX: (value) => firstX = value,
            firstY: (value) => firstY = value,
            lastX: (value) => lastX = value,
            lastY: (value) => lastY = value,
            hasPoint: (value) => hasPoint = value,
            contentWidth: contentWidth,
            phaseDuration: phaseDuration,
          );
        }
        break;
      }
      appendPoint(
        path: path,
        sample: sample,
        maxValueOnChart: maxValueOnChart,
        size: size,
        hasPointValue: hasPoint,
        firstX: (value) => firstX = value,
        firstY: (value) => firstY = value,
        lastX: (value) => lastX = value,
        lastY: (value) => lastY = value,
        hasPoint: (value) => hasPoint = value,
        contentWidth: contentWidth,
        phaseDuration: phaseDuration,
      );
      previous = sample;
    }

    if (!hasPoint) {
      return;
    }

    final endX = lastX;
    final fillPath = Path()
      ..moveTo(0, size.height)
      ..lineTo(firstX, size.height)
      ..lineTo(firstX, firstY)
      ..addPath(path, Offset.zero)
      ..lineTo(endX, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillColor = isPreparing
        ? const Color(0x333B7CFF)
        : (isWorking ? const Color(0x332AC41F) : const Color(0x33FF4B4B));
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillColor, backgroundColor],
      ).createShader(chartRect);
    canvas.drawPath(fillPath, fillPaint);

    final strokeColor = isPreparing
        ? const Color(0xFF3B7CFF)
        : (isWorking ? const Color(0xFF2AC41F) : const Color(0xFFFF4B4B));
    double? maxLineY;
    double? percent60LineY;
    double? percent20LineY;
    if (targetMaxValue > 0) {
      final linePaint = Paint()
        ..color = const Color(0xFFB0B0B0)
        ..strokeWidth = 1;
      maxLineY = size.height - (targetMaxValue / maxValueOnChart) * size.height;
      drawDottedLine(canvas, linePaint, maxLineY, size.width);
      percent60LineY = resolvePercentLineY(size, maxLineY, 0.6);
      percent20LineY = resolvePercentLineY(size, maxLineY, 0.2);
      drawDottedLine(canvas, linePaint, percent60LineY, size.width);
      drawDottedLine(canvas, linePaint, percent20LineY, size.width);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final endOffset = Offset(lastX, lastY);
    canvas.drawCircle(endOffset, 6, Paint()..color = strokeColor);
    canvas.drawCircle(endOffset, 4, Paint()..color = Colors.white);
    if (targetMaxValue > 0 && maxLineY != null) {
      drawMaxLabel(canvas, size, maxLineY, targetMaxValue);
      if (percent60LineY != null) {
        drawPercentLabel(canvas, size, percent60LineY, '60%');
      }
      if (percent20LineY != null) {
        drawPercentLabel(canvas, size, percent20LineY, '20%');
      }
    }
  }

  @override
  bool shouldRepaint(covariant MonitorChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.displayTimeListenable != displayTimeListenable ||
        oldDelegate.isPreparing != isPreparing ||
        oldDelegate.isWorking != isWorking ||
        oldDelegate.targetMaxValue != targetMaxValue ||
        oldDelegate.isMaxLineLocked != isMaxLineLocked ||
        oldDelegate.maxLineLockTime != maxLineLockTime ||
        oldDelegate.phaseDuration != phaseDuration ||
        oldDelegate.rightInset != rightInset;
  }

}
