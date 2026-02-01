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
        const Text('可视化参数', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        _FilterPanel(
          startDate: filter.startDate,
          endDate: filter.endDate,
          metric: filter.metric,
          definitions: metricDefinitions,
          recordDates: result.recordDates,
          onApply: (startDate, endDate, metric) {
            final notifier = ref.read(trainingCompareFilterProvider.notifier);
            notifier.setStartDate(startDate);
            notifier.setEndDate(endDate);
            notifier.setMetric(metric);
          },
          onReset: () => ref.read(trainingCompareFilterProvider.notifier).resetAll(),
        ),
      ],
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
        foregroundColor: const Color(0xFF111827),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
    final hasPlan = planName != null && planName!.isNotEmpty;
    final hasData = displayMax != null || displayMin != null;
    final maxLabel = 'Max: ${_formatMetricValue(metric, displayMax)}';
    final minLabel = 'Min: ${_formatMetricValue(metric, displayMin)}';
    final intermediateValues = _filterIntermediateValues(stats.values, displayMax, displayMin);
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
                      hasPlan ? planName! : '未选择计划',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.swap_horiz, size: 16, color: Color(0xFF2F7BEA)),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: _IndicatorBar(
                  maxValue: displayMax,
                  minValue: displayMin,
                  intermediateValues: intermediateValues,
                  scaleRange: scaleRange,
                  metric: metric,
                  isEmpty: !hasData,
                  maxLabel: maxLabel,
                  minLabel: minLabel,
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
    required this.intermediateValues,
    required this.scaleRange,
    required this.metric,
    required this.isEmpty,
    required this.maxLabel,
    required this.minLabel,
  });

  final double? maxValue;
  final double? minValue;
  final List<double> intermediateValues;
  final _ScaleRange scaleRange;
  final TimedSummaryMetric metric;
  final bool isEmpty;
  final String maxLabel;
  final String minLabel;

  @override
  Widget build(BuildContext context) {
    const barHeight = 300.0;
    final range = (scaleRange.max - scaleRange.min).abs();
    final normalizedRange = range <= 0 ? 1.0 : range;
    final maxHeight = (((maxValue ?? 0) - scaleRange.min) / normalizedRange).clamp(0.0, 1.0) * barHeight;
    final minHeight = (((minValue ?? 0) - scaleRange.min) / normalizedRange).clamp(0.0, 1.0) * barHeight;
    const labelAboveOffset = 6.0;
    const labelBelowOffset = 18.0;
    const indicatorColor = Color(0xFF2F7BEA);
    const dotColor = Color(0x802F7BEA);
    final labelPositions = _resolveLabelPositions(
      maxPos: maxHeight + labelAboveOffset,
      minPos: minHeight - labelBelowOffset,
      barHeight: barHeight,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final dotPositions = _buildIntermediateDotPositions(
          values: intermediateValues,
          scaleRange: scaleRange,
          normalizedRange: normalizedRange,
          barHeight: barHeight,
          maxWidth: constraints.maxWidth,
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
              for (final dot in dotPositions)
                Positioned(
                  bottom: dot.bottom,
                  left: dot.left,
                  child: Container(
                    width: dot.size,
                    height: dot.size,
                    decoration: const BoxDecoration(color: dotColor, shape: BoxShape.circle),
                  ),
                ),
            if (!isEmpty)
              Positioned(
                bottom: maxHeight,
                left: 0,
                right: 0,
                child: Divider(color: indicatorColor, thickness: 2, height: 2),
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
                child: Divider(color: indicatorColor, thickness: 2, height: 2),
              ),
            if (!isEmpty)
              Positioned(
                bottom: labelPositions.minPos,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    minLabel,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF000000), fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            if (isEmpty)
              const Center(
                child: Text('暂无数据', style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
              ),
          ],
        );
      },
    );
  }
}

class _LabelPositions {
  const _LabelPositions({required this.maxPos, required this.minPos});

  final double maxPos;
  final double minPos;
}

_LabelPositions _resolveLabelPositions({required double maxPos, required double minPos, required double barHeight}) {
  const minGap = 16.0;
  const topInset = 4.0;
  const bottomInset = 4.0;
  final entries = <_LabelEntry>[_LabelEntry(key: 'max', pos: maxPos), _LabelEntry(key: 'min', pos: minPos)]
    ..sort((a, b) => a.pos.compareTo(b.pos));

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
  );
}

class _LabelEntry {
  _LabelEntry({required this.key, required this.pos});

  final String key;
  double pos;
}

