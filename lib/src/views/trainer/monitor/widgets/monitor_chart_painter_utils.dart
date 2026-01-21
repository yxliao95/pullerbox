import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../models/chart_sample.dart';

double resolveYAxisMax({required double targetMaxValue, required bool isWorking, required double currentMaxValue}) {
  if (targetMaxValue > 0) {
    return (targetMaxValue / 0.7).clamp(1.0, double.infinity);
  }
  var yMax = 50.0;
  while (currentMaxValue > yMax * 0.7) {
    yMax += 10.0;
  }
  return yMax;
}

double resolveDisplayTime({required List<ChartSample> samples, required ValueListenable<double> displayTimeListenable}) {
  final latestTime = samples.last.time;
  final displayTime = displayTimeListenable.value;
  if (displayTime <= 0) {
    return 0.0;
  }
  return math.min(displayTime, latestTime);
}

double resolveSamplesMax(List<ChartSample> samples) {
  var maxValue = 0.0;
  for (final sample in samples) {
    if (sample.value > maxValue) {
      maxValue = sample.value;
    }
  }
  return maxValue;
}

void appendPoint({
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
  required double phaseDuration,
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

void drawDottedLine(Canvas canvas, Paint paint, double y, double width) {
  const segment = 4.0;
  const gap = 4.0;
  var x = 0.0;
  while (x < width) {
    final endX = math.min(x + segment, width);
    canvas.drawLine(Offset(x, y), Offset(endX, y), paint);
    x += segment + gap;
  }
}

double resolvePercentLineY(Size size, double maxLineY, double ratio) {
  return (size.height - (size.height - maxLineY) * ratio).clamp(0.0, size.height);
}

void drawPercentLabel(Canvas canvas, Size size, double lineY, String text) {
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

void drawMaxLabel(Canvas canvas, Size size, double lineY, double value) {
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

ChartSample interpolateSample(ChartSample start, ChartSample end, double time) {
  final span = end.time - start.time;
  if (span <= 0) {
    return start;
  }
  final t = ((time - start.time) / span).clamp(0.0, 1.0);
  final value = start.value + (end.value - start.value) * t;
  return ChartSample(time: time, value: value);
}
