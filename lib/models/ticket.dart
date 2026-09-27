import 'dart:convert';

enum TicketStatus { upcoming, completed, cancelled }

enum TicketType { journey, returnTicket, season }

enum BookingType { issue, renew }

class BookedTicket {
  final String id; // UTS Booking Code, e.g. XODHEGL014
  final String fromStationName;
  final String fromStationCode;
  final String toStationName;
  final String toStationCode;
  final TicketType ticketType;
  final BookingType bookingType;
  final String trainType; // ORDINARY, MAIL/EXP, SUPERFAST, AC EMU TRAIN
  final String duration; // MONTHLY, QUARTERLY, HALF YEARLY, YEARLY, FORTNIGHTLY
  final String classType; // FIRST, SECOND
  final int fare;
  final DateTime bookingDate;
  final TicketStatus status;
  final double distanceKm;
  final String passengerName;
  final String passengerAddress;
  final String passengerIdType;
  final String passengerIdNumber;
  final String? passengerPhotoPath;

  // RO1: Spatial Indexing & Geofence Verification Metadata
  final String? s2CellToken;
  final String? s2CellId;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracyMeters;
  final bool geofenceVerified;
  final bool offlineCreated;

  BookedTicket({
    required this.id,
    required this.fromStationName,
    required this.fromStationCode,
    required this.toStationName,
    required this.toStationCode,
    required this.ticketType,
    required this.bookingType,
    required this.trainType,
    required this.duration,
    required this.classType,
    required this.fare,
    required this.bookingDate,
    required this.status,
    required this.distanceKm,
    required this.passengerName,
    required this.passengerAddress,
    required this.passengerIdType,
    required this.passengerIdNumber,
    this.passengerPhotoPath,
    this.s2CellToken,
    this.s2CellId,
    this.latitude,
    this.longitude,
    this.locationAccuracyMeters,
    this.geofenceVerified = true,
    this.offlineCreated = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromStationName': fromStationName,
      'fromStationCode': fromStationCode,
      'toStationName': toStationName,
      'toStationCode': toStationCode,
      'ticketType': ticketType.name,
      'bookingType': bookingType.name,
      'trainType': trainType,
      'duration': duration,
      'classType': classType,
      'fare': fare,
      'bookingDate': bookingDate.toIso8601String(),
      'status': status.name,
      'distanceKm': distanceKm,
      'passengerName': passengerName,
      'passengerAddress': passengerAddress,
      'passengerIdType': passengerIdType,
      'passengerIdNumber': passengerIdNumber,
      'passengerPhotoPath': passengerPhotoPath,
      's2CellToken': s2CellToken,
      's2CellId': s2CellId,
      'latitude': latitude,
      'longitude': longitude,
      'locationAccuracyMeters': locationAccuracyMeters,
      'geofenceVerified': geofenceVerified,
      'offlineCreated': offlineCreated,
    };
  }

  factory BookedTicket.fromJson(Map<String, dynamic> json) {
    return BookedTicket(
      id: json['id'] as String,
      fromStationName: json['fromStationName'] as String,
      fromStationCode: json['fromStationCode'] as String,
      toStationName: json['toStationName'] as String,
      toStationCode: json['toStationCode'] as String,
      ticketType: TicketType.values.firstWhere(
        (e) => e.name == json['ticketType'],
        orElse: () => TicketType.journey,
      ),
      bookingType: BookingType.values.firstWhere(
        (e) => e.name == json['bookingType'],
        orElse: () => BookingType.issue,
      ),
      trainType: json['trainType'] as String? ?? 'ORDINARY',
      duration: json['duration'] as String? ?? 'SINGLE',
      classType: json['classType'] as String? ?? 'SECOND',
      fare: (json['fare'] as num).toInt(),
      bookingDate: DateTime.parse(json['bookingDate'] as String),
      status: TicketStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TicketStatus.upcoming,
      ),
      distanceKm: (json['distanceKm'] as num? ?? 3.0).toDouble(),
      passengerName: json['passengerName'] as String? ?? 'Rakhi sinha',
      passengerAddress: json['passengerAddress'] as String? ?? '006-yashwant sneh, YK Nagar NX Virar West',
      passengerIdType: json['passengerIdType'] as String? ?? 'PAN Card',
      passengerIdNumber: json['passengerIdNumber'] as String? ?? 'SENP******',
      passengerPhotoPath: json['passengerPhotoPath'] as String?,
      s2CellToken: json['s2CellToken'] as String?,
      s2CellId: json['s2CellId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAccuracyMeters: (json['locationAccuracyMeters'] as num?)?.toDouble(),
      geofenceVerified: json['geofenceVerified'] as bool? ?? true,
      offlineCreated: json['offlineCreated'] as bool? ?? false,
    );
  }
}
