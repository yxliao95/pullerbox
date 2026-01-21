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
      painter: _ChartPainter(
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

class _ChartPainter extends CustomPainter {
  _ChartPainter({
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

    final maxValueOnChart = _resolveYAxisMax(isWorking, _resolveSamplesMax());
    final displayTime = _resolveDisplayTime();
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
      _appendPoint(
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
      );
      previous = anchorSample;
    }
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
            lastY: (value) => lastY = value,
            hasPoint: (value) => hasPoint = value,
            contentWidth: contentWidth,
          );
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
        lastY: (value) => lastY = value,
        hasPoint: (value) => hasPoint = value,
        contentWidth: contentWidth,
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
      _drawDottedLine(canvas, linePaint, maxLineY, size.width);
      percent60LineY = _resolvePercentLineY(size, maxLineY, 0.6);
      percent20LineY = _resolvePercentLineY(size, maxLineY, 0.2);
      _drawDottedLine(canvas, linePaint, percent60LineY, size.width);
      _drawDottedLine(canvas, linePaint, percent20LineY, size.width);
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
      _drawMaxLabel(canvas, size, maxLineY, targetMaxValue);
      if (percent60LineY != null) {
        _drawPercentLabel(canvas, size, percent60LineY, '60%');
      }
      if (percent20LineY != null) {
        _drawPercentLabel(canvas, size, percent20LineY, '20%');
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
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

  double _resolveYAxisMax(bool isWorking, double currentMaxValue) {
    if (targetMaxValue > 0) {
      return (targetMaxValue / 0.7).clamp(1.0, double.infinity);
    }
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

  double _resolveSamplesMax() {
    var maxValue = 0.0;
    for (final sample in samples) {
      if (sample.value > maxValue) {
        maxValue = sample.value;
      }
    }
    return maxValue;
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
    required ValueSetter<double> lastY,
    required double contentWidth,
  }) {
    final x = (sample.time / math.max(phaseDuration, 1.0)) * contentWidth;
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
    lastY(y);
  }

  void _drawDottedLine(Canvas canvas, Paint paint, double y, double width) {
    const segment = 4.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < width) {
      final endX = math.min(x + segment, width);
      canvas.drawLine(Offset(x, y), Offset(endX, y), paint);
      x += segment + gap;
    }
  }

  double _resolvePercentLineY(Size size, double maxLineY, double ratio) {
    return (size.height - (size.height - maxLineY) * ratio).clamp(0.0, size.height);
  }

  void _drawPercentLabel(Canvas canvas, Size size, double lineY, String text) {
    const padding = 8.0;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6E6E6E)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final textX = padding;
    final textY = (lineY - textPainter.height - 4.0).clamp(0.0, size.height - textPainter.height);
    textPainter.paint(canvas, Offset(textX, textY));
  }

  void _drawMaxLabel(Canvas canvas, Size size, double lineY, double value) {
    const padding = 8.0;
    final text = 'PEAK ${value.toStringAsFixed(1)} kg';
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6E6E6E)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final textX = padding;
    final textY = (lineY - textPainter.height - 4.0).clamp(0.0, size.height - textPainter.height);
    textPainter.paint(canvas, Offset(textX, textY));
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
