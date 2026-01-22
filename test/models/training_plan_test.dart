import 'package:flutter_test/flutter_test.dart';

import 'package:pullerbox/src/models/training_plan.dart';

void main() {
  const defaultPlan = TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20);

  test('TrainingPlanState copyWith updates fields', () {
    final updated = defaultPlan.copyWith(name: 'Plan A', workSeconds: 12);

    expect(updated.name, 'Plan A');
    expect(updated.workSeconds, 12);
    expect(updated.restSeconds, defaultPlan.restSeconds);
    expect(updated.cycles, defaultPlan.cycles);
  });

  test('TrainingPlanState totalDurationSeconds clamps when cycles <= 0', () {
    const plan = TrainingPlanState(name: 'Zero', workSeconds: 5, restSeconds: 5, cycles: 0);

    expect(plan.totalDurationSeconds, 0);
  });

  test('TrainingPlanItem fromJson uses fallback plan when missing', () {
    const fallback = TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20);
    final item = TrainingPlanItem.fromJson(<String, dynamic>{'id': 'p1'});

    expect(item.id, 'p1');
    expect(item.plan.name, fallback.name);
    expect(item.plan.workSeconds, fallback.workSeconds);
    expect(item.plan.restSeconds, fallback.restSeconds);
    expect(item.plan.cycles, fallback.cycles);
  });

  test('TrainingPlanLibrarySnapshot round-trip keeps selection', () {
    const item = TrainingPlanItem(id: 'p1', plan: defaultPlan);
    const snapshot = TrainingPlanLibrarySnapshot(
      plans: <TrainingPlanItem>[item],
      selectedPlanId: 'p1',
      isFreeTraining: false,
    );

    final decoded = TrainingPlanLibrarySnapshot.fromJson(snapshot.toJson());

    expect(decoded.plans.length, 1);
    expect(decoded.selectedPlanId, 'p1');
    expect(decoded.isFreeTraining, isFalse);
  });
}
