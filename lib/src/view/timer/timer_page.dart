import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../provider/training_plan_provider.dart';

class TimerPage extends ConsumerStatefulWidget {
  const TimerPage({super.key});

  @override
  ConsumerState<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends ConsumerState<TimerPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(trainingPlanProvider);
    _nameController = TextEditingController(text: state.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TrainingPlanState>(trainingPlanProvider, (previous, next) {
      ref.read(trainingPlanLibraryProvider.notifier).updateSelectedPlan(next);
    });
    final state = ref.watch(trainingPlanProvider);
    final controller = ref.read(trainingPlanProvider.notifier);
    final totalDurationText = _formatDuration(state.totalDurationSeconds);
    const sliverAppBarExpandedHeight = 210.0;
    const sliverAppBarCollapsedThresholdPadding = 8.0;
    const sliverAppBarTitlePadding = EdgeInsets.fromLTRB(16, 0, 16, 12);
    const sliverHeaderExpandedPadding = EdgeInsets.fromLTRB(16, 12, 16, 18);
    const bottomFloatButtonHeight = 52.0;

    if (_nameController.text != state.name) {
      _nameController.text = state.name;
      _nameController.selection = TextSelection.fromPosition(TextPosition(offset: _nameController.text.length));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      extendBodyBehindAppBar: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        height: bottomFloatButtonHeight,
        width: MediaQuery.of(context).size.width - 32,
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: const Color(0xFF2A73F1),
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          label: const Text('开始', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        ),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              floating: true,
              snap: false,
              expandedHeight: sliverAppBarExpandedHeight,
              backgroundColor: const Color(0xFF2A73F1),
              elevation: 0,
              flexibleSpace: LayoutBuilder(
                builder: (context, constraints) {
                  final topPadding = MediaQuery.of(context).padding.top;
                  final collapsedThreshold = topPadding + kToolbarHeight + sliverAppBarCollapsedThresholdPadding;
                  final isCollapsed = constraints.maxHeight <= collapsedThreshold;

                  return FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: sliverAppBarTitlePadding,
                    title: isCollapsed
                        ? _CollapsedHeaderContent(title: '总时长', duration: totalDurationText, onConnectPressed: () {})
                        : null,
                    background: _ExpandedHeaderSection(
                      title: '总时长',
                      duration: totalDurationText,
                      onConnectPressed: () {},
                      expandedPadding: sliverHeaderExpandedPadding,
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 16),
                    _PlanNameRow(controller: _nameController, onNameChanged: controller.updateName),
                    const SizedBox(height: 12),
                    _NumberCard(
                      label: '锻炼',
                      value: state.workSeconds,
                      unit: '秒',
                      onMinus: controller.decrementWork,
                      onPlus: controller.incrementWork,
                    ),
                    const SizedBox(height: 12),
                    _NumberCard(
                      label: '休息',
                      value: state.restSeconds,
                      unit: '秒',
                      onMinus: controller.decrementRest,
                      onPlus: controller.incrementRest,
                    ),
                    const SizedBox(height: 12),
                    _NumberCard(
                      label: '循环',
                      value: state.cycles,
                      unit: '次',
                      onMinus: controller.decrementCycles,
                      onPlus: controller.incrementCycles,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {},
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E2E2E),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('自由训练'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showPlanSelector(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E2E2E),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('选择计划'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(height: bottomFloatButtonHeight + 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPlanSelector(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => const _PlanSelectorDialog(),
    );
    if (!mounted) {
      return;
    }
    final libraryState = ref.read(trainingPlanLibraryProvider);
    final selectedPlanId = libraryState.selectedPlanId;
    if (selectedPlanId != null) {
      TrainingPlanState? selectedPlan;
      for (final plan in libraryState.plans) {
        if (plan.id == selectedPlanId) {
          selectedPlan = plan.plan;
          break;
        }
      }
      if (selectedPlan != null) {
        ref.read(trainingPlanProvider.notifier).applyPlan(selectedPlan);
      }
    }
    ref.read(trainingPlanLibraryProvider.notifier).exitEditing();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainSeconds = seconds % 60;
    final minuteText = minutes.toString().padLeft(2, '0');
    final secondText = remainSeconds.toString().padLeft(2, '0');
    return '$minuteText:$secondText';
  }
}

class _PlanSelectorDialog extends ConsumerWidget {
  const _PlanSelectorDialog();

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

                      return _PlanListTile(
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
                        child: Text(isEditing ? '批量删除' : '新增计划'),
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

class _PlanListTile extends StatelessWidget {
  const _PlanListTile({
    super.key,
    required this.index,
    required this.title,
    required this.valuesText,
    required this.isActive,
    required this.isEditing,
    required this.isChecked,
    required this.shouldWrapTitle,
    required this.onTap,
    required this.onToggleCheck,
  });

  final int index;
  final String title;
  final String valuesText;
  final bool isActive;
  final bool isEditing;
  final bool isChecked;
  final bool shouldWrapTitle;
  final VoidCallback onTap;
  final VoidCallback onToggleCheck;

  @override
  Widget build(BuildContext context) {
    final activeColor = isActive ? const Color(0xFF2A73F1) : const Color(0xFF1E1E1E);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: activeColor),
                  maxLines: shouldWrapTitle ? null : 1,
                  overflow: shouldWrapTitle ? TextOverflow.visible : TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('锻炼 / 休息 / 循环', style: TextStyle(fontSize: 12, color: Color(0xFF9B9B9B))),
                  const SizedBox(height: 4),
                  Text(valuesText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 16),
              if (isEditing)
                Checkbox(value: isChecked, onChanged: (_) => onToggleCheck())
              else
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle, color: Color(0xFF1E1E1E)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpandedHeaderSection extends StatelessWidget {
  const _ExpandedHeaderSection({
    required this.title,
    required this.duration,
    required this.onConnectPressed,
    required this.expandedPadding,
  });

  final String title;
  final String duration;
  final VoidCallback onConnectPressed;
  final EdgeInsets expandedPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: expandedPadding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[Color(0xFF2A73F1), Color(0xFF1F5DD8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              duration,
              style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _BluetoothCard(onConnectPressed: onConnectPressed),
          ],
        ),
      ),
    );
  }
}

class _CollapsedHeaderContent extends StatelessWidget {
  const _CollapsedHeaderContent({required this.title, required this.duration, required this.onConnectPressed});

  final String title;
  final String duration;
  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 16),
              Text(
                duration,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        _BluetoothIconButton(onConnectPressed: onConnectPressed),
      ],
    );
  }
}

class _BluetoothCard extends StatelessWidget {
  const _BluetoothCard({required this.onConnectPressed});

  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF3A7AF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: <Widget>[
          const CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Icon(Icons.bluetooth, color: Color(0xFF2A73F1)),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text('设备未连接', style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
          _BluetoothButton(onConnectPressed: onConnectPressed),
        ],
      ),
    );
  }
}

class _BluetoothButton extends StatelessWidget {
  const _BluetoothButton({required this.onConnectPressed});

  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onConnectPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF2A73F1),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: const Text('连接设备'),
    );
  }
}

