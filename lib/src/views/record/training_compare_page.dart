import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/metric_definitions.dart';
import '../../providers/training_compare_provider.dart';

class TrainingComparePage extends ConsumerWidget {
  const TrainingComparePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(trainingCompareResultProvider);
    final filter = result.filter;
    final metricDefinitions = timedSummaryMetricDefinitions
        .where((definition) => definition.metric != TimedSummaryMetric.fatigueSignal)
        .toList();
    final metricLabel = timedSummaryMetricDefinitionMap[filter.metric]?.label ?? '指标';
    final sharedScaleRange = _resolveScaleRangeFromValues(<double?>[
      result.left.maxValue,
      result.left.minValue,
      result.left.lastValue,
      result.right.maxValue,
      result.right.minValue,
      result.right.lastValue,
    ]);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: <Widget>[
        _DateRangeCard(
          startDate: filter.startDate,
          endDate: filter.endDate,
          onStartTap: () => _pickStartDate(context, ref),
          onEndTap: () => _pickEndDate(context, ref),
          onReset: () => ref.read(trainingCompareFilterProvider.notifier).resetRecentMonths(),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: _PlanIndicatorCard(
                title: '计划 A',
                planName: filter.leftPlanName,
                stats: result.left,
                metric: filter.metric,
                scaleRange: sharedScaleRange,
                onTap: () => _showPlanPicker(
                  context,
                  planNames: result.availablePlanNames,
                  selectedName: filter.leftPlanName,
                  onSelected: (name) => ref.read(trainingCompareFilterProvider.notifier).setLeftPlanName(name),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _PlanIndicatorCard(
                title: '计划 B',
                planName: filter.rightPlanName,
                stats: result.right,
                metric: filter.metric,
                scaleRange: sharedScaleRange,
                onTap: () => _showPlanPicker(
                  context,
                  planNames: result.availablePlanNames,
                  selectedName: filter.rightPlanName,
                  onSelected: (name) => ref.read(trainingCompareFilterProvider.notifier).setRightPlanName(name),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _MetricSwitchButton(
          label: metricLabel,
          onTap: () => _showMetricPicker(
            context,
            current: filter.metric,
            definitions: metricDefinitions,
            onSelected: (metric) => ref.read(trainingCompareFilterProvider.notifier).setMetric(metric),
          ),
        ),
      ],
    );
  }

  Future<void> _pickStartDate(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(trainingCompareFilterProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    ref.read(trainingCompareFilterProvider.notifier).setStartDate(picked);
  }

  Future<void> _pickEndDate(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(trainingCompareFilterProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.endDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !context.mounted) {
      return;
    }
    ref.read(trainingCompareFilterProvider.notifier).setEndDate(picked);
  }
}

class _DateRangeCard extends StatelessWidget {
  const _DateRangeCard({
    required this.startDate,
    required this.endDate,
    required this.onStartTap,
    required this.onEndTap,
    required this.onReset,
  });

  final DateTime startDate;
  final DateTime endDate;
  final VoidCallback onStartTap;
  final VoidCallback onEndTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('时间范围', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DateButton(label: _formatDate(startDate), onTap: onStartTap),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
                ),
                Expanded(
                  child: _DateButton(label: _formatDate(endDate), onTap: onEndTap),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onReset, child: const Text('最近三个月')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF2F7BEA),
        side: const BorderSide(color: Color(0xFF2F7BEA)),
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

class _PlanIndicatorCard extends StatelessWidget {
  const _PlanIndicatorCard({
    required this.title,
    required this.planName,
    required this.stats,
    required this.metric,
    required this.scaleRange,
    required this.onTap,
  });

  final String title;
  final String? planName;
  final TrainingCompareMetricStats stats;
  final TimedSummaryMetric metric;
  final _ScaleRange scaleRange;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayMax = stats.maxValue;
    final displayMin = stats.minValue;
    final displayLast = stats.lastValue;
    final hasPlan = planName != null && planName!.isNotEmpty;
    final hasData = displayMax != null || displayMin != null || displayLast != null;
    final maxLabel = _formatMetricValue(metric, displayMax);
    final minLabel = _formatMetricValue(metric, displayMin);
    final lastLabel = _formatMetricValue(metric, displayLast);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      hasPlan ? planName! : title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasPlan ? '更换' : '选择',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF2F7BEA), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
                child: _IndicatorBar(
                  maxValue: displayMax,
                  minValue: displayMin,
                  lastValue: displayLast,
                  scaleRange: scaleRange,
                  metric: metric,
                  isEmpty: !hasData,
                  maxLabel: maxLabel,
                  minLabel: minLabel,
                  lastLabel: lastLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IndicatorBar extends StatelessWidget {
  const _IndicatorBar({
    required this.maxValue,
    required this.minValue,
    required this.lastValue,
    required this.scaleRange,
    required this.metric,
    required this.isEmpty,
    required this.maxLabel,
    required this.minLabel,
    required this.lastLabel,
  });

  final double? maxValue;
  final double? minValue;
  final double? lastValue;
  final _ScaleRange scaleRange;
  final TimedSummaryMetric metric;
  final bool isEmpty;
  final String maxLabel;
  final String minLabel;
  final String lastLabel;

  @override
  Widget build(BuildContext context) {
    const barHeight = 300.0;
    final range = (scaleRange.max - scaleRange.min).abs();
    final normalizedRange = range <= 0 ? 1.0 : range;
    final maxHeight = (((maxValue ?? 0) - scaleRange.min) / normalizedRange).clamp(0.0, 1.0) * barHeight;
    final minHeight = (((minValue ?? 0) - scaleRange.min) / normalizedRange).clamp(0.0, 1.0) * barHeight;
    final lastHeight = (((lastValue ?? 0) - scaleRange.min) / normalizedRange).clamp(0.0, 1.0) * barHeight;
    const labelAboveOffset = 6.0;
    const labelBelowOffset = 18.0;
    final labelPositions = _resolveLabelPositions(
      maxPos: maxHeight + labelAboveOffset,
      minPos: minHeight - labelBelowOffset,
      lastPos: lastHeight + labelAboveOffset,
      barHeight: barHeight,
    );
    return Stack(
      alignment: Alignment.bottomCenter,
      children: <Widget>[
        Container(
          height: barHeight,
          decoration: BoxDecoration(color: const Color.fromARGB(30, 0, 0, 0)),
        ),
        if (!isEmpty && maxValue != null && minValue != null)
          Positioned(
            bottom: math.min(minHeight, maxHeight),
            left: 0,
            right: 0,
            child: Container(
              height: (maxHeight - minHeight).abs().clamp(2.0, barHeight),
              color: const Color(0x4D2F7BEA),
            ),
          ),
        if (!isEmpty)
          Positioned(
            bottom: maxHeight,
            left: 0,
            right: 0,
            child: const Divider(color: Color(0xFF000000), thickness: 2, height: 2),
          ),
        if (!isEmpty)
          Positioned(
            bottom: labelPositions.maxPos,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                maxLabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFF000000), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (!isEmpty)
          Positioned(
            bottom: minHeight,
            left: 0,
            right: 0,
            child: const Divider(color: Color(0xFFFFFFFF), thickness: 2, height: 2),
          ),
        if (!isEmpty)
          Positioned(
            bottom: labelPositions.minPos,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                minLabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (!isEmpty)
          Positioned(
            bottom: lastHeight,
            left: 0,
            right: 0,
            child: const Divider(color: Color(0xFF2F7BEA), thickness: 2, height: 2),
          ),
        if (!isEmpty)
          Positioned(
            bottom: labelPositions.lastPos,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                lastLabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFF2F7BEA), fontWeight: FontWeight.w600),
              ),
            ),
          ),
        if (isEmpty)
          const Center(
            child: Text('暂无数据', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          ),
      ],
    );
  }
}

class _LabelPositions {
  const _LabelPositions({required this.maxPos, required this.minPos, required this.lastPos});

  final double maxPos;
  final double minPos;
  final double lastPos;
}

_LabelPositions _resolveLabelPositions({
  required double maxPos,
  required double minPos,
  required double lastPos,
  required double barHeight,
}) {
  const minGap = 16.0;
  const topInset = 4.0;
  const bottomInset = 4.0;
  final entries = <_LabelEntry>[
    _LabelEntry(key: 'max', pos: maxPos),
    _LabelEntry(key: 'min', pos: minPos),
    _LabelEntry(key: 'last', pos: lastPos),
  ]..sort((a, b) => a.pos.compareTo(b.pos));

  for (int index = 1; index < entries.length; index++) {
    final prev = entries[index - 1];
    final current = entries[index];
    if (current.pos - prev.pos < minGap) {
      current.pos = prev.pos + minGap;
    }
  }

  final maxAllowed = barHeight - topInset;
  if (entries.last.pos > maxAllowed) {
    final overflow = entries.last.pos - maxAllowed;
    for (final entry in entries) {
      entry.pos -= overflow;
    }
  }

  if (entries.first.pos < bottomInset) {
    final offset = bottomInset - entries.first.pos;
    for (final entry in entries) {
      entry.pos += offset;
    }
  }

  double resolved(String key) {
    return entries.firstWhere((entry) => entry.key == key).pos;
  }

  return _LabelPositions(
    maxPos: resolved('max').clamp(bottomInset, barHeight - topInset),
    minPos: resolved('min').clamp(bottomInset, barHeight - topInset),
    lastPos: resolved('last').clamp(bottomInset, barHeight - topInset),
  );
}

class _LabelEntry {
  _LabelEntry({required this.key, required this.pos});

  final String key;
  double pos;
}

class _MetricSwitchButton extends StatelessWidget {
  const _MetricSwitchButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2F7BEA),
          side: const BorderSide(color: Color(0xFF2F7BEA)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('指标：$label', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

Future<void> _showPlanPicker(
  BuildContext context, {
  required List<String> planNames,
  required String? selectedName,
  required ValueChanged<String?> onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: const Text('清除选择'),
              onTap: () {
                onSelected(null);
                Navigator.of(context).pop();
              },
            ),
            const Divider(height: 1),
            if (planNames.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('暂无可选计划', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
                ),
              ),
            for (final name in planNames)
              ListTile(
                title: Text(name),
                trailing: name == selectedName ? const Icon(Icons.check, color: Color(0xFF2F7BEA)) : null,
                onTap: () {
                  onSelected(name);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}

Future<void> _showMetricPicker(
  BuildContext context, {
  required TimedSummaryMetric current,
  required List<MetricDefinition<TimedSummaryMetric>> definitions,
  required ValueChanged<TimedSummaryMetric> onSelected,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final definition in definitions)
              ListTile(
                title: Text(definition.label),
                subtitle: Text(definition.description),
                trailing: definition.metric == current ? const Icon(Icons.check, color: Color(0xFF2F7BEA)) : null,
                onTap: () {
                  onSelected(definition.metric);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      );
    },
  );
}

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

double _resolveScaleMax({
  required double? maxValue,
  required double? minValue,
  required double? lastValue,
}) {
  return _resolveScaleRangeFromValues(<double?>[maxValue, minValue, lastValue]).max;
}

_ScaleRange _resolveScaleRangeFromValues(List<double?> candidates) {
  final values = candidates.whereType<double>().where((value) => value.isFinite && value >= 0).toList();
  if (values.isEmpty) {
    return const _ScaleRange(min: 0.0, max: 10.0);
  }
  final resolvedMax = values.reduce(math.max);
  final resolvedMin = values.reduce(math.min);
  final minStep = _resolveScaleStep(resolvedMax);
  const desiredMinPos = 0.2;
  const desiredMaxPos = 0.8;
  final lowerBound = resolvedMax / 0.8;
  final upperBound = resolvedMin > 0 ? resolvedMin / 0.2 : double.infinity;
  var scaleMax = lowerBound;
  if (upperBound.isFinite && upperBound >= lowerBound) {
    scaleMax = lowerBound;
  }
  var scaleMin = 0.0;
  for (var index = 0; index < 2; index++) {
    final maxConstraint =
        scaleMin + (resolvedMax - scaleMin) / (desiredMaxPos == 0 ? 1 : desiredMaxPos);
    scaleMax = math.max(scaleMax, maxConstraint);
    scaleMax = (scaleMax / minStep).ceil() * minStep;
    scaleMax = math.max(minStep, scaleMax);
    final range = scaleMax - scaleMin;
    final minPos = range <= 0 ? 0.0 : (resolvedMin - scaleMin) / range;
    if (minPos < desiredMinPos) {
      final denominator = 1 - desiredMinPos;
      scaleMin = denominator == 0 ? scaleMin : (resolvedMin - desiredMinPos * scaleMax) / denominator;
      if (!scaleMin.isFinite) {
        scaleMin = 0.0;
      }
    }
  }
  return _ScaleRange(min: scaleMin, max: scaleMax);
}

double _resolveScaleStep(double maxValue) {
  if (maxValue <= 1.0) {
    return 0.1;
  }
  if (maxValue <= 5.0) {
    return 0.5;
  }
  if (maxValue <= 10.0) {
    return 1.0;
  }
  if (maxValue <= 50.0) {
    return 5.0;
  }
  return 10.0;
}

class _ScaleRange {
  const _ScaleRange({required this.min, required this.max});

  final double min;
  final double max;
}

String _formatMetricValue(TimedSummaryMetric metric, double? value) {
  if (value == null) {
    return 'N/A';
  }
  switch (metric) {
    case TimedSummaryMetric.controlCycles:
      return value.round().toString();
    case TimedSummaryMetric.dropMean:
    case TimedSummaryMetric.dropMax:
    case TimedSummaryMetric.dropStd:
      return '${(value * 100).toStringAsFixed(1)}%';
    case TimedSummaryMetric.fatigueSignal:
      return 'N/A';
    case TimedSummaryMetric.maxStrength:
    case TimedSummaryMetric.maxControlStrength:
    case TimedSummaryMetric.minControlStrength:
      return '${value.toStringAsFixed(1)}kg';
  }
}
