import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/training_plan_controller.dart';
import '../../../../providers/training_plan_library_controller.dart';
import 'plan_list_tile.dart';

class PlanSelectorDialog extends ConsumerWidget {
  const PlanSelectorDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(trainingPlanLibraryProvider);
    final libraryController = ref.read(trainingPlanLibraryProvider.notifier);
    final isEditing = libraryState.isEditing;
    final allSelected =
        libraryState.selectedPlanIds.length == libraryState.plans.length && libraryState.plans.isNotEmpty;
    const headerHeight = 56.0;
    const bottomHeight = 76.0;
    const horizontalPadding = 16.0 * 2;
    const titleToMiddleGap = 12.0;
    const middleToControlGap = 16.0;
    final titleStyle = const TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
    final labelStyle = const TextStyle(fontSize: 12, color: Color(0xFF9B9B9B));
    final valueStyle = const TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    final labelPainter = TextPainter(
      text: TextSpan(text: '锻炼 / 休息 / 循环', style: labelStyle),
      textDirection: Directionality.of(context),
    )..layout();
    final valuePainter = TextPainter(
      text: TextSpan(text: '999 / 999 / 999', style: valueStyle),
      textDirection: Directionality.of(context),
    )..layout();
    final middleColumnWidth = math.max(labelPainter.width, valuePainter.width);
    final rightControlWidth = isEditing ? 48.0 : 24.0;
    const headerSideWidth = 64.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxDialogHeight = math.min(MediaQuery.of(context).size.height * 0.6, constraints.maxHeight);
          final dialogWidth = constraints.maxWidth.clamp(0.0, 420.0);
          final titleMaxWidth = math.max(
            0.0,
            dialogWidth -
                horizontalPadding -
                middleColumnWidth -
                titleToMiddleGap -
                middleToControlGap -
                rightControlWidth,
          );

          return SizedBox(
            width: dialogWidth,
            height: maxDialogHeight,
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: headerHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: isEditing
                        ? Row(
                            children: <Widget>[
                              SizedBox(
                                width: headerSideWidth,
                                child: IconButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: allSelected ? null : libraryController.selectAll,
                                child: const Text('全选', style: TextStyle(color: Color(0xFF2A73F1))),
                              ),
                              TextButton(onPressed: libraryController.toggleEditing, child: const Text('取消')),
                            ],
                          )
                        : Stack(
                            children: <Widget>[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: headerSideWidth,
                                  child: IconButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                              ),
                              const Center(
                                child: Text('选择计划', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: SizedBox(
                                  width: headerSideWidth,
                                  child: TextButton(
                                    onPressed: libraryController.toggleEditing,
                                    child: const Text('编辑'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    physics: const ClampingScrollPhysics(),
                    itemCount: libraryState.plans.length,
                    onReorder: (oldIndex, newIndex) {
                      if (!isEditing) {
                        libraryController.reorderPlans(oldIndex, newIndex);
                      }
                    },
                    itemBuilder: (context, index) {
                      final item = libraryState.plans[index];
                      final isSelected = item.id == libraryState.selectedPlanId;
                      final isChecked = libraryState.selectedPlanIds.contains(item.id);
                      final singleLinePainter = TextPainter(
                        text: TextSpan(text: item.plan.name, style: titleStyle),
                        textDirection: Directionality.of(context),
                        maxLines: 1,
                      )..layout();
                      final shouldWrapTitle = singleLinePainter.width > titleMaxWidth;

                      return PlanListTile(
                        key: ValueKey(item.id),
                        index: index,
                        title: item.plan.name,
                        valuesText: '${item.plan.workSeconds} / ${item.plan.restSeconds} / ${item.plan.cycles}',
                        isActive: isSelected,
                        isEditing: isEditing,
                        isChecked: isChecked,
                        shouldWrapTitle: shouldWrapTitle,
                        onTap: () {
                          if (isEditing) {
                            libraryController.toggleSelectedPlan(item.id);
                            return;
                          }
                          libraryController.selectPlan(item.id);
                          ref.read(trainingPlanProvider.notifier).applyPlan(item.plan);
                          Navigator.of(context).pop();
                        },
                        onToggleCheck: () => libraryController.toggleSelectedPlan(item.id),
                      );
                    },
                  ),
                ),
                SizedBox(
                  height: bottomHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isEditing
                            ? (libraryState.selectedPlanIds.isEmpty
                                  ? null
                                  : () {
                                      final didResetToDefault = libraryController.deleteSelected();
                                      if (didResetToDefault) {
                                        ref
                                            .read(trainingPlanProvider.notifier)
                                            .applyPlan(ref.read(trainingPlanLibraryProvider).plans.first.plan);
                                        Navigator.of(context).pop();
                                      }
                                    })
                            : () {
                                final planId = libraryController.addPlan();
                                final selectedPlan = ref
                                    .read(trainingPlanLibraryProvider)
                                    .plans
                                    .firstWhere((plan) => plan.id == planId);
                                ref.read(trainingPlanProvider.notifier).applyPlan(selectedPlan.plan);
                                Navigator.of(context).pop();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A73F1),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(isEditing ? '删除' : '新增计划'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
