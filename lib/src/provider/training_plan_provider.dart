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
}

final trainingPlanProvider = NotifierProvider<TrainingPlanController, TrainingPlanState>(TrainingPlanController.new);