class _BluetoothIconButton extends StatelessWidget {
  const _BluetoothIconButton({required this.onConnectPressed});

  final VoidCallback onConnectPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onConnectPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.bluetooth, color: Color(0xFF2A73F1), size: 20),
      ),
    );
  }
}

class _PlanNameRow extends StatelessWidget {
  const _PlanNameRow({required this.controller, required this.onNameChanged});

  final TextEditingController controller;
  final ValueChanged<String> onNameChanged;

  @override
  Widget build(BuildContext context) {
    const hintText = '输入训练名称';
    const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    const hintStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black38);
    const horizontalPadding = 12.0;
    const iconWidth = 16.0;
    const iconSpacing = 8.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxTextWidth = math.max(0.0, constraints.maxWidth - iconWidth - iconSpacing);

        return Row(
          children: <Widget>[
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                final displayText = value.text.isNotEmpty ? value.text : hintText;
                final displayStyle = value.text.isNotEmpty ? textStyle : hintStyle;
                final singleLinePainter = TextPainter(
                  text: TextSpan(text: displayText, style: displayStyle),
                  textDirection: Directionality.of(context),
                  maxLines: 1,
                )..layout();
                final availableLineWidth = math.max(0.0, maxTextWidth - horizontalPadding * 2);
                final shouldWrap = singleLinePainter.width > availableLineWidth;
                final textPainter = TextPainter(
                  text: TextSpan(text: displayText, style: displayStyle),
                  textDirection: Directionality.of(context),
                )..layout(maxWidth: availableLineWidth);
                final underlineWidth = shouldWrap
                    ? maxTextWidth
                    : math.min(textPainter.width + horizontalPadding * 2, maxTextWidth);
                final fieldWidth = shouldWrap ? maxTextWidth : math.min(underlineWidth + 8, maxTextWidth);

                return SizedBox(
                  width: fieldWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      TextField(
                        controller: controller,
                        onChanged: onNameChanged,
                        minLines: 1,
                        maxLines: shouldWrap ? null : 1,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          hintText: hintText,
                          hintStyle: hintStyle,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.fromLTRB(horizontalPadding, 0, horizontalPadding, 2),
                        ),
                        style: textStyle,
                      ),
                      Container(height: 1, width: underlineWidth, color: const Color(0xFFE1E1E1)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: iconSpacing),
            const Icon(Icons.edit, size: 16, color: Colors.black45),
          ],
        );
      },
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final int value;
  final String unit;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x11000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  Text(label, style: const TextStyle(color: Colors.black, fontSize: 16)),
                  const SizedBox(width: 20),
                  Text(value.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  Text(unit, style: const TextStyle(color: Color(0xFF6C6C6C), fontSize: 12)),
                ],
              ),
            ),
          ),
          _AdjustButton(icon: Icons.remove, onTap: onMinus),
          const SizedBox(width: 8),
          _AdjustButton(icon: Icons.add, onTap: onPlus),
        ],
      ),
    );
  }
}

class _AdjustButton extends StatelessWidget {
  const _AdjustButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(color: Color(0xFFF0F0F0), shape: BoxShape.circle),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
