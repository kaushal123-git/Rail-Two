import 'dart:async';
import '../models/train.dart';

class TrainSimulationEngine {
  static final TrainSimulationEngine _instance = TrainSimulationEngine._internal();
  factory TrainSimulationEngine() => _instance;
  TrainSimulationEngine._internal() {
    _initTrains();
    startSimulation();
  }

  final _trainsController = StreamController<List<LocoTrain>>.broadcast();
  Stream<List<LocoTrain>> get trainsStream => _trainsController.stream;
  List<LocoTrain> _trains = [];
  List<LocoTrain> get currentTrains => List.unmodifiable(_trains);

  Timer? _ticker;
  bool _isSimulating = false;

  void _initTrains() {
    _trains = [
      LocoTrain(
        id: 'WR-90142',
        name: 'VR-CCG FAST',
        number: '90142',
        line: 'Western',
        trainType: 'Fast Local',
        originStation: 'Virar',
        destinationStation: 'Churchgate',
        currentStation: 'Borivali',
        nextStation: 'Andheri',
        progress: 0.35,
        speedKmH: 62.0,
        etaMinutes: 28,
        delayMinutes: 0,
        crowdLevel: 'High',
        status: 'On Time',
        routeStationNames: ['Virar', 'Vasai Road', 'Bhayandar', 'Borivali', 'Andheri', 'Bandra', 'Dadar', 'Mumbai Central', 'Churchgate'],
        lat: 19.1845,
        lng: 72.8521,
      ),
      LocoTrain(
        id: 'WR-90215',
        name: 'BVI-CCG AC EMU',
        number: '90215',
        line: 'Western',
        trainType: 'AC EMU',
        originStation: 'Borivali',
        destinationStation: 'Churchgate',
        currentStation: 'Kandivali',
        nextStation: 'Malad',
        progress: 0.65,
        speedKmH: 54.0,
        etaMinutes: 34,
        delayMinutes: 0,
        crowdLevel: 'Moderate',
        status: 'On Time',
        routeStationNames: ['Borivali', 'Kandivali', 'Malad', 'Goregaon', 'Andheri', 'Bandra', 'Dadar', 'Churchgate'],
        lat: 19.1950,
        lng: 72.8505,
        isAc: true,
      ),
      LocoTrain(
        id: 'WR-90334',
        name: 'CCG-VR FAST',
        number: '90334',
        line: 'Western',
        trainType: 'Fast Local',
        originStation: 'Churchgate',
        destinationStation: 'Virar',
        currentStation: 'Bandra',
        nextStation: 'Andheri',
        progress: 0.20,
        speedKmH: 58.0,
        etaMinutes: 42,
        delayMinutes: 0,
        crowdLevel: 'Very High',
        status: 'On Time',
        routeStationNames: ['Churchgate', 'Mumbai Central', 'Dadar', 'Bandra', 'Andheri', 'Borivali', 'Vasai Road', 'Virar'],
        lat: 19.0750,
        lng: 72.8425,
      ),
      LocoTrain(
        id: 'WR-90412',
        name: 'DDR-VR SLOW',
        number: '90412',
        line: 'Western',
        trainType: 'Slow Local',
        originStation: 'Dadar',
        destinationStation: 'Virar',
        currentStation: 'Malad',
        nextStation: 'Kandivali',
        progress: 0.80,
        speedKmH: 48.0,
        etaMinutes: 31,
        delayMinutes: 2,
        crowdLevel: 'Moderate',
        status: 'Delayed +2m',
        routeStationNames: ['Dadar', 'Matunga Road', 'Mahim', 'Bandra', 'Andheri', 'Goregaon', 'Malad', 'Kandivali', 'Borivali', 'Virar'],
        lat: 19.1980,
        lng: 72.8510,
      ),
      LocoTrain(
        id: 'CR-70110',
        name: 'CSMT-KYN FAST',
        number: '70110',
        line: 'Central',
        trainType: 'Fast Local',
        originStation: 'CSMT',
        destinationStation: 'Kalyan',
        currentStation: 'Kurla',
        nextStation: 'Ghatkopar',
        progress: 0.50,
        speedKmH: 65.0,
        etaMinutes: 24,
        delayMinutes: 0,
        crowdLevel: 'Very High',
        status: 'On Time',
        routeStationNames: ['CSMT', 'Byculla', 'Dadar', 'Kurla', 'Ghatkopar', 'Thane', 'Kalyan'],
        lat: 19.0750,
        lng: 72.8935,
      ),
      LocoTrain(
        id: 'CR-70230',
        name: 'KYN-CSMT AC LOCAL',
        number: '70230',
        line: 'Central',
        trainType: 'AC EMU',
        originStation: 'Kalyan',
        destinationStation: 'CSMT',
        currentStation: 'Thane',
        nextStation: 'Ghatkopar',
        progress: 0.40,
        speedKmH: 60.0,
        etaMinutes: 29,
        delayMinutes: 0,
        crowdLevel: 'Low',
        status: 'On Time',
        routeStationNames: ['Kalyan', 'Dombivli', 'Thane', 'Ghatkopar', 'Kurla', 'Dadar', 'CSMT'],
        lat: 19.1360,
        lng: 72.9420,
        isAc: true,
      ),
      LocoTrain(
        id: 'HR-80150',
        name: 'CSMT-PNVL SLOW',
        number: '80150',
        line: 'Harbour',
        trainType: 'Slow Local',
        originStation: 'CSMT',
        destinationStation: 'Panvel',
        currentStation: 'Wadala Road',
        nextStation: 'Chembur',
        progress: 0.45,
        speedKmH: 45.0,
        etaMinutes: 38,
        delayMinutes: 0,
        crowdLevel: 'Moderate',
        status: 'On Time',
        routeStationNames: ['CSMT', 'Wadala Road', 'Chembur', 'Vashi', 'Nerul', 'Panvel'],
        lat: 19.0395,
        lng: 72.8790,
      ),
    ];
  }

