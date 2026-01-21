import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/free_training_record_provider.dart';
import '../../providers/training_record_provider.dart';
import 'free_training_record_detail_page.dart';
import 'training_record_detail_page.dart';
import 'widgets/free_training_record_card.dart';
import 'widgets/record_card.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordState = ref.watch(trainingRecordProvider);
    final controller = ref.read(trainingRecordProvider.notifier);
    final freeRecordState = ref.watch(freeTrainingRecordProvider);
    final freeController = ref.read(freeTrainingRecordProvider.notifier);
    final records = recordState.records;
    final freeRecords = freeRecordState.records;
    if (records.isEmpty && freeRecords.isEmpty) {
      return const Center(child: Text('暂无训练记录'));
    }
    final items = <Widget>[];
    if (freeRecords.isNotEmpty) {
      items.add(const _SectionHeader(title: '自由训练'));
      for (final record in freeRecords) {
        items.add(
          Dismissible(
            key: ValueKey<String>('free-${record.id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              color: const Color(0xFFE94B4B),
              child: const Icon(Icons.delete, color: Colors.white),
            ),
            onDismissed: (_) => freeController.removeRecord(record.id),
            child: FreeTrainingRecordCard(
              record: record,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => FreeTrainingRecordDetailPage(record: record),
                  ),
                );
              },
            ),
          ),
        );
        items.add(const SizedBox(height: 12));
      }
    }
    if (records.isNotEmpty) {
      items.add(const _SectionHeader(title: '计时训练'));
      for (final record in records) {
        items.add(
          Dismissible(
            key: ValueKey<String>('timer-${record.id}'),
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
          ),
        );
        items.add(const SizedBox(height: 12));
      }
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: items,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF6C6C6C)),
      ),
    );
  }
}
