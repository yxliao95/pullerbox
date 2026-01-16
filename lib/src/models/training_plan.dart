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

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'workSeconds': workSeconds,
      'restSeconds': restSeconds,
      'cycles': cycles,
    };
  }

  factory TrainingPlanState.fromJson(Map<String, dynamic> json) {
    return TrainingPlanState(
      name: json['name'] as String? ?? '默认',
      workSeconds: (json['workSeconds'] as num?)?.toInt() ?? 0,
      restSeconds: (json['restSeconds'] as num?)?.toInt() ?? 0,
      cycles: (json['cycles'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrainingPlanItem {
  const TrainingPlanItem({required this.id, required this.plan});

  final String id;
  final TrainingPlanState plan;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'plan': plan.toJson(),
    };
  }

  factory TrainingPlanItem.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'] as Map?;
    return TrainingPlanItem(
      id: json['id'] as String? ?? '',
      plan: planJson == null
          ? const TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20)
          : TrainingPlanState.fromJson(Map<String, dynamic>.from(planJson)),
    );
  }
}

class TrainingPlanLibrarySnapshot {
  const TrainingPlanLibrarySnapshot({required this.plans, required this.selectedPlanId});

  final List<TrainingPlanItem> plans;
  final String? selectedPlanId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'selectedPlanId': selectedPlanId,
      'plans': plans.map((item) => item.toJson()).toList(),
    };
  }

  factory TrainingPlanLibrarySnapshot.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'] as List? ?? <dynamic>[];
    final plans = rawPlans
        .whereType<Map>()
        .map((plan) => TrainingPlanItem.fromJson(Map<String, dynamic>.from(plan)))
        .toList();
    return TrainingPlanLibrarySnapshot(
      plans: plans,
      selectedPlanId: json['selectedPlanId'] as String?,
    );
  }
}