  void startSimulation() {
    if (_isSimulating) return;
    _isSimulating = true;
    _ticker = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      _tick();
    });
  }

  void stopSimulation() {
    _ticker?.cancel();
    _isSimulating = false;
  }

  void _tick() {
    final updated = <LocoTrain>[];
    for (final train in _trains) {
      double newProgress = train.progress + 0.035;
      double newLat = train.lat;
      double newLng = train.lng;

      // Drift slightly along the track direction
      if (train.line == 'Western') {
        if (train.destinationStation == 'Churchgate') {
          // Southbound
          newLat -= 0.0012;
          newLng -= 0.0003;
        } else {
          // Northbound
          newLat += 0.0012;
          newLng += 0.0003;
        }
      } else if (train.line == 'Central') {
        newLat += (train.destinationStation == 'Kalyan' ? 0.0015 : -0.0015);
        newLng += (train.destinationStation == 'Kalyan' ? 0.0020 : -0.0020);
      }

      int newEta = train.etaMinutes;
      if (newProgress >= 1.0) {
        newProgress = 0.05;
        newEta = (train.etaMinutes > 2 ? train.etaMinutes - 2 : 25);
      }

      updated.add(train.copyWith(
        progress: newProgress,
        lat: newLat,
        lng: newLng,
        etaMinutes: newEta,
      ));
    }
    _trains = updated;
    _trainsController.add(_trains);
  }

  /// Demo helper: Injects a delay into a specific train
  void injectDelay(String trainId, int delayMins) {
    _trains = _trains.map((t) {
      if (t.id == trainId || t.name.contains(trainId)) {
        return t.copyWith(
          delayMinutes: delayMins,
          status: 'Delayed +${delayMins}m',
          etaMinutes: t.etaMinutes + delayMins,
        );
      }
      return t;
    }).toList();
    _trainsController.add(_trains);
  }

  /// Demo helper: Updates crowd level
  void setTrainCrowd(String trainId, String crowd) {
    _trains = _trains.map((t) {
      if (t.id == trainId || t.name.contains(trainId)) {
        return t.copyWith(crowdLevel: crowd);
      }
      return t;
    }).toList();
    _trainsController.add(_trains);
  }

  void resetSimulation() {
    _initTrains();
    _trainsController.add(_trains);
  }

  void dispose() {
    _ticker?.cancel();
    _trainsController.close();
  }
}
