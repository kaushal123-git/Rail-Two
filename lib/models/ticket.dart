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
    );
  }
}