List<double> _filterIntermediateValues(List<double> values, double? maxValue, double? minValue) {
  const epsilon = 1e-6;
  return values.where((value) => value.isFinite).where((value) {
    final isMax = maxValue != null && (value - maxValue).abs() <= epsilon;
    final isMin = minValue != null && (value - minValue).abs() <= epsilon;
    return !isMax && !isMin;
  }).toList();
}

class _DotPosition {
  const _DotPosition({required this.left, required this.bottom, required this.size});

  final double left;
  final double bottom;
  final double size;
}

List<_DotPosition> _buildIntermediateDotPositions({
  required List<double> values,
  required _ScaleRange scaleRange,
  required double normalizedRange,
  required double barHeight,
  required double maxWidth,
}) {
  const dotSize = 3.0;
  const horizontalPadding = 8.0;
  final availableWidth = math.max(0.0, maxWidth - horizontalPadding * 2);
  final grouped = <double, List<double>>{};
  for (final value in values) {
    grouped.putIfAbsent(value, () => <double>[]).add(value);
  }
  final positions = <_DotPosition>[];
  for (final entry in grouped.entries) {
    final value = entry.key;
    final count = entry.value.length;
    final bottom = (((value - scaleRange.min) / normalizedRange).clamp(0.0, 1.0) * barHeight);
    if (count <= 1) {
      final left = horizontalPadding + (availableWidth - dotSize) / 2;
      positions.add(_DotPosition(left: left, bottom: bottom - dotSize / 2, size: dotSize));
      continue;
    }
    final span = math.min(availableWidth, (count - 1) * (dotSize + 4));
    final start = horizontalPadding + (availableWidth - span) / 2;
    final step = count > 1 ? span / (count - 1) : 0.0;
    for (int index = 0; index < count; index++) {
      final left = start + step * index;
      positions.add(_DotPosition(left: left, bottom: bottom - dotSize / 2, size: dotSize));
    }
  }
  return positions;
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.startDate,
    required this.endDate,
    required this.metric,
    required this.definitions,
    required this.recordDates,
    required this.onApply,
    required this.onReset,
  });

  final DateTime startDate;
  final DateTime endDate;
  final TimedSummaryMetric metric;
  final List<MetricDefinition<TimedSummaryMetric>> definitions;
  final Set<DateTime> recordDates;
  final void Function(DateTime startDate, DateTime endDate, TimedSummaryMetric metric) onApply;
  final VoidCallback onReset;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late DateTime _draftStartDate;
  late DateTime _draftEndDate;
  late TimedSummaryMetric _draftMetric;
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _draftStartDate = widget.startDate;
    _draftEndDate = widget.endDate;
    _draftMetric = widget.metric;
  }

  @override
  void didUpdateWidget(_FilterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDirty &&
        (widget.startDate != _draftStartDate || widget.endDate != _draftEndDate || widget.metric != _draftMetric)) {
      _draftStartDate = widget.startDate;
      _draftEndDate = widget.endDate;
      _draftMetric = widget.metric;
    }
  }

  @override
  Widget build(BuildContext context) {
    final metricLabel = timedSummaryMetricDefinitionMap[_draftMetric]?.label ?? '指标';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('时间范围', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            Row(
              children: <Widget>[
                Expanded(
                  child: _DateButton(label: _formatDate(_draftStartDate), onTap: _pickDraftStartDate),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Text('至', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
                ),
                Expanded(
                  child: _DateButton(label: _formatDate(_draftEndDate), onTap: _pickDraftEndDate),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('指标', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            const SizedBox(height: 2),
            _MetricSelector(label: metricLabel, onTap: _pickDraftMetric),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _resetToDefaults,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B7280),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('重置', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _applyChanges,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2F7BEA),
                    side: const BorderSide(color: Color(0xFF2F7BEA)),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('更新', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDraftStartDate() async {
    final picked = await _showCompactDatePicker(
      context,
      initialDate: _draftStartDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      highlightedDates: widget.recordDates,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _draftStartDate = picked;
      if (_draftEndDate.isBefore(_draftStartDate)) {
        _draftEndDate = _draftStartDate;
      }
      _isDirty = true;
    });
  }

  Future<void> _pickDraftEndDate() async {
    final picked = await _showCompactDatePicker(
      context,
      initialDate: _draftEndDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      highlightedDates: widget.recordDates,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _draftEndDate = picked;
      if (_draftStartDate.isAfter(_draftEndDate)) {
        _draftStartDate = _draftEndDate;
      }
      _isDirty = true;
    });
  }

  Future<void> _pickDraftMetric() async {
    await _showMetricPicker(
      context,
      current: _draftMetric,
      definitions: widget.definitions,
      onSelected: (metric) {
        setState(() {
          _draftMetric = metric;
          _isDirty = true;
        });
      },
    );
  }

  void _applyChanges() {
    widget.onApply(_draftStartDate, _draftEndDate, _draftMetric);
    setState(() {
      _isDirty = false;
    });
  }

  void _resetToDefaults() {
    widget.onReset();
    setState(() {
      _draftStartDate = widget.startDate;
      _draftEndDate = widget.endDate;
      _draftMetric = widget.metric;
      _isDirty = false;
    });
  }
}

class _MetricSelector extends StatelessWidget {
  const _MetricSelector({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF111827),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF6B7280)),
        ],
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

Future<DateTime?> _showCompactDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required Set<DateTime> highlightedDates,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (context) {
      return _CompactDatePickerDialog(
        initialDate: initialDate,
        firstDate: firstDate,
        lastDate: lastDate,
        highlightedDates: highlightedDates,
      );
    },
  );
}

class _CompactDatePickerDialog extends StatefulWidget {
  const _CompactDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.highlightedDates,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final Set<DateTime> highlightedDates;

  @override
  State<_CompactDatePickerDialog> createState() => _CompactDatePickerDialogState();
}

class _CompactDatePickerDialogState extends State<_CompactDatePickerDialog> {
  late DateTime _displayedMonth;
  late DateTime _selectedDate;
  late Set<int> _highlightedKeys;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(widget.initialDate);
    _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    _highlightedKeys = widget.highlightedDates.map(_dateKey).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = '${_displayedMonth.year}年${_displayedMonth.month}月';
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  onPressed: _canMoveMonth(-1) ? () => _shiftMonth(-1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _canMoveMonth(1) ? () => _shiftMonth(1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildWeekdayHeader(),
            const SizedBox(height: 6),
            _buildCalendarGrid(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
                const SizedBox(width: 8),
                TextButton(onPressed: () => Navigator.of(context).pop(_selectedDate), child: const Text('确定')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = <String>['一', '二', '三', '四', '五', '六', '日'];
    return Row(
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    final startOffset = firstDay.weekday - 1;
    const totalCells = 42;
    return GridView.builder(
      itemCount: totalCells,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisExtent: 36),
      itemBuilder: (context, index) {
        final day = index - startOffset + 1;
        if (day < 1 || day > daysInMonth) {
          return const SizedBox.shrink();
        }
        final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
        final inRange =
            !_dateOnly(date).isBefore(_dateOnly(widget.firstDate)) &&
            !_dateOnly(date).isAfter(_dateOnly(widget.lastDate));
        final isSelected = _isSameDay(date, _selectedDate);
        final isHighlighted = _highlightedKeys.contains(_dateKey(date));
        final textStyle = TextStyle(
          fontSize: 12,
          fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.normal,
          color: inRange ? const Color(0xFF111827) : const Color(0xFF9CA3AF),
        );
        return GestureDetector(
          onTap: inRange
              ? () {
                  setState(() {
                    _selectedDate = _dateOnly(date);
                  });
                }
              : null,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: isSelected
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2F7BEA), width: 1.5),
                    )
                  : null,
              child: Text(day.toString(), style: textStyle),
            ),
          ),
        );
      },
    );
  }

  bool _canMoveMonth(int delta) {
    final target = DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
    final minMonth = DateTime(widget.firstDate.year, widget.firstDate.month, 1);
    final maxMonth = DateTime(widget.lastDate.year, widget.lastDate.month, 1);
    return !target.isBefore(minMonth) && !target.isAfter(maxMonth);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + delta, 1);
    });
  }
}

int _dateKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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
  final posSpan = desiredMaxPos - desiredMinPos;
  final safeSpan = posSpan == 0 ? 1.0 : posSpan;
  final targetRange = (resolvedMax - resolvedMin) / safeSpan;
  var scaleMax = resolvedMax + (1 - desiredMaxPos) * targetRange;
  scaleMax = math.max(minStep, (scaleMax / minStep).ceil() * minStep);
  var scaleMin = 0.0;
  for (var index = 0; index < 10; index++) {
    final minDenominator = 1 - desiredMinPos;
    final maxDenominator = 1 - desiredMaxPos;
    final lowerBoundMin = maxDenominator == 0 ? scaleMin : (resolvedMax - desiredMaxPos * scaleMax) / maxDenominator;
    final upperBoundMin = minDenominator == 0 ? scaleMin : (resolvedMin - desiredMinPos * scaleMax) / minDenominator;
    if (lowerBoundMin > upperBoundMin) {
      scaleMax += minStep;
      continue;
    }
    final snappedUpper = (upperBoundMin / minStep).floor() * minStep;
    if (snappedUpper < lowerBoundMin) {
      scaleMax += minStep;
      continue;
    }
    scaleMin = snappedUpper;
    break;
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
