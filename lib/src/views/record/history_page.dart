import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/free_training_record.dart';
import '../../models/metric_definitions.dart';
import '../../models/training_record.dart';
import '../../providers/free_training_record_provider.dart';
import '../../providers/metric_visibility_provider.dart';
import '../../providers/training_record_provider.dart';
import 'overview_page.dart';
import 'widgets/free_training_record_card.dart';
import 'widgets/record_calendar.dart';
import 'widgets/record_card.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final Set<RecordTrainingType> _selectedTypes = <RecordTrainingType>{RecordTrainingType.timed};
  final Set<TimedSummaryMetric> _timedSummary = <TimedSummaryMetric>{
    TimedSummaryMetric.maxControlStrength,
    TimedSummaryMetric.fatigueSignal,
    TimedSummaryMetric.minControlStrength,
  };
  final Set<FreeSummaryMetric> _freeSummary = <FreeSummaryMetric>{
    FreeSummaryMetric.totalDuration,
    FreeSummaryMetric.controlMax,
    FreeSummaryMetric.longestControl,
  };
  TimedBarMetric _timedBarMetric = TimedBarMetric.averageStrength;

  @override
  Widget build(BuildContext context) {
    final recordState = ref.watch(trainingRecordProvider);
    final freeRecordState = ref.watch(freeTrainingRecordProvider);
    final records = recordState.records;
    final freeRecords = freeRecordState.records;
    final recordDates = <DateTime>[
      for (final record in freeRecords) DateUtils.dateOnly(record.startedAt),
      for (final record in records) DateUtils.dateOnly(record.startedAt),
    ];
    final items = <Widget>[
      const _SectionTitle(title: '训练日历'),
      const SizedBox(height: 8),
      RecordCalendar(recordDates: recordDates),
      const SizedBox(height: 16),
      _OverviewEntryButton(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const OverviewPage())),
      ),
      const SizedBox(height: 16),
    ];
    const listPadding = EdgeInsets.fromLTRB(16, 16, 16, 120);
    if (records.isEmpty && freeRecords.isEmpty) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('暂无训练记录', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
          ),
        ),
      );
      return SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: <Widget>[
            ListView(padding: listPadding, children: items),
            Positioned(
              right: 16,
              bottom: 16,
              child: _RecordActionButtons(
                onClear: () => _handleClearRecords(context),
                onBuild: () => _handleBuildRecords(context),
              ),
            ),
          ],
        ),
      );
    }
    items
      ..add(_RecordSectionHeader(onFilterTap: () => _openFilterPanel(context)))
      ..add(const SizedBox(height: 8))
      ..addAll(_buildGroupedRecords(context, freeRecords, records));
    return SafeArea(
      top: true,
      bottom: false,
      child: Stack(
        children: <Widget>[
          ListView(padding: listPadding, children: items),
          Positioned(
            right: 16,
            bottom: 16,
            child: _RecordActionButtons(
              onClear: () => _handleClearRecords(context),
              onBuild: () => _handleBuildRecords(context),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedRecords(
    BuildContext context,
    List<FreeTrainingRecord> freeRecords,
    List<TrainingRecord> timedRecords,
  ) {
    final includeTimed = _selectedTypes.contains(RecordTrainingType.timed);
    final includeFree = _selectedTypes.contains(RecordTrainingType.free);
    final entries = <_RecordEntry>[
      if (includeFree)
        for (final record in freeRecords)
          _RecordEntry(startedAt: record.startedAt, buildCard: (context) => _buildFreeRecordCard(context, record)),
      if (includeTimed)
        for (final record in timedRecords)
          _RecordEntry(startedAt: record.startedAt, buildCard: (context) => _buildTimedRecordCard(context, record)),
    ]..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    if (entries.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text('暂无训练记录', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E8E))),
          ),
        ),
      ];
    }

    final grouped = <DateTime, List<_RecordEntry>>{};
    for (final entry in entries) {
      final date = DateUtils.dateOnly(entry.startedAt);
      grouped.putIfAbsent(date, () => <_RecordEntry>[]).add(entry);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = <Widget>[];
    for (final date in dates) {
      final dayEntries = grouped[date] ?? <_RecordEntry>[];
      items.add(_DateHeader(title: _formatDateSection(date)));
      items.add(const SizedBox(height: 8));
      items.add(_RecordCarousel(entries: dayEntries));
      items.add(const SizedBox(height: 16));
    }
    return items;
  }

  Widget _buildFreeRecordCard(BuildContext context, FreeTrainingRecord record) {
    final metrics = _freeSummary.toList()..sort((a, b) => a.index.compareTo(b.index));
    return FreeTrainingRecordCard(
      record: record,
      summaryMetrics: metrics,
      onLongPress: () => _confirmDeleteFreeRecord(record),
    );
  }

  Widget _buildTimedRecordCard(BuildContext context, TrainingRecord record) {
    final metrics = _timedSummary.toList()..sort((a, b) => a.index.compareTo(b.index));
    return RecordCard(
      record: record,
      summaryMetrics: metrics,
      barMetric: _timedBarMetric,
      onLongPress: () => _confirmDeleteTimedRecord(record),
    );
  }

  Future<void> _confirmDeleteTimedRecord(TrainingRecord record) async {
    final shouldDelete = await _showDeleteConfirm(context, title: '删除计时训练记录', content: '确定删除该记录吗？此操作不可撤销。');
    if (!shouldDelete) {
      return;
    }
    ref.read(trainingRecordProvider.notifier).removeRecord(record.id);
  }

  Future<void> _confirmDeleteFreeRecord(FreeTrainingRecord record) async {
    final shouldDelete = await _showDeleteConfirm(context, title: '删除自由训练记录', content: '确定删除该记录吗？此操作不可撤销。');
    if (!shouldDelete) {
      return;
    }
    ref.read(freeTrainingRecordProvider.notifier).removeRecord(record.id);
  }

  Future<bool> _showDeleteConfirm(BuildContext context, {required String title, required String content}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('删除')),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<bool> _showConfirmDialog(
    BuildContext context, {
    required String title,
    required String content,
    String cancelLabel = '取消',
    String confirmLabel = '确认',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelLabel)),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(confirmLabel)),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _handleClearRecords(BuildContext context) async {
    final shouldClear = await _showDeleteConfirm(
      context,
      title: '清空记录',
      content: '确定清空所有记录吗？此操作不可撤销。',
    );
    if (!shouldClear) {
      return;
    }
    ref.read(trainingRecordProvider.notifier).clearAllRecords();
    ref.read(freeTrainingRecordProvider.notifier).clearAllRecords();
  }

  Future<void> _handleBuildRecords(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateUtils.dateOnly(DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (!mounted) {
      return;
    }
    if (picked == null) {
      return;
    }
    final shouldBuild = await _showConfirmDialog(
      context,
      title: '构造记录',
      content: '确认构造 ${_formatShortDate(picked)} 的训练记录吗？',
    );
    if (!shouldBuild) {
      return;
    }
    ref.read(trainingRecordProvider.notifier).buildRecordsForDate(picked);
  }

  void _openFilterPanel(BuildContext context) {
    final visibility = ref.read(metricVisibilityProvider);
    final timedDefinitions = timedSummaryMetricDefinitions
        .where((definition) => visibility.timedVisibility(definition.metric).showInFilter)
        .toList();
    final freeDefinitions = freeSummaryMetricDefinitions
        .where((definition) => visibility.freeVisibility(definition.metric).showInFilter)
        .toList();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              child: Container(
                width: 300,
                margin: const EdgeInsets.only(left: 24),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: _FilterPanel(
                  selectedTypes: _selectedTypes,
                  timedSummary: _timedSummary,
                  freeSummary: _freeSummary,
                  timedBarMetric: _timedBarMetric,
                  timedDefinitions: timedDefinitions,
                  freeDefinitions: freeDefinitions,
                  onChanged: (selectedTypes, timedSummary, freeSummary, timedBarMetric) {
                    setState(() {
                      _selectedTypes
                        ..clear()
                        ..addAll(selectedTypes);
                      _timedSummary
                        ..clear()
                        ..addAll(timedSummary);
                      _freeSummary
                        ..clear()
                        ..addAll(freeSummary);
                      _timedBarMetric = timedBarMetric;
                    });
                  },
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final offsetTween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
        return SlideTransition(position: animation.drive(offsetTween), child: child);
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.black87),
    );
  }
}

