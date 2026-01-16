import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/training_record.dart';
import '../provider/training_record_provider.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(trainingRecordProvider).records;
    if (records.isEmpty) {
      return const Center(
        child: Text('暂无训练记录'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: records.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = records[index];
        return _RecordCard(
          record: record,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => _TrainingRecordDetailPage(record: record),
              ),
            );
          },
        );
      },
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final TrainingRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black45),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _formatDateTime(record.startedAt),
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _StatColumn(label: '最大值', value: record.statistics.maxValue),
                  _StatColumn(label: '平均值', value: record.statistics.averageValue),
                  _StatColumn(label: '中位数', value: record.statistics.medianValue),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        const SizedBox(height: 4),
        Text('${value.toStringAsFixed(1)}kg', style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _TrainingRecordDetailPage extends StatelessWidget {
  const _TrainingRecordDetailPage({required this.record});

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
            _formatDateTime(record.startedAt),
            style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
          ),
          const SizedBox(height: 16),
          _detailRow('锻炼 / 休息 / 循环', '${record.workSeconds} / ${record.restSeconds} / ${record.cycles}'),
          const SizedBox(height: 8),
          _detailRow('总时间', _formatDuration(record.totalSeconds)),
          const SizedBox(height: 16),
          const Text('统计数据', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _detailRow('最大值', '${record.statistics.maxValue.toStringAsFixed(1)}kg'),
          const SizedBox(height: 8),
          _detailRow('平均值', '${record.statistics.averageValue.toStringAsFixed(1)}kg'),
          const SizedBox(height: 8),
          _detailRow('中位数', '${record.statistics.medianValue.toStringAsFixed(1)}kg'),
          const SizedBox(height: 16),
          const Text('原始数据', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...record.samples.map(
            (sample) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _detailRow(
                '${sample.time.toStringAsFixed(1)}s',
                '${sample.value.toStringAsFixed(1)}kg',
              ),
            ),
          ),
        ],
      ),
    );
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

String _formatDateTime(DateTime dateTime) {
  final year = dateTime.year.toString().padLeft(4, '0');
  final month = dateTime.month.toString().padLeft(2, '0');
  final day = dateTime.day.toString().padLeft(2, '0');
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}

String _formatDuration(int totalSeconds) {
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
}
