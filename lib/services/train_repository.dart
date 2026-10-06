import 'dart:async';
import '../models/train.dart';

/// Clean repository interface for Mumbai Suburban train positions and telemetry.
/// In Phase 0, live train simulation engines are removed.
/// Real-time GTFS-RT / Railway Provider integration will be connected in Phase 4 via the LOCO Backend.
abstract class TrainDataRepository {
  Stream<List<LocoTrain>> get trainsStream;
  List<LocoTrain> get currentTrains;
  bool get isLiveFeedConnected;
}

class TrainRepository implements TrainDataRepository {
  static final TrainRepository _instance = TrainRepository._internal();
  factory TrainRepository() => _instance;
  TrainRepository._internal();

  final _trainsController = StreamController<List<LocoTrain>>.broadcast();

  @override
  Stream<List<LocoTrain>> get trainsStream => _trainsController.stream;

  @override
  List<LocoTrain> get currentTrains => const [];

  @override
  bool get isLiveFeedConnected => false;
}
