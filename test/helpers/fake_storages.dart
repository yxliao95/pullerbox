import 'package:pullerbox/src/models/free_training_record.dart';
import 'package:pullerbox/src/models/training_plan.dart';
import 'package:pullerbox/src/models/training_record.dart';
import 'package:pullerbox/src/services/free_training_record_storage.dart';
import 'package:pullerbox/src/services/training_plan_storage.dart';
import 'package:pullerbox/src/services/training_record_storage.dart';

class FakeTrainingRecordStorage extends TrainingRecordStorage {
  FakeTrainingRecordStorage({this.snapshot});

  TrainingRecordSnapshot? snapshot;
  TrainingRecordSnapshot? savedSnapshot;

  @override
  Future<TrainingRecordSnapshot?> loadHistory() async {
    return snapshot;
  }

  @override
  Future<void> saveHistory(TrainingRecordSnapshot snapshot) async {
    savedSnapshot = snapshot;
  }
}

class FakeFreeTrainingRecordStorage extends FreeTrainingRecordStorage {
  FakeFreeTrainingRecordStorage({this.snapshot});

  FreeTrainingRecordSnapshot? snapshot;
  FreeTrainingRecordSnapshot? savedSnapshot;

  @override
  Future<FreeTrainingRecordSnapshot?> loadHistory() async {
    return snapshot;
  }

  @override
  Future<void> saveHistory(FreeTrainingRecordSnapshot snapshot) async {
    savedSnapshot = snapshot;
  }
}

class FakeTrainingPlanStorage extends TrainingPlanStorage {
  FakeTrainingPlanStorage({this.snapshot});

  TrainingPlanLibrarySnapshot? snapshot;
  TrainingPlanLibrarySnapshot? savedSnapshot;

  @override
  Future<TrainingPlanLibrarySnapshot?> loadLibrary() async {
    return snapshot;
  }

  @override
  Future<void> saveLibrary(TrainingPlanLibrarySnapshot snapshot) async {
    savedSnapshot = snapshot;
  }
}
