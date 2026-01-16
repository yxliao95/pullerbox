import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrainingPlanState {
  const TrainingPlanState({
    required this.name,
    required this.workSeconds,
    required this.restSeconds,
    required this.cycles,
  });

  final String name;
  final int workSeconds;
  final int restSeconds;
  final int cycles;

  TrainingPlanState copyWith({String? name, int? workSeconds, int? restSeconds, int? cycles}) {
    return TrainingPlanState(
      name: name ?? this.name,
      workSeconds: workSeconds ?? this.workSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      cycles: cycles ?? this.cycles,
    );
  }

  int get totalDurationSeconds {
    if (cycles <= 0) {
      return 0;
    }
    return (workSeconds + restSeconds) * cycles;
  }
}

class TrainingPlanController extends Notifier<TrainingPlanState> {
  @override
  TrainingPlanState build() {
    return const TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20);
  }

  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  void incrementWork() {
    state = state.copyWith(workSeconds: state.workSeconds + 1);
  }

  void decrementWork() {
    state = state.copyWith(workSeconds: _maxZero(state.workSeconds - 1));
  }

  void incrementRest() {
    state = state.copyWith(restSeconds: state.restSeconds + 1);
  }

  void decrementRest() {
    state = state.copyWith(restSeconds: _maxZero(state.restSeconds - 1));
  }

  void incrementCycles() {
    state = state.copyWith(cycles: state.cycles + 1);
  }

  void decrementCycles() {
    state = state.copyWith(cycles: _maxZero(state.cycles - 1));
  }

  int _maxZero(int value) {
    return value < 0 ? 0 : value;
  }

  void applyPlan(TrainingPlanState plan) {
    state = plan;
  }
}

final trainingPlanProvider = NotifierProvider<TrainingPlanController, TrainingPlanState>(TrainingPlanController.new);

class TrainingPlanItem {
  const TrainingPlanItem({required this.id, required this.plan});

  final String id;
  final TrainingPlanState plan;
}

class TrainingPlanLibraryState {
  const TrainingPlanLibraryState({
    required this.plans,
    required this.selectedPlanId,
    required this.isEditing,
    required this.selectedPlanIds,
  });

  final List<TrainingPlanItem> plans;
  final String? selectedPlanId;
  final bool isEditing;
  final Set<String> selectedPlanIds;

  TrainingPlanLibraryState copyWith({
    List<TrainingPlanItem>? plans,
    String? selectedPlanId,
    bool? isEditing,
    Set<String>? selectedPlanIds,
  }) {
    return TrainingPlanLibraryState(
      plans: plans ?? this.plans,
      selectedPlanId: selectedPlanId ?? this.selectedPlanId,
      isEditing: isEditing ?? this.isEditing,
      selectedPlanIds: selectedPlanIds ?? this.selectedPlanIds,
    );
  }
}

class TrainingPlanLibraryController extends Notifier<TrainingPlanLibraryState> {
  @override
  TrainingPlanLibraryState build() {
    const defaultPlan = TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20);
    final initialPlans = <TrainingPlanItem>[
      const TrainingPlanItem(id: 'default', plan: defaultPlan),
      TrainingPlanItem(
        id: 'plan-1',
        plan: const TrainingPlanState(name: '左手 crimp 20mm', workSeconds: 10, restSeconds: 3, cycles: 40),
      ),
      TrainingPlanItem(
        id: 'plan-2',
        plan: const TrainingPlanState(name: '右手 crimp 20mm', workSeconds: 10, restSeconds: 3, cycles: 40),
      ),
      TrainingPlanItem(
        id: 'plan-3',
        plan: const TrainingPlanState(name: '左手 pinch block 8cm', workSeconds: 10, restSeconds: 3, cycles: 40),
      ),
    ];
    return TrainingPlanLibraryState(
      plans: initialPlans,
      selectedPlanId: 'default',
      isEditing: false,
      selectedPlanIds: <String>{},
    );
  }

  void toggleEditing() {
    final isEditing = !state.isEditing;
    state = state.copyWith(isEditing: isEditing, selectedPlanIds: <String>{});
  }

  void exitEditing() {
    if (!state.isEditing) {
      return;
    }
    state = state.copyWith(isEditing: false, selectedPlanIds: <String>{});
  }

  void selectPlan(String planId) {
    state = state.copyWith(selectedPlanId: planId);
  }

  void toggleSelectedPlan(String planId) {
    if (!state.isEditing) {
      return;
    }
    final updated = Set<String>.from(state.selectedPlanIds);
    if (updated.contains(planId)) {
      updated.remove(planId);
    } else {
      updated.add(planId);
    }
    state = state.copyWith(selectedPlanIds: updated);
  }

  void selectAll() {
    if (!state.isEditing) {
      return;
    }
    state = state.copyWith(selectedPlanIds: state.plans.map((plan) => plan.id).toSet());
  }

  String addPlan() {
    final planId = 'plan-${DateTime.now().microsecondsSinceEpoch}';
    final newPlan = TrainingPlanItem(
      id: planId,
      plan: TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20),
    );
    state = state.copyWith(
      plans: <TrainingPlanItem>[...state.plans, newPlan],
      selectedPlanId: planId,
    );
    return planId;
  }

  bool deleteSelected() {
    if (state.selectedPlanIds.isEmpty) {
      return false;
    }
    final remaining = state.plans.where((plan) => !state.selectedPlanIds.contains(plan.id)).toList();
    if (remaining.isEmpty) {
      const newPlan = TrainingPlanItem(
        id: 'default',
        plan: TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20),
      );
      state = state.copyWith(
        plans: <TrainingPlanItem>[newPlan],
        selectedPlanId: newPlan.id,
        selectedPlanIds: <String>{},
      );
      return true;
    }
    final selectedPlanId = remaining.any((plan) => plan.id == state.selectedPlanId)
        ? state.selectedPlanId
        : remaining.first.id;
    state = state.copyWith(plans: remaining, selectedPlanId: selectedPlanId, selectedPlanIds: <String>{});
    return false;
  }

  void reorderPlans(int oldIndex, int newIndex) {
    final updated = [...state.plans];
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    state = state.copyWith(plans: updated);
  }

  void updateSelectedPlan(TrainingPlanState plan) {
    final selectedPlanId = state.selectedPlanId;
    if (selectedPlanId == null) {
      return;
    }
    final updated = state.plans
        .map((item) => item.id == selectedPlanId ? TrainingPlanItem(id: item.id, plan: plan) : item)
        .toList();
    state = state.copyWith(plans: updated);
  }
}

final trainingPlanLibraryProvider = NotifierProvider<TrainingPlanLibraryController, TrainingPlanLibraryState>(
  TrainingPlanLibraryController.new,
);
