import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../models/training_plan.dart';
import '../../../provider/training_plan_provider.dart';
import '../monitor/training_monitor_page.dart';
import 'widgets/plan_selector_dialog.dart';
import 'widgets/training_plan_form.dart';
import 'widgets/training_plan_header.dart';

class TimerPage extends ConsumerStatefulWidget {
  const TimerPage({super.key});

  @override
  ConsumerState<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends ConsumerState<TimerPage> {
  late final TextEditingController _nameController;
  bool _isDeviceConnected = false;

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
    final libraryState = ref.watch(trainingPlanLibraryProvider);
    final libraryController = ref.read(trainingPlanLibraryProvider.notifier);
    final state = ref.watch(trainingPlanProvider);
    final controller = ref.read(trainingPlanProvider.notifier);
    final totalDurationText = _formatDuration(state.totalDurationSeconds);
    final isFreeTraining = libraryState.isFreeTraining;
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
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<Widget>(
                builder: (_) => TrainingMonitorPage(isDeviceConnected: _isDeviceConnected),
              ),
            );
          },
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
                        ? TrainingPlanCollapsedHeader(
                            title: isFreeTraining ? '自由训练' : '总时长',
                            duration: totalDurationText,
                            onConnectPressed: _toggleDeviceConnection,
                            isFreeTraining: isFreeTraining,
                            isDeviceConnected: _isDeviceConnected,
                          )
                        : null,
                    background: TrainingPlanExpandedHeader(
                      title: isFreeTraining ? '自由训练' : '总时长',
                      duration: totalDurationText,
                      onConnectPressed: _toggleDeviceConnection,
                      expandedPadding: sliverHeaderExpandedPadding,
                      isFreeTraining: isFreeTraining,
                      isDeviceConnected: _isDeviceConnected,
                    ),
                  );
                },
              ),
            ),
            if (isFreeTraining)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => libraryController.setFreeTraining(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E2E2E),
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('切换计划训练'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(height: bottomFloatButtonHeight + 16),
                    ],
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 16),
                      PlanNameRow(controller: _nameController, onNameChanged: controller.updateName),
                      const SizedBox(height: 12),
                      NumberCard(
                        label: '锻炼',
                        value: state.workSeconds,
                        unit: '秒',
                        onMinus: controller.decrementWork,
                        onPlus: controller.incrementWork,
                      ),
                      const SizedBox(height: 12),
                      NumberCard(
                        label: '休息',
                        value: state.restSeconds,
                        unit: '秒',
                        onMinus: controller.decrementRest,
                        onPlus: controller.incrementRest,
                      ),
                      const SizedBox(height: 12),
                      NumberCard(
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
                              onPressed: () => libraryController.setFreeTraining(true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2E2E2E),
                                backgroundColor: Colors.white,
                                side: BorderSide.none,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('切换自由训练'),
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
      builder: (context) => const PlanSelectorDialog(),
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

  void _toggleDeviceConnection() {
    setState(() {
      _isDeviceConnected = !_isDeviceConnected;
    });
  }
}
