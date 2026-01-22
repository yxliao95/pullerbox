import 'package:flutter/material.dart';

import '../../../models/free_training_record.dart';
import '../../../models/metric_definitions.dart';
import '../record_formatters.dart';
import '../free_training_record_detail_page.dart';

class FreeTrainingRecordCard extends StatelessWidget {
  const FreeTrainingRecordCard({
    required this.record,
    required this.summaryMetrics,
    this.onLongPress,
    super.key,
  });

  final FreeTrainingRecord record;
  final List<FreeSummaryMetric> summaryMetrics;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => FreeTrainingRecordDetailPage(record: record),
            ),
          );
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
                      record.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: Color(0xFFB0B0B0)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                formatRecordDateTime(record.startedAt),
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E8E)),
              ),
              const SizedBox(height: 10),
              _FreeTrainingSparkline(samples: record.samples, totalSeconds: record.totalSeconds),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  return _StatGrid(
                    maxWidth: constraints.maxWidth,
                    children: summaryMetrics.map((metric) => _buildSummary(metric)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatColumn _buildSummary(FreeSummaryMetric metric) {
    final definition = freeSummaryMetricDefinitionMap[metric];
    switch (metric) {
      case FreeSummaryMetric.totalDuration:
        return _StatColumn(label: definition?.shortLabel ?? '总时长', value: _formatSeconds(record.totalSeconds));
      case FreeSummaryMetric.controlMax:
        return _StatColumn(label: definition?.shortLabel ?? '最大控制力量', value: _formatKg(record.controlMaxValue));
      case FreeSummaryMetric.longestControl:
        return _StatColumn(
          label: definition?.shortLabel ?? '最长连续控制',
          value: _formatSeconds(record.longestControlTimeSeconds),
        );
      case FreeSummaryMetric.windowMean:
        return _StatColumn(label: definition?.shortLabel ?? '1s均值', value: _formatKg(record.currentWindowMeanValue));
      case FreeSummaryMetric.windowDelta:
        return _StatColumn(label: definition?.shortLabel ?? '1s变化', value: _formatKg(record.currentWindowDeltaValue));
      case FreeSummaryMetric.deltaMax:
        return _StatColumn(label: definition?.shortLabel ?? '1s最大增长', value: _formatKg(record.deltaMaxValue));
      case FreeSummaryMetric.deltaMin:
        return _StatColumn(label: definition?.shortLabel ?? '1s最大下降', value: _formatKg(record.deltaMinValue));
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

class _FreeTrainingSparkline extends StatelessWidget {
  const _FreeTrainingSparkline({required this.samples, required this.totalSeconds});

  final List<double> samples;
  final double totalSeconds;

  @override
  Widget build(BuildContext context) {
    if (samples.length < 2) {
      return Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Text('暂无曲线', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E8E))),
      );
    }
    return SizedBox(
      height: 44,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _SparklinePainter(
              samples: samples,
              totalSeconds: totalSeconds,
              lineColor: const Color(0xFF2F7BEA),
            ),
          );
        },
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({
    required this.samples,
    required this.totalSeconds,
    required this.lineColor,
  });

  final List<double> samples;
  final double totalSeconds;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final minValue = samples.reduce((a, b) => a < b ? a : b);
    final maxValue = samples.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs();
    final safeRange = range <= 0 ? 1.0 : range;
    final path = Path();
    for (int i = 0; i < samples.length; i++) {
      final denom = totalSeconds > 0 ? totalSeconds : (samples.length - 1).toDouble();
      final time = (samples.length == 1) ? 0.0 : (i / (samples.length - 1)) * denom;
      final x = denom == 0 ? 0.0 : size.width * (time / denom);
      final normalized = (samples[i] - minValue) / safeRange;
      final y = size.height * (1 - normalized);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = lineColor;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.samples != samples || oldDelegate.lineColor != lineColor;
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
