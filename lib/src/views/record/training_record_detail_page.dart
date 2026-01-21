import 'package:flutter/material.dart';

import '../../models/training_record.dart';
import 'record_formatters.dart';

class TrainingRecordDetailPage extends StatelessWidget {
  const TrainingRecordDetailPage({required this.record, super.key});

  final TrainingRecord record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('训练详情'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: <Widget>[
          Text(record.planName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            formatRecordDateTime(record.startedAt),
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
          ),
          const SizedBox(height: 16),
          _detailRow('锻炼 / 休息 / 循环', '${record.workSeconds} / ${record.restSeconds} / ${record.cycles}'),
          const SizedBox(height: 8),
          _detailRow('总时间', formatRecordDuration(record.totalSeconds)),
          const SizedBox(height: 16),
          const Text('统计数据', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _detailRow('最大力量', _formatWeight(record.statistics.maxStrengthSession)),
          const SizedBox(height: 8),
          _detailRow('最大控制力量', _formatWeight(record.statistics.maxControlStrengthSession)),
          const SizedBox(height: 8),
          _detailRow('控制循环数', _formatCount(record.statistics.controlCycles)),
          const SizedBox(height: 8),
          _detailRow('力竭信号', _formatFatigue(record.statistics)),
          const SizedBox(height: 8),
          _detailRow('最低控制力量', _formatMinControl(record.statistics)),
          const SizedBox(height: 8),
          _detailRow('降幅均值', _formatPercent(record.statistics.dropMean)),
          const SizedBox(height: 8),
          _detailRow('降幅最大', _formatPercent(record.statistics.dropMax)),
          const SizedBox(height: 8),
          _detailRow('降幅标准差', _formatPercent(record.statistics.dropStd)),
          const SizedBox(height: 16),
          const Text('原始数据', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._buildGroupedRows(),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedRows() {
    if (record.groupedSamples.isEmpty) {
      return const <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text('N/A', style: TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
        ),
      ];
    }
    return record.groupedSamples
        .map(
          (group) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('第 ${group.cycle} 组', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              ...group.samples.map(
                (sample) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: _detailRow(
                    '${sample.time.toStringAsFixed(1)}s',
                    '${sample.value.toStringAsFixed(1)}kg',
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        )
        .toList();
  }

  String _formatWeight(double value) {
    if (record.groupedSamples.isEmpty || value.isNaN || value.isInfinite) {
      return 'N/A';
    }
    return '${value.toStringAsFixed(1)}kg';
  }

  String _formatCount(int value) {
    if (record.groupedSamples.isEmpty) {
      return 'N/A';
    }
    return value.toString();
  }

  String _formatFatigue(TrainingStatistics statistics) {
    if (record.groupedSamples.isEmpty) {
      return 'N/A';
    }
    if (statistics.fatigueStartCycle <= 0) {
      return '未触发';
    }
    return '第${statistics.fatigueStartCycle}轮 / ${statistics.fatigueStartTime.toStringAsFixed(1)}s';
  }

  String _formatMinControl(TrainingStatistics statistics) {
    if (record.groupedSamples.isEmpty) {
      return 'N/A';
    }
    if (statistics.fatigueStartCycle <= 0) {
      return '未触发';
    }
    if (statistics.minControlStrengthMissing) {
      return '缺失';
    }
    return _formatWeight(statistics.minControlStrength);
  }

  String _formatPercent(double value) {
    if (record.groupedSamples.isEmpty || value.isNaN || value.isInfinite) {
      return 'N/A';
    }
    if (record.statistics.fatigueStartCycle <= 0) {
      return 'N/A';
    }
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
