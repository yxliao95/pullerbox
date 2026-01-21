import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/training_plan.dart';
import '../../../providers/training_plan_controller.dart';
import '../../../providers/training_plan_library_controller.dart';
import 'training_plan_view.dart';
import 'widgets/plan_selector_dialog.dart';

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

    return TrainingPlanView(
      state: state,
      libraryState: libraryState,
      controller: controller,
      libraryController: libraryController,
      nameController: _nameController,
      isDeviceConnected: _isDeviceConnected,
      onToggleDeviceConnection: _toggleDeviceConnection,
      onShowPlanSelector: () => _showPlanSelector(context),
      onStartTraining: () => Navigator.of(context).push(buildTrainingMonitorRoute(_isDeviceConnected)),
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

  void _toggleDeviceConnection() {
    setState(() {
      _isDeviceConnected = !_isDeviceConnected;
    });
  }
}
