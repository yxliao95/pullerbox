import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/training_plan.dart';
import '../../../providers/training_plan_controller.dart';
import '../../../providers/training_plan_library_controller.dart';
import '../monitor/training_monitor_page.dart';
import 'widgets/training_plan_form.dart';
import 'widgets/training_plan_header.dart';

class TrainingPlanView extends StatelessWidget {
  const TrainingPlanView({
    required this.state,
    required this.libraryState,
    required this.controller,
    required this.libraryController,
    required this.nameController,
    required this.isDeviceConnected,
    required this.onToggleDeviceConnection,
    required this.onShowPlanSelector,
    required this.onStartTraining,
    super.key,
  });

  final TrainingPlanState state;
  final TrainingPlanLibraryState libraryState;
  final TrainingPlanController controller;
  final TrainingPlanLibraryController libraryController;
  final TextEditingController nameController;
  final bool isDeviceConnected;
  final VoidCallback onToggleDeviceConnection;
  final VoidCallback onShowPlanSelector;
  final VoidCallback onStartTraining;

  @override
  Widget build(BuildContext context) {
    final totalDurationText = _formatDuration(state.totalDurationSeconds);
    final isFreeTraining = libraryState.isFreeTraining;
    const sliverAppBarExpandedHeight = 210.0;
    const sliverAppBarCollapsedThresholdPadding = 8.0;
    const sliverAppBarTitlePadding = EdgeInsets.fromLTRB(16, 0, 16, 12);
    const sliverHeaderExpandedPadding = EdgeInsets.fromLTRB(16, 12, 16, 18);
    const bottomFloatButtonHeight = 52.0;
    const bottomFloatHintHeight = 18.0;
    final showDeviceHint = isFreeTraining && !isDeviceConnected;
    final bottomFloatAreaHeight = bottomFloatButtonHeight + (showDeviceHint ? bottomFloatHintHeight : 0);

    if (nameController.text != state.name) {
      nameController.text = state.name;
      nameController.selection = TextSelection.fromPosition(TextPosition(offset: nameController.text.length));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      extendBodyBehindAppBar: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: SizedBox(
        height: bottomFloatAreaHeight,
        width: MediaQuery.of(context).size.width - 32,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (showDeviceHint)
              const Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('请连接设备', style: TextStyle(fontSize: 12, color: Colors.black45)),
              ),
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: FloatingActionButton.extended(
                  onPressed: showDeviceHint ? null : onStartTraining,
                  backgroundColor: showDeviceHint ? const Color(0xFFBDBDBD) : const Color(0xFF2A73F1),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  label: const Text('开始', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ],
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
                            onConnectPressed: onToggleDeviceConnection,
                            isFreeTraining: isFreeTraining,
                            isDeviceConnected: isDeviceConnected,
                          )
                        : null,
                    background: TrainingPlanExpandedHeader(
                      title: isFreeTraining ? '自由训练' : '总时长',
                      duration: totalDurationText,
                      onConnectPressed: onToggleDeviceConnection,
                      expandedPadding: sliverHeaderExpandedPadding,
                      isFreeTraining: isFreeTraining,
                      isDeviceConnected: isDeviceConnected,
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
                      SizedBox(height: bottomFloatAreaHeight + 16),
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
                      PlanNameRow(controller: nameController, onNameChanged: controller.updateName),
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
                              onPressed: onShowPlanSelector,
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
                      SizedBox(height: bottomFloatAreaHeight + 16),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainSeconds = seconds % 60;
  final minuteText = minutes.toString().padLeft(2, '0');
  final secondText = remainSeconds.toString().padLeft(2, '0');
  return '$minuteText:$secondText';
}

Route<Widget> buildTrainingMonitorRoute(bool isDeviceConnected) {
  return MaterialPageRoute<Widget>(
    builder: (_) => TrainingMonitorPage(isDeviceConnected: isDeviceConnected),
  );
}
