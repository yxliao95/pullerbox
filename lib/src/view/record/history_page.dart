import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/training_record_provider.dart';
import 'training_record_detail_page.dart';
import 'widgets/record_card.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final records = ref.watch(trainingRecordProvider).records;
    if (records.isEmpty) {
      return const Center(child: Text('暂无训练记录'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: records.length,
      separatorBuilder: (_, _unused) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = records[index];
        return RecordCard(
          record: record,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => TrainingRecordDetailPage(record: record),
              ),
            );
          },
        );
      },
    );
  }
}
