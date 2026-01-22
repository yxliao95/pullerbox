import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pullerbox/src/models/training_plan.dart';
import 'package:pullerbox/src/services/training_plan_storage.dart';

void main() {
  const storageKey = TrainingPlanStorage.storageKey;
  const defaultPlan = TrainingPlanState(name: '默认', workSeconds: 7, restSeconds: 3, cycles: 20);

  TrainingPlanLibrarySnapshot buildSnapshot() {
    return const TrainingPlanLibrarySnapshot(
      plans: <TrainingPlanItem>[TrainingPlanItem(id: 'p1', plan: defaultPlan)],
      selectedPlanId: 'p1',
      isFreeTraining: false,
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('loadLibrary returns null when storage is empty', () async {
    final storage = TrainingPlanStorage();

    final snapshot = await storage.loadLibrary();

    expect(snapshot, isNull);
  });

  test('saveLibrary persists and loadLibrary restores snapshot', () async {
    final storage = TrainingPlanStorage();
    final snapshot = buildSnapshot();

    await storage.saveLibrary(snapshot);
    final restored = await storage.loadLibrary();

    expect(restored, isNotNull);
    expect(restored!.plans.length, 1);
    expect(restored.selectedPlanId, 'p1');
    expect(restored.isFreeTraining, isFalse);
  });

  test('loadLibrary returns null when stored payload is invalid', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{storageKey: '[]'});
    final storage = TrainingPlanStorage();

    final snapshot = await storage.loadLibrary();

    expect(snapshot, isNull);
  });
}
