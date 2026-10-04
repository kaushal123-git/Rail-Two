enum TicketStatus { upcoming, completed, cancelled, suspicious }

enum TicketType { journey, returnTicket, season }

enum BookingType { issue, renew }

enum TicketLifecycle {
  created,
  active,
  inJourney,
  completed,
  expired,
  cancelled,
  suspicious,
}

class BookedTicket {
  final String id; // UTS / LOCO Booking Code, e.g. LOCO-VR-9042 or XODHEGL014
  final String fromStationName;
  final String fromStationCode;
  final String toStationName;
  final String toStationCode;
  final TicketType ticketType;
  final BookingType bookingType;
  final String trainType; // ORDINARY, MAIL/EXP, SUPERFAST, AC EMU TRAIN
  final String duration; // SINGLE, MONTHLY, QUARTERLY, HALF YEARLY, YEARLY, FORTNIGHTLY
  final String classType; // FIRST, SECOND
  final int fare;
  final DateTime bookingDate;
  final DateTime? validUntil;
  final TicketStatus status;
  final TicketLifecycle lifecycle;
  final double distanceKm;
  final String passengerName;
  final String passengerAddress;
  final String passengerIdType;
  final String passengerIdNumber;
  final String? passengerPhotoPath;
  final String qrSecurityToken;
  final int riskScore; // 0 to 100 for fraud detection

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
    this.validUntil,
    required this.status,
    this.lifecycle = TicketLifecycle.active,
    required this.distanceKm,
    required this.passengerName,
    required this.passengerAddress,
    required this.passengerIdType,
    required this.passengerIdNumber,
    this.passengerPhotoPath,
    String? qrSecurityToken,
    this.riskScore = 0,
    this.s2CellToken,
    this.s2CellId,
    this.latitude,
    this.longitude,
    this.locationAccuracyMeters,
    this.geofenceVerified = true,
    this.offlineCreated = false,
  }) : qrSecurityToken = qrSecurityToken ?? 'LOCO_SEC_v2:$id:${bookingDate.millisecondsSinceEpoch}:MUMBAI_SUBURBAN';

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
      'validUntil': validUntil?.toIso8601String(),
      'status': status.name,
      'lifecycle': lifecycle.name,
      'distanceKm': distanceKm,
      'passengerName': passengerName,
      'passengerAddress': passengerAddress,
      'passengerIdType': passengerIdType,
      'passengerIdNumber': passengerIdNumber,
      'passengerPhotoPath': passengerPhotoPath,
      'qrSecurityToken': qrSecurityToken,
      'riskScore': riskScore,
    };
  }

  factory BookedTicket.fromJson(Map<String, dynamic> json) {
    final bDate = DateTime.parse(json['bookingDate'] as String);
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
      bookingDate: bDate,
      validUntil: json['validUntil'] != null ? DateTime.parse(json['validUntil'] as String) : bDate.add(const Duration(hours: 3)),
      status: TicketStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TicketStatus.upcoming,
      ),
      lifecycle: TicketLifecycle.values.firstWhere(
        (e) => e.name == json['lifecycle'],
        orElse: () => TicketLifecycle.active,
      ),
      distanceKm: (json['distanceKm'] as num? ?? 3.0).toDouble(),
      passengerName: json['passengerName'] as String? ?? 'Aayush Sinha',
      passengerAddress: json['passengerAddress'] as String? ?? 'Bandra West, Mumbai',
      passengerIdType: json['passengerIdType'] as String? ?? 'PAN Card',
      passengerIdNumber: json['passengerIdNumber'] as String? ?? 'SENP******',
      passengerPhotoPath: json['passengerPhotoPath'] as String?,
      qrSecurityToken: json['qrSecurityToken'] as String?,
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
    );
  }

  BookedTicket copyWith({
    String? id,
    String? fromStationName,
    String? fromStationCode,
    String? toStationName,
    String? toStationCode,
    TicketType? ticketType,
    BookingType? bookingType,
    String? trainType,
    String? duration,
    String? classType,
    int? fare,
    DateTime? bookingDate,
    DateTime? validUntil,
    TicketStatus? status,
    TicketLifecycle? lifecycle,
    double? distanceKm,
    String? passengerName,
    String? passengerAddress,
    String? passengerIdType,
    String? passengerIdNumber,
    String? passengerPhotoPath,
    String? qrSecurityToken,
    int? riskScore,
  }) {
    return BookedTicket(
      id: id ?? this.id,
      fromStationName: fromStationName ?? this.fromStationName,
      fromStationCode: fromStationCode ?? this.fromStationCode,
      toStationName: toStationName ?? this.toStationName,
      toStationCode: toStationCode ?? this.toStationCode,
      ticketType: ticketType ?? this.ticketType,
      bookingType: bookingType ?? this.bookingType,
      trainType: trainType ?? this.trainType,
      duration: duration ?? this.duration,
      classType: classType ?? this.classType,
      fare: fare ?? this.fare,
      bookingDate: bookingDate ?? this.bookingDate,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      lifecycle: lifecycle ?? this.lifecycle,
      distanceKm: distanceKm ?? this.distanceKm,
      passengerName: passengerName ?? this.passengerName,
      passengerAddress: passengerAddress ?? this.passengerAddress,
      passengerIdType: passengerIdType ?? this.passengerIdType,
      passengerIdNumber: passengerIdNumber ?? this.passengerIdNumber,
      passengerPhotoPath: passengerPhotoPath ?? this.passengerPhotoPath,
      qrSecurityToken: qrSecurityToken ?? this.qrSecurityToken,
      riskScore: riskScore ?? this.riskScore,
    );
  }
}
