import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ChartSample {
  const ChartSample({required this.time, required this.value});

  final double time;
  final double value;
}

class MonitorChartPanel extends StatelessWidget {
  const MonitorChartPanel({
    required this.samples,
    required this.displayTimeListenable,
    required this.isPreparing,
    required this.isWorking,
    required this.maxValue,
    required this.phaseDuration,
    super.key,
  });

  final List<ChartSample> samples;
  final ValueListenable<double> displayTimeListenable;
  final bool isPreparing;
  final bool isWorking;
  final double maxValue;
  final double phaseDuration;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ChartPainter(
        samples: samples,
        displayTimeListenable: displayTimeListenable,
        isPreparing: isPreparing,
        isWorking: isWorking,
        maxValue: maxValue,
        phaseDuration: phaseDuration,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.samples,
    required this.displayTimeListenable,
    required this.isPreparing,
    required this.isWorking,
    required this.maxValue,
    required this.phaseDuration,
  }) : super(repaint: displayTimeListenable);

  final List<ChartSample> samples;
  final ValueListenable<double> displayTimeListenable;
  final bool isPreparing;
  final bool isWorking;
  final double maxValue;
  final double phaseDuration;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0 || size.height == 0) {
      return;
    }
    final chartRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(chartRect, Paint()..color = const Color(0xFFF2F2F2));
    if (samples.isEmpty) {
      return;
    }

    final maxValueOnChart = _resolveYAxisMax(isWorking, maxValue);
    final displayTime = _resolveDisplayTime();
    final path = Path();
    double firstX = 0.0;
    double firstY = size.height;
    double lastX = 0.0;
    var hasPoint = false;
    var visibleMaxValue = 0.0;
    var visibleMaxTime = 0.0;
    ChartSample? previous;
    for (final sample in samples) {
      if (sample.time > displayTime) {
        if (previous != null) {
          final interpolated = _interpolateSample(previous, sample, displayTime);
          _appendPoint(
            path: path,
            sample: interpolated,
            maxValueOnChart: maxValueOnChart,
            size: size,
            hasPointValue: hasPoint,
            firstX: (value) => firstX = value,
            firstY: (value) => firstY = value,
            lastX: (value) => lastX = value,
            hasPoint: (value) => hasPoint = value,
          );
          if (interpolated.value >= visibleMaxValue) {
            visibleMaxValue = interpolated.value;
            visibleMaxTime = interpolated.time;
          }
        }
        break;
      }
      _appendPoint(
        path: path,
        sample: sample,
        maxValueOnChart: maxValueOnChart,
        size: size,
        hasPointValue: hasPoint,
        firstX: (value) => firstX = value,
        firstY: (value) => firstY = value,
        lastX: (value) => lastX = value,
        hasPoint: (value) => hasPoint = value,
      );
      if (sample.value >= visibleMaxValue) {
        visibleMaxValue = sample.value;
        visibleMaxTime = sample.time;
      }
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
    canvas.drawPath(fillPath, Paint()..color = fillColor);

    if (isWorking && visibleMaxValue > 0) {
      final maxX = (visibleMaxTime / math.max(phaseDuration, 1.0)) * size.width;
      final maxY = size.height - (visibleMaxValue / maxValueOnChart) * size.height;
      final linePaint = Paint()
        ..color = const Color(0xFFB0B0B0)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(maxX, size.height), Offset(maxX, maxY), linePaint);
    }

    final strokeColor = isPreparing
        ? const Color(0xFF3B7CFF)
        : (isWorking ? const Color(0xFF2AC41F) : const Color(0xFFFF4B4B));
    canvas.drawPath(
      path,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (isWorking && visibleMaxValue > 0) {
      final maxX = (visibleMaxTime / math.max(phaseDuration, 1.0)) * size.width;
      final maxY = size.height - (visibleMaxValue / maxValueOnChart) * size.height;
      final dotPaint = Paint()..color = strokeColor;
      canvas.drawCircle(Offset(maxX, maxY), 4, dotPaint);

      final labelText = 'MAX ${visibleMaxValue.toStringAsFixed(1)} kg';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      var textX = maxX + 8;
      if (textX + textPainter.width > size.width) {
        textX = maxX - 8 - textPainter.width;
      }
      final textY = (maxY - textPainter.height - 6).clamp(0.0, size.height - textPainter.height);
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.displayTimeListenable != displayTimeListenable ||
        oldDelegate.isPreparing != isPreparing ||
        oldDelegate.isWorking != isWorking ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.phaseDuration != phaseDuration;
  }

  double _resolveYAxisMax(bool isWorking, double currentMaxValue) {
    var yMax = 50.0;
    while (currentMaxValue > yMax * 0.7) {
      yMax += 10.0;
    }
    return yMax;
  }

  double _resolveDisplayTime() {
    final latestTime = samples.last.time;
    final displayTime = displayTimeListenable.value;
    if (displayTime <= 0) {
      return 0.0;
    }
    return math.min(displayTime, latestTime);
  }

  void _appendPoint({
    required Path path,
    required ChartSample sample,
    required double maxValueOnChart,
    required Size size,
    required bool hasPointValue,
    required ValueSetter<double> firstX,
    required ValueSetter<double> firstY,
    required ValueSetter<double> lastX,
    required ValueSetter<bool> hasPoint,
  }) {
    final x = (sample.time / math.max(phaseDuration, 1.0)) * size.width;
    final y = size.height - (sample.value / maxValueOnChart) * size.height;
    if (hasPointValue) {
      path.lineTo(x, y);
    } else {
      firstX(x);
      firstY(y);
      path.moveTo(x, y);
      hasPoint(true);
    }
    lastX(x);
  }

  ChartSample _interpolateSample(ChartSample start, ChartSample end, double time) {
    final span = end.time - start.time;
    if (span <= 0) {
      return start;
    }
    final t = ((time - start.time) / span).clamp(0.0, 1.0);
    final value = start.value + (end.value - start.value) * t;
    return ChartSample(time: time, value: value);
  }
}
