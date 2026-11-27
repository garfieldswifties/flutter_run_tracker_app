import '../models/run.dart';
import '../models/run_photo.dart';

abstract class RunService {
  Future<List<Run>> fetchRuns();
  Future<RunChange> insertRun(Run input, RunPhoto? photo);
  Future<RunChange> updateRun(Run original, Run input, RunPhoto? photo);
  Future<RunChange> deleteRun(Run original);
}

class RunChange {
  const RunChange(this.run, {this.imageCleanupPending = false});

  final Run run;
  final bool imageCleanupPending;
}

class RunActionException implements Exception {
  const RunActionException(this.message, {this.requiresRefresh = false});

  final String message;
  final bool requiresRefresh;
}
