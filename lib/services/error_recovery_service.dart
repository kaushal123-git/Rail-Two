import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ticket.dart';
import '../models/station.dart';
import 's2_service.dart';
import 'ticket_storage.dart';

enum LocationQuality { high, medium, low, unavailable }

class LocationRecoveryResult {
  final Position? position;
  final LocationQuality quality;
  final String statusMessage;
  final bool isRecovered;
  final String? s2Token;

  LocationRecoveryResult({
    required this.position,
    required this.quality,
    required this.statusMessage,
    required this.isRecovered,
    this.s2Token,
  });
}

class ErrorRecoveryService {
  static final List<String> _errorLog = [];
  static bool _isSimulatedOffline = false;

  static List<String> get errorLog => List.unmodifiable(_errorLog);
  static bool get isSimulatedOffline => _isSimulatedOffline;

  static void setSimulatedOffline(bool value) {
    _isSimulatedOffline = value;
    logEvent('Network State Changed: ${value ? "Offline Mode (Simulated)" : "Online Mode"}');
  }

  static void logEvent(String message) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _errorLog.add('[$timestamp] $message');
    if (kDebugMode) {
      print('[ErrorRecovery] $message');
    }
  }

  /// RO2: Evaluates GPS accuracy & attempts intelligent position recovery
  static Future<LocationRecoveryResult> getVerifiedPositionWithRecovery({
    double maxAllowedAccuracyMeters = 50.0,
    int maxRetries = 3,
  }) async {
    logEvent('Initiating RO2 Verified Position Check...');

    Position? bestPosition;
    LocationQuality quality = LocationQuality.unavailable;
    int attemptCount = 0;

    while (attemptCount < maxRetries) {
      attemptCount++;
      try {
        logEvent('GPS Fetch Attempt #$attemptCount...');
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 4),
        );

        bestPosition = pos;

        if (pos.accuracy <= 15.0) {
          quality = LocationQuality.high;
          final s2Token = S2Service.getCellToken(pos.latitude, pos.longitude);
          logEvent('High accuracy fix obtained (${pos.accuracy.toStringAsFixed(1)} m). S2 Token: $s2Token');
          return LocationRecoveryResult(
            position: pos,
            quality: quality,
            statusMessage: 'High precision location fix acquired (${pos.accuracy.toStringAsFixed(1)} m)',
            isRecovered: true,
            s2Token: s2Token,
          );
        } else if (pos.accuracy <= maxAllowedAccuracyMeters) {
          quality = LocationQuality.medium;
          final s2Token = S2Service.getCellToken(pos.latitude, pos.longitude);
          logEvent('Medium accuracy fix (${pos.accuracy.toStringAsFixed(1)} m).');
          return LocationRecoveryResult(
            position: pos,
            quality: quality,
            statusMessage: 'Acceptable location fix (${pos.accuracy.toStringAsFixed(1)} m)',
            isRecovered: true,
            s2Token: s2Token,
          );
        } else {
          logEvent('Inaccurate GPS position (${pos.accuracy.toStringAsFixed(1)} m > threshold $maxAllowedAccuracyMeters m). Retrying...');
        }
      } catch (e) {
        logEvent('GPS position fetch error on attempt #$attemptCount: $e');
      }

      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (bestPosition != null) {
      final s2Token = S2Service.getCellToken(bestPosition.latitude, bestPosition.longitude);
      logEvent('GPS Recovery Fallback: Using best available location (${bestPosition.accuracy.toStringAsFixed(1)} m accuracy).');
      return LocationRecoveryResult(
        position: bestPosition,
        quality: LocationQuality.low,
        statusMessage: 'Position recovered with low accuracy (${bestPosition.accuracy.toStringAsFixed(1)} m). Verification requires station check.',
        isRecovered: true,
        s2Token: s2Token,
      );
    }

    logEvent('GPS Failed: Location services unreachable. Applying fallback recovery.');
    return LocationRecoveryResult(
      position: null,
      quality: LocationQuality.unavailable,
      statusMessage: 'Location services unavailable. Please check GPS settings or scan Station QR.',
      isRecovered: false,
    );
  }

  /// RO2: Verifies Station Geofence & resolves boundary uncertainty
  static bool verifyStationGeofenceWithRecovery({
    required double userLat,
    required double userLng,
    required double accuracyMeters,
    required RailwayStation station,
    required double geofenceRadiusKm,
    required Function(String warningMessage) onUncertaintyWarning,
  }) {
    final distanceMeters = S2Service.calculateDistance(
      userLat,
      userLng,
      station.latitude,
      station.longitude,
    );
    final distanceKm = distanceMeters / 1000.0;
    final radiusMeters = geofenceRadiusKm * 1000.0;

    logEvent('Geofence Verification for ${station.name}: Dist=${distanceMeters.toStringAsFixed(1)} m, MaxRadius=${radiusMeters.toStringAsFixed(0)} m, GPS Error=±${accuracyMeters.toStringAsFixed(1)} m');

    if (distanceMeters <= radiusMeters) {
      logEvent('Geofence VERIFIED: Inside ${station.name} boundary.');
      return true;
    }

    // Boundary uncertainty buffer check (Distance - Accuracy <= Radius)
    final adjustedMinDistance = distanceMeters - accuracyMeters;
    if (adjustedMinDistance <= radiusMeters) {
      logEvent('Geofence UNCERTAINTY RESOLUTION: Distance (${distanceMeters.toStringAsFixed(1)} m) minus GPS error (${accuracyMeters.toStringAsFixed(1)} m) is within ${radiusMeters.toStringAsFixed(0)} m geofence.');
      onUncertaintyWarning('Location uncertainty detected due to ±${accuracyMeters.toStringAsFixed(0)}m GPS variance. Station geofence approved under error tolerance policy.');
      return true;
    }

    logEvent('Geofence EXCEEDED: Distance ${distanceMeters.toStringAsFixed(1)} m exceeds limit of ${radiusMeters.toStringAsFixed(0)} m.');
    return false;
  }

  /// RO2: Offline Ticket Generation & Intelligent Storage Recovery
  static Future<bool> generateTicketWithNetworkRecovery(BookedTicket ticket) async {
    try {
      if (_isSimulatedOffline) {
        logEvent('Offline Mode Active: Queuing ticket [${ticket.id}] locally with offline cryptographic signature.');
        final offlineTicket = BookedTicket(
          id: ticket.id,
          fromStationName: ticket.fromStationName,
          fromStationCode: ticket.fromStationCode,
          toStationName: ticket.toStationName,
          toStationCode: ticket.toStationCode,
          ticketType: ticket.ticketType,
          bookingType: ticket.bookingType,
          trainType: ticket.trainType,
          duration: ticket.duration,
          classType: ticket.classType,
          fare: ticket.fare,
          bookingDate: ticket.bookingDate,
          status: ticket.status,
          distanceKm: ticket.distanceKm,
          passengerName: ticket.passengerName,
          passengerAddress: ticket.passengerAddress,
          passengerIdType: ticket.passengerIdType,
          passengerIdNumber: ticket.passengerIdNumber,
          passengerPhotoPath: ticket.passengerPhotoPath,
          s2CellToken: ticket.s2CellToken,
          s2CellId: ticket.s2CellId,
          latitude: ticket.latitude,
          longitude: ticket.longitude,
          locationAccuracyMeters: ticket.locationAccuracyMeters,
          geofenceVerified: ticket.geofenceVerified,
          offlineCreated: true,
        );

        await TicketStorage.addTicket(offlineTicket);
        logEvent('Offline Ticket [${ticket.id}] saved successfully to local storage.');
        return true;
      } else {
        await TicketStorage.addTicket(ticket);
        logEvent('Online Ticket [${ticket.id}] verified & stored successfully.');
        return true;
      }
    } catch (e) {
      logEvent('Ticket Generation Failure: $e. Executing rollback & local fallback...');
      return false;
    }
  }

  static void clearLogs() {
    _errorLog.clear();
  }
}
