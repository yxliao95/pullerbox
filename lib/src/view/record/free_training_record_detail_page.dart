import 'package:flutter/material.dart';

import '../../models/free_training_record.dart';
import 'record_formatters.dart';

class FreeTrainingRecordDetailPage extends StatelessWidget {
  const FreeTrainingRecordDetailPage({required this.record, super.key});

  final FreeTrainingRecord record;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('自由训练记录')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(record.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            formatRecordDateTime(record.startedAt),
            style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E8E)),
          ),
          const SizedBox(height: 16),
          _detailRow('总时长', _formatSeconds(record.totalSeconds)),
          const SizedBox(height: 8),
          _detailRow('最大控制力量', _formatKg(record.controlMaxValue)),
          const SizedBox(height: 8),
          _detailRow('最长连续控制', _formatSeconds(record.longestControlTimeSeconds)),
          const SizedBox(height: 8),
          _detailRow('1s均值', _formatKg(record.currentWindowMeanValue)),
          const SizedBox(height: 8),
          _detailRow('1s变化', _formatKg(record.currentWindowDeltaValue)),
          const SizedBox(height: 8),
          _detailRow('1s最大增长', _formatKg(record.deltaMaxValue)),
          const SizedBox(height: 8),
          _detailRow('1s最大下降', _formatKg(record.deltaMinValue)),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: <Widget>[
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

String _formatKg(double? value) {
  if (value == null || value.isNaN || value.isInfinite) {
    return 'N/A';
  }
  return '${value.toStringAsFixed(1)}kg';
}

String _formatSeconds(double? value) {
  if (value == null || value.isNaN || value.isInfinite) {
    return 'N/A';
  }
  return '${value.toStringAsFixed(1)}s';
}
