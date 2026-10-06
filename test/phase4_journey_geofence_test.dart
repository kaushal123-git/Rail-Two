import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:railway_station_finder/models/journey.dart';
import 'package:railway_station_finder/models/station.dart';
import 'package:railway_station_finder/models/ticket.dart';
import 'package:railway_station_finder/services/fraud_detection_service.dart';
import 'package:railway_station_finder/services/journey_guardian_service.dart';
import 'package:railway_station_finder/services/location_service.dart';
import 'package:railway_station_finder/widgets/journey_guardian_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testOrigin = RailwayStation(
    id: 'borivali',
    name: 'Borivali',
    latitude: 19.2290,
    longitude: 72.8573,
  );

  final testDest = RailwayStation(
    id: 'dadar',
    name: 'Dadar',
    latitude: 19.0192,
    longitude: 72.8438,
  );

  final testTicket = BookedTicket(
    id: 'TKT-TEST-001',
    fromStationName: 'Borivali',
    fromStationCode: 'BVI',
    toStationName: 'Dadar',
    toStationCode: 'DDR',
    ticketType: TicketType.journey,
    bookingType: BookingType.issue,
    trainType: 'FAST LOCAL',
    duration: '1 HOUR',
    classType: 'SECOND',
    fare: 15,
    bookingDate: DateTime.now(),
    status: TicketStatus.upcoming,
    distanceKm: 24.0,
    passengerName: 'Test Commuter',
    passengerAddress: 'Mumbai, Maharashtra',
    passengerIdType: 'Aadhaar',
    passengerIdNumber: '1234****',
  );

  group('Phase 4: ActiveJourney Model Tests', () {
    test('ActiveJourney initializes with Phase 4 security and corridor metadata', () {
      final journey = ActiveJourney(
        ticket: testTicket,
        originStation: testOrigin,
        destinationStation: testDest,
        currentStation: testOrigin,
        nextStation: testDest,
        serverJourneyId: 'j-uuid-1234',
        securityState: 'NORMAL',
        locationConfidence: 0.95,
        riskScore: 0.05,
        routeStationNames: ['Borivali', 'Andheri', 'Bandra', 'Dadar'],
      );

      expect(journey.serverJourneyId, 'j-uuid-1234');
      expect(journey.securityState, 'NORMAL');
      expect(journey.locationConfidence, 0.95);
      expect(journey.riskScore, 0.05);
      expect(journey.routeStationNames.length, 4);
      expect(journey.state, JourneyState.planned);
    });

    test('ActiveJourney copyWith preserves and modifies fields correctly', () {
      final journey = ActiveJourney(
        ticket: testTicket,
        originStation: testOrigin,
        destinationStation: testDest,
        currentStation: testOrigin,
        nextStation: testDest,
      );

      final updated = journey.copyWith(
        progressPercent: 65.0,
        securityState: 'ROUTE_DEVIATION',
        locationConfidence: 0.70,
        riskScore: 0.35,
        state: JourneyState.inTransit,
      );

      expect(updated.progressPercent, 65.0);
      expect(updated.securityState, 'ROUTE_DEVIATION');
      expect(updated.locationConfidence, 0.70);
      expect(updated.riskScore, 0.35);
      expect(updated.state, JourneyState.inTransit);
      expect(updated.originStation.name, 'Borivali');
    });
  });

  group('Phase 4: LocationService Evidence Collection Tests', () {
    test('getLocationEvidence returns expected signal keys', () async {
      final evidence = await LocationService.getLocationEvidence();

      expect(evidence.containsKey('latitude'), isTrue);
      expect(evidence.containsKey('longitude'), isTrue);
      expect(evidence.containsKey('accuracy_meters'), isTrue);
      expect(evidence.containsKey('provider'), isTrue);
      expect(evidence.containsKey('is_mock'), isTrue);
      expect(evidence.containsKey('timestamp_device'), isTrue);
      expect(evidence['provider'], 'gps');
    });
  });

  group('Phase 4: JourneyGuardianService Lifecycle Tests', () {
    final guardian = JourneyGuardianService();

    tearDown(() {
      guardian.clearJourney();
    });

    test('startJourney sets activeJourney and notifies stream', () async {
      expect(guardian.hasActiveJourney, isFalse);

      ActiveJourney? emitted;
      final sub = guardian.journeyStream.listen((j) => emitted = j);

      await guardian.startJourney(
        ticket: testTicket,
        originStation: testOrigin,
        destinationStation: testDest,
      );

      await Future.delayed(Duration.zero);

      expect(guardian.hasActiveJourney, isTrue);
      expect(guardian.activeJourney, isNotNull);
      expect(guardian.activeJourney!.originStation.name, 'Borivali');
      expect(guardian.activeJourney!.destinationStation.name, 'Dadar');
      expect(emitted, isNotNull);

      await sub.cancel();
    });

    test('completeJourney updates state to completed', () async {
      await guardian.startJourney(
        ticket: testTicket,
        originStation: testOrigin,
        destinationStation: testDest,
      );

      await guardian.completeJourney();

      expect(guardian.activeJourney!.state, JourneyState.completed);
      expect(guardian.activeJourney!.progressPercent, 100.0);
      expect(guardian.hasActiveJourney, isFalse);
    });

    test('abandonJourney updates state to abandoned', () async {
      await guardian.startJourney(
        ticket: testTicket,
        originStation: testOrigin,
        destinationStation: testDest,
      );

      await guardian.abandonJourney(reason: 'Commuter exited route');

      expect(guardian.activeJourney!.state, JourneyState.abandoned);
      expect(guardian.hasActiveJourney, isFalse);
    });
  });

  group('Phase 4: JourneyGuardianCard Widget Tests', () {
    testWidgets('renders station names, progress bar and security badge', (tester) async {
      final journey = ActiveJourney(
        ticket: testTicket,
        originStation: testOrigin,
        destinationStation: testDest,
        currentStation: RailwayStation(id: 'andheri', name: 'Andheri', latitude: 19.1197, longitude: 72.8464),
        nextStation: RailwayStation(id: 'bandra', name: 'Bandra', latitude: 19.0544, longitude: 72.8406),
        securityState: 'NORMAL',
        progressPercent: 45.0,
        speedKmH: 52.0,
        locationConfidence: 0.94,
        riskScore: 0.05,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: JourneyGuardianCard(journey: journey),
            ),
          ),
        ),
      );

      expect(find.text('JOURNEY GUARDIAN'), findsOneWidget);
      expect(find.text('TRUSTED JOURNEY'), findsOneWidget);
      expect(find.text('Borivali'), findsOneWidget);
      expect(find.text('Dadar'), findsOneWidget);
      expect(find.text('Andheri'), findsOneWidget);
      expect(find.text('Bandra'), findsOneWidget);
      expect(find.text('45%'), findsOneWidget);
      expect(find.text('Complete at Destination'), findsOneWidget);
    });

    testWidgets('displays security warning badge when anomaly flagged', (tester) async {
      final suspiciousJourney = ActiveJourney(
        ticket: testTicket,
        originStation: testOrigin,
        destinationStation: testDest,
        currentStation: testOrigin,
        nextStation: testDest,
        securityState: 'SECURITY_WARNING',
        locationConfidence: 0.40,
        riskScore: 0.85,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: JourneyGuardianCard(journey: suspiciousJourney),
            ),
          ),
        ),
      );

      expect(find.text('SECURITY WARNING'), findsOneWidget);
    });
  });

  group('Phase 4: FraudDetectionService Signal Evaluation Tests', () {
    test('Teleportation / Impossible Speed flags anomaly correctly', () {
      final features = BookingPatternFeatures(
        userLat: 19.0192,
        userLng: 72.8438,
        accuracyMeters: 5.0,
        distanceToStationMeters: 50.0,
        timeDifferenceSeconds: 10.0,
        distanceMovedFromLastBookingKm: 30.0, // 30km in 10s = 10,800 km/h!
        isQrScanned: false,
        isOffline: false,
        deviceId: 'device-test-1',
      );

      final result = FraudDetectionService.analyzeBookingAttempt(features);

      expect(result.riskLevel, FraudRiskLevel.fraudulent);
      expect(result.isTicketAllowed, isFalse);
      expect(result.riskScore, greaterThan(0.7));
      expect(result.flaggedAnomalies.any((a) => a.contains('Impossible Travel Velocity')), isTrue);
    });

    test('Clean legitimate booking patterns pass validation', () {
      final cleanFeatures = BookingPatternFeatures(
        userLat: 19.2290,
        userLng: 72.8573,
        accuracyMeters: 8.0,
        distanceToStationMeters: 40.0,
        timeDifferenceSeconds: 3600.0,
        distanceMovedFromLastBookingKm: 0.1,
        isQrScanned: true,
        isOffline: false,
        deviceId: 'device-test-2',
      );

      final result = FraudDetectionService.analyzeBookingAttempt(cleanFeatures);

      expect(result.riskLevel, FraudRiskLevel.legitimate);
      expect(result.isTicketAllowed, isTrue);
    });
  });
}
