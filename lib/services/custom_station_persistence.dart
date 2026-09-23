import 'custom_station_persistence_stub.dart'
    if (dart.library.html) 'custom_station_persistence_web.dart'
    if (dart.library.io) 'custom_station_persistence_native.dart';

import '../models/station.dart';

abstract class CustomStationPersistence {
  Future<List<RailwayStation>> loadCustomStations();
  Future<void> saveCustomStations(List<RailwayStation> customStations);
}

final CustomStationPersistence customStationPersistence = getPersistence();
