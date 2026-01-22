import 'package:flutter/material.dart';

import '../../../models/training_record.dart';
import '../../../models/metric_definitions.dart';
import '../record_formatters.dart';
import '../training_record_detail_page.dart';

class RecordCard extends StatelessWidget {
  const RecordCard({
    required this.record,
    required this.summaryMetrics,
    required this.barMetric,
    this.onLongPress,
    super.key,
  });

  final TrainingRecord record;
  final List<TimedSummaryMetric> summaryMetrics;
  final TimedBarMetric barMetric;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final hasStatistics = record.groupedSamples.isNotEmpty;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrainingRecordDetailPage(record: record)));
        },
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      record.planName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFFB0B0B0)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      formatRecordDateTime(record.startedAt),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${record.workSeconds}/${record.restSeconds}/${record.cycles} · ${formatRecordDuration(record.totalSeconds)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _CycleBarChart(statistics: record.statistics, metric: barMetric),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  return _StatGrid(
                    maxWidth: constraints.maxWidth,
                    children: summaryMetrics.map((metric) => _buildSummary(metric, hasStatistics)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatColumn _buildSummary(TimedSummaryMetric metric, bool hasStatistics) {
    final definition = timedSummaryMetricDefinitionMap[metric];
    switch (metric) {
      case TimedSummaryMetric.maxStrength:
        return _StatColumn(
          label: definition?.shortLabel ?? '最大力量',
          value: _formatWeight(record.statistics.maxStrengthSession, hasStatistics),
        );
      case TimedSummaryMetric.maxControlStrength:
        return _StatColumn(
          label: definition?.shortLabel ?? '最大控制力量',
          value: _formatWeight(record.statistics.maxControlStrengthSession, hasStatistics),
        );
      case TimedSummaryMetric.controlCycles:
        return _StatColumn(
          label: definition?.shortLabel ?? '控制循环数',
          value: _formatCount(record.statistics.controlCycles, hasStatistics),
        );
      case TimedSummaryMetric.fatigueSignal:
        return _StatColumn(
          label: definition?.shortLabel ?? '力竭信号',
          value: _formatFatigue(record.statistics, hasStatistics),
        );
      case TimedSummaryMetric.minControlStrength:
        return _StatColumn(
          label: definition?.shortLabel ?? '最低控制力量',
          value: _formatMinControl(record.statistics, hasStatistics),
        );
      case TimedSummaryMetric.dropMean:
        return _StatColumn(
          label: definition?.shortLabel ?? '降幅均值',
          value: _formatPercent(record.statistics.dropMean, record.statistics, hasStatistics),
        );
      case TimedSummaryMetric.dropMax:
        return _StatColumn(
          label: definition?.shortLabel ?? '降幅最大',
          value: _formatPercent(record.statistics.dropMax, record.statistics, hasStatistics),
        );
      case TimedSummaryMetric.dropStd:
        return _StatColumn(
          label: definition?.shortLabel ?? '降幅标准差',
          value: _formatPercent(record.statistics.dropStd, record.statistics, hasStatistics),
        );
    }
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _CycleBarChart extends StatelessWidget {
  const _CycleBarChart({required this.statistics, required this.metric});

  final TrainingStatistics statistics;
  final TimedBarMetric metric;

  @override
  Widget build(BuildContext context) {
    final cycles = statistics.cycleStatistics;
    if (cycles.isEmpty) {
      return Container(
        height: 44,
        decoration: BoxDecoration(color: const Color(0xFFF5F6FA), borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: const Text('暂无曲线', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
      );
    }
    final maxValue = cycles.fold<double>(0.0, (max, stat) {
      final value = _cycleMetricValue(stat, metric);
      return value > max ? value : max;
    });
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          if (maxWidth <= 0 || cycles.isEmpty) {
            return const SizedBox.shrink();
          }
          final count = cycles.length;
          var spacing = count > 1 ? 4.0 : 0.0;
          var available = maxWidth - spacing * (count - 1);
          if (available <= 0) {
            spacing = 0.0;
            available = maxWidth;
          }
          var barWidth = available / count;
          if (barWidth < 2) {
            barWidth = 2;
            final required = barWidth * count + spacing * (count - 1);
            if (required > maxWidth) {
              spacing = 0.0;
              barWidth = maxWidth / count;
            }
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int index = 0; index < count; index++) ...<Widget>[
                SizedBox(
                  width: barWidth,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: _barHeight(cycles[index], safeMax),
                      decoration: BoxDecoration(color: const Color(0xFF2F7BEA), borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
                if (index != count - 1) SizedBox(width: spacing),
              ],
            ],
          );
        },
      ),
    );
  }

  double _barHeight(TrainingCycleStatistics statistics, double safeMax) {
    final value = _cycleMetricValue(statistics, metric);
    if (value <= 0) {
      return 0;
    }
    return 36 * (value / safeMax);
  }
}

String _formatWeight(double value, bool isAvailable) {
  if (!isAvailable || value.isNaN || value.isInfinite) {
    return 'N/A';
  }
  return '${value.toStringAsFixed(1)}kg';
}

String _formatCount(int value, bool isAvailable) {
  if (!isAvailable) {
    return 'N/A';
  }
  return value.toString();
}

String _formatFatigue(TrainingStatistics statistics, bool isAvailable) {
  if (!isAvailable) {
    return 'N/A';
  }
  if (statistics.fatigueStartCycle <= 0) {
    return '未触发';
  }
  return '第${statistics.fatigueStartCycle}轮';
}

String _formatMinControl(TrainingStatistics statistics, bool isAvailable) {
  if (!isAvailable) {
    return 'N/A';
  }
  if (statistics.fatigueStartCycle <= 0) {
    return '未触发';
  }
  if (statistics.minControlStrengthMissing) {
    return '缺失';
  }
  return _formatWeight(statistics.minControlStrength, true);
}

String _formatPercent(double value, TrainingStatistics statistics, bool isAvailable) {
  if (!isAvailable || value.isNaN || value.isInfinite) {
    return 'N/A';
  }
  if (statistics.fatigueStartCycle <= 0) {
    return 'N/A';
  }
  return '${(value * 100).toStringAsFixed(1)}%';
}

double _cycleMetricValue(TrainingCycleStatistics statistics, TimedBarMetric metric) {
  switch (metric) {
    case TimedBarMetric.averageStrength:
      return statistics.averageStrength;
    case TimedBarMetric.maxStrength:
      return statistics.maxStrength;
    case TimedBarMetric.controlStrength:
      return statistics.controlStrength;
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.maxWidth, required this.children});

  final double maxWidth;
  final List<_StatColumn> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    const columns = 3;
    final rows = <List<_StatColumn>>[];
    for (int i = 0; i < children.length; i += columns) {
      rows.add(children.sublist(i, (i + columns).clamp(0, children.length)));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) ...<Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              for (final child in rows[rowIndex]) IntrinsicWidth(child: child),
            ],
          ),
          if (rowIndex != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }
}
