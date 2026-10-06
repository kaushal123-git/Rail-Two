import 'dart:async';
import '../models/train.dart';
import '../services/train_repository.dart';

/// Legacy adapter preserved for backwards compatibility during Phase 0 cleanup.
/// All simulated movement, timers, and fabricated coordinates have been removed.
/// Real railway telemetry will be provided by TrainRepository in Phase 4.
@Deprecated('Use TrainRepository directly')
class TrainSimulationEngine implements TrainDataRepository {
  static final TrainSimulationEngine _instance = TrainSimulationEngine._internal();
  factory TrainSimulationEngine() => _instance;
  TrainSimulationEngine._internal();

  final TrainRepository _repository = TrainRepository();

  @override
  Stream<List<LocoTrain>> get trainsStream => _repository.trainsStream;

  @override
  List<LocoTrain> get currentTrains => _repository.currentTrains;

  @override
  bool get isLiveFeedConnected => _repository.isLiveFeedConnected;

  // Stubs for legacy prototype calls
  void startSimulation() {}
  void stopSimulation() {}
  void resetSimulation() {}
  void injectDelay(String trainId, int delayMinutes) {}
  void setTrainCrowd(String trainId, String crowd) {}
}
