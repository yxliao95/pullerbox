import 'package:flutter/material.dart';

import '../../../models/free_training_record.dart';
import '../record_formatters.dart';

class FreeTrainingRecordCard extends StatelessWidget {
  const FreeTrainingRecordCard({required this.record, required this.onTap, super.key});

  final FreeTrainingRecord record;
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
                      record.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.black45),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                formatRecordDateTime(record.startedAt),
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  _StatColumn(label: '最大控制', value: _formatKg(record.controlMaxValue)),
                  _StatColumn(label: '最长连续', value: _formatSeconds(record.longestControlTimeSeconds)),
                  _StatColumn(label: '总时长', value: _formatSeconds(record.totalSeconds)),
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
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
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