class _RecordSectionHeader extends StatelessWidget {
  const _RecordSectionHeader({required this.onFilterTap});

  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: _SectionTitle(title: '记录')),
        IconButton(
          onPressed: onFilterTap,
          icon: const Icon(Icons.filter_alt_outlined),
          tooltip: '筛选',
          color: const Color(0xFF5B5B5B),
        ),
      ],
    );
  }
}

class _OverviewEntryButton extends StatelessWidget {
  const _OverviewEntryButton({required this.onTap});

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
        child: const Text('可视化数据统计', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _RecordActionButtons extends StatelessWidget {
  const _RecordActionButtons({required this.onClear, required this.onBuild});

  final VoidCallback onClear;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: 120,
              child: OutlinedButton(
                onPressed: onClear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE35D5B),
                  side: const BorderSide(color: Color(0xFFE35D5B)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('清空记录', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 120,
              child: ElevatedButton(
                onPressed: onBuild,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F7BEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('构造记录', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
    );
  }
}

class _RecordCarousel extends StatelessWidget {
  const _RecordCarousel({required this.entries});

  final List<_RecordEntry> entries;

  @override
  Widget build(BuildContext context) {
    const itemWidth = 300.0;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Row(
        children: <Widget>[
          for (int index = 0; index < entries.length; index++) ...<Widget>[
            SizedBox(width: itemWidth, child: entries[index].buildCard(context)),
            if (index != entries.length - 1) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _RecordEntry {
  const _RecordEntry({required this.startedAt, required this.buildCard});

  final DateTime startedAt;
  final Widget Function(BuildContext context) buildCard;
}

String _formatDateSection(DateTime date) {
  final today = DateUtils.dateOnly(DateTime.now());
  final isToday = _isSameDate(date, today);
  final month = date.month;
  final day = date.day;
  const weekdays = <String>['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
  final weekdayLabel = weekdays[date.weekday - 1];
  if (isToday) {
    return '今日, $month月$day日, $weekdayLabel';
  }
  return '$month月$day日, $weekdayLabel';
}

bool _isSameDate(DateTime left, DateTime right) {
  return left.year == right.year && left.month == right.month && left.day == right.day;
}

String _formatShortDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

class _FilterPanel extends StatefulWidget {
  const _FilterPanel({
    required this.selectedTypes,
    required this.timedSummary,
    required this.freeSummary,
    required this.timedBarMetric,
    required this.timedDefinitions,
    required this.freeDefinitions,
    required this.onChanged,
  });

  final Set<RecordTrainingType> selectedTypes;
  final Set<TimedSummaryMetric> timedSummary;
  final Set<FreeSummaryMetric> freeSummary;
  final TimedBarMetric timedBarMetric;
  final List<MetricDefinition<TimedSummaryMetric>> timedDefinitions;
  final List<MetricDefinition<FreeSummaryMetric>> freeDefinitions;
  final void Function(
    Set<RecordTrainingType> selectedTypes,
    Set<TimedSummaryMetric> timedSummary,
    Set<FreeSummaryMetric> freeSummary,
    TimedBarMetric timedBarMetric,
  )
  onChanged;

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late Set<RecordTrainingType> _selectedTypes;
  late Set<TimedSummaryMetric> _timedSummary;
  late Set<FreeSummaryMetric> _freeSummary;
  late TimedBarMetric _timedBarMetric;

  @override
  void initState() {
    super.initState();
    _selectedTypes = Set<RecordTrainingType>.from(widget.selectedTypes);
    _timedSummary = Set<TimedSummaryMetric>.from(widget.timedSummary);
    _freeSummary = Set<FreeSummaryMetric>.from(widget.freeSummary);
    _timedBarMetric = widget.timedBarMetric;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
          child: Row(
            children: <Widget>[
              const Expanded(
                child: Text('筛选条件', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close), tooltip: '关闭'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: <Widget>[
              const _FilterSectionTitle(title: '训练类型'),
              const SizedBox(height: 8),
              for (final type in RecordTrainingType.values)
                _FilterCheckboxRow(
                  label: recordTrainingTypeLabel(type),
                  value: _selectedTypes.contains(type),
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _selectedTypes.add(type);
                      } else {
                        _selectedTypes.remove(type);
                      }
                    });
                  },
                ),
              const SizedBox(height: 16),
              const _FilterSectionTitle(title: '指标类型'),
              const SizedBox(height: 8),
              const _FilterSubTitle(title: '计时训练'),
              const SizedBox(height: 4),
              for (final definition in widget.timedDefinitions)
                _FilterCheckboxRow(
                  label: definition.label,
                  value: _timedSummary.contains(definition.metric),
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _timedSummary.add(definition.metric);
                      } else {
                        _timedSummary.remove(definition.metric);
                      }
                    });
                  },
                ),
              const SizedBox(height: 12),
              const _FilterSubTitle(title: '自由训练'),
              const SizedBox(height: 4),
              for (final definition in widget.freeDefinitions)
                _FilterCheckboxRow(
                  label: definition.label,
                  value: _freeSummary.contains(definition.metric),
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _freeSummary.add(definition.metric);
                      } else {
                        _freeSummary.remove(definition.metric);
                      }
                    });
                  },
                ),
              const SizedBox(height: 16),
              const _FilterSectionTitle(title: '柱状图指标 · 计时训练'),
              const SizedBox(height: 8),
              RadioGroup<TimedBarMetric>(
                groupValue: _timedBarMetric,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _timedBarMetric = value);
                },
                child: Column(
                  children: <Widget>[
                    for (final metric in TimedBarMetric.values)
                      _FilterRadioRow<TimedBarMetric>(label: timedBarMetricLabel(metric), value: metric),
                  ],
                ),
              ),
            ],
          ),
        ),
        _FilterApplyBar(
          onApply: () {
            _applySelections();
            Navigator.of(context).pop();
          },
          onReset: _resetSelections,
        ),
      ],
    );
  }

  void _resetSelections() {
    const defaultTimed = <TimedSummaryMetric>{
      TimedSummaryMetric.maxControlStrength,
      TimedSummaryMetric.fatigueSignal,
      TimedSummaryMetric.minControlStrength,
    };
    const defaultFree = <FreeSummaryMetric>{
      FreeSummaryMetric.totalDuration,
      FreeSummaryMetric.controlMax,
      FreeSummaryMetric.longestControl,
    };
    setState(() {
      _selectedTypes
        ..clear()
        ..add(RecordTrainingType.timed);
      _timedSummary
        ..clear()
        ..addAll(widget.timedDefinitions.map((definition) => definition.metric).where(defaultTimed.contains));
      _freeSummary
        ..clear()
        ..addAll(widget.freeDefinitions.map((definition) => definition.metric).where(defaultFree.contains));
      _timedBarMetric = TimedBarMetric.averageStrength;
    });
  }

  void _applySelections() {
    widget.onChanged(
      Set<RecordTrainingType>.from(_selectedTypes),
      Set<TimedSummaryMetric>.from(_timedSummary),
      Set<FreeSummaryMetric>.from(_freeSummary),
      _timedBarMetric,
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  const _FilterSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700));
  }
}

class _FilterSubTitle extends StatelessWidget {
  const _FilterSubTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E8E)),
    );
  }
}

class _FilterCheckboxRow extends StatelessWidget {
  const _FilterCheckboxRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        children: <Widget>[
          Checkbox(value: value, onChanged: (value) => onChanged(value ?? false)),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _FilterRadioRow<T> extends StatelessWidget {
  const _FilterRadioRow({required this.label, required this.value});

  final String label;
  final T value;

  @override
  Widget build(BuildContext context) {
    final registry = RadioGroup.maybeOf<T>(context);
    return InkWell(
      onTap: () => registry?.onChanged(value),
      child: Row(
        children: <Widget>[
          Radio<T>(value: value),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _FilterApplyBar extends StatelessWidget {
  const _FilterApplyBar({required this.onApply, required this.onReset});

  final VoidCallback onApply;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
          color: Colors.white,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2F7BEA),
                  side: const BorderSide(color: Color(0xFF2F7BEA)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('重置', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F7BEA),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('应用', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
