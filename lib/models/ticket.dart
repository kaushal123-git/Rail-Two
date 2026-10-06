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
  final String provider;

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
    this.provider = 'LOCO_CORE',
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
      'provider': provider,
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
      passengerName: json['passengerName'] as String? ?? 'Commuter',
      passengerAddress: json['passengerAddress'] as String? ?? 'Mumbai Suburban',
      passengerIdType: json['passengerIdType'] as String? ?? 'PAN Card',
      passengerIdNumber: json['passengerIdNumber'] as String? ?? 'SENP******',
      passengerPhotoPath: json['passengerPhotoPath'] as String?,
      qrSecurityToken: json['qrSecurityToken'] as String?,
      riskScore: (json['riskScore'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? 'LOCO_CORE',
    );
  }

  factory BookedTicket.fromBackendJson(Map<String, dynamic> json) {
    final bDate = json['issued_at'] != null
        ? DateTime.parse(json['issued_at'] as String)
        : (json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now());
    final vUntil = json['valid_until'] != null
        ? DateTime.parse(json['valid_until'] as String)
        : bDate.add(const Duration(hours: 3));

    final backendStatus = (json['ticket_status'] as String? ?? 'ISSUED').toUpperCase();
    TicketStatus st = TicketStatus.upcoming;
    TicketLifecycle lc = TicketLifecycle.active;

    switch (backendStatus) {
      case 'COMPLETED':
        st = TicketStatus.completed;
        lc = TicketLifecycle.completed;
        break;
      case 'CANCELLED':
        st = TicketStatus.cancelled;
        lc = TicketLifecycle.cancelled;
        break;
      case 'EXPIRED':
        st = TicketStatus.completed;
        lc = TicketLifecycle.expired;
        break;
      case 'FRAUD_BLOCKED':
        st = TicketStatus.suspicious;
        lc = TicketLifecycle.suspicious;
        break;
      case 'IN_JOURNEY':
        st = TicketStatus.upcoming;
        lc = TicketLifecycle.inJourney;
        break;
      case 'ACTIVE':
      case 'ISSUED':
      default:
        st = TicketStatus.upcoming;
        lc = TicketLifecycle.active;
        break;
    }

    final origMap = json['origin_station'] as Map<String, dynamic>?;
    final destMap = json['destination_station'] as Map<String, dynamic>?;

    final origName = origMap?['name'] ?? origMap?['display_name'] ?? 'Origin';
    final origCode = origMap?['code'] ?? 'ORIG';
    final destName = destMap?['name'] ?? destMap?['display_name'] ?? 'Destination';
    final destCode = destMap?['code'] ?? 'DEST';

    final jType = (json['journey_type'] as String? ?? 'SINGLE').toUpperCase();
    final TicketType tType;
    if (jType == 'SEASON') {
      tType = TicketType.season;
    } else if (jType == 'RETURN') {
      tType = TicketType.returnTicket;
    } else {
      tType = TicketType.journey;
    }

    return BookedTicket(
      id: json['provider_ticket_id'] as String? ?? (json['id'] as String? ?? 'LOCO-TKT'),
      fromStationName: origName as String,
      fromStationCode: origCode as String,
      toStationName: destName as String,
      toStationCode: destCode as String,
      ticketType: tType,
      bookingType: BookingType.issue,
      trainType: 'SUBURBAN EMU',
      duration: jType,
      classType: json['ticket_class'] as String? ?? 'SECOND',
      fare: (json['fare'] as num?)?.toInt() ?? 10,
      bookingDate: bDate,
      validUntil: vUntil,
      status: st,
      lifecycle: lc,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 5.0,
      passengerName: json['passenger_name'] as String? ?? 'Commuter',
      passengerAddress: 'Mumbai Suburban Transit',
      passengerIdType: 'Digital Identity',
      passengerIdNumber: json['id'] as String? ?? '',
      qrSecurityToken: json['qr_token_id'] as String?,
      provider: json['provider'] as String? ?? 'LOCO_CORE',
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
    String? provider,
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
      provider: provider ?? this.provider,
    );
  }
}
