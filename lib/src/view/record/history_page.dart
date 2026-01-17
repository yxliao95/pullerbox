import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/training_record_provider.dart';
import 'training_record_detail_page.dart';
import 'widgets/record_card.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordState = ref.watch(trainingRecordProvider);
    final controller = ref.read(trainingRecordProvider.notifier);
    final records = recordState.records;
    if (records.isEmpty) {
      return const Center(child: Text('暂无训练记录'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: records.length,
      separatorBuilder: (_, _unused) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final record = records[index];
        return Dismissible(
          key: ValueKey<String>(record.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: const Color(0xFFE94B4B),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (_) => controller.removeRecord(record.id),
          child: RecordCard(
            record: record,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => TrainingRecordDetailPage(record: record),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
