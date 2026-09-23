import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket.dart';

class TicketStorage {
  static const String _storageKey = 'rail_two_booked_tickets';

  static Future<List<BookedTicket>> getTickets() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data == null || data.isEmpty) {
      final initialTickets = _getInitialMockTickets();
      await saveTickets(initialTickets);
      return initialTickets;
    }
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => BookedTicket.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return _getInitialMockTickets();
    }
  }

  static Future<void> saveTickets(List<BookedTicket> tickets) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(tickets.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  static Future<void> addTicket(BookedTicket ticket) async {
    final tickets = await getTickets();
    tickets.insert(0, ticket); // Insert latest at the top
    await saveTickets(tickets);
  }

  static List<BookedTicket> _getInitialMockTickets() {
    final now = DateTime.now();
    return [
      BookedTicket(
        id: 'XODHEGL014',
        fromStationName: 'DAHISAR',
        fromStationCode: 'DIC',
        toStationName: 'BORIVALI',
        toStationCode: 'BVI',
        ticketType: TicketType.journey,
        bookingType: BookingType.issue,
        trainType: 'ORDINARY',
        duration: 'SINGLE',
        classType: 'SECOND',
        fare: 5,
        bookingDate: now,
        status: TicketStatus.upcoming,
        distanceKm: 3.0,
        passengerName: 'Rakhi sinha',
        passengerAddress: '006-yashwant sneh, YK Nagar NX Virar West, Thane, India',
        passengerIdType: 'PAN Card',
        passengerIdNumber: 'SENP******',
      ),
      BookedTicket(
        id: 'XODJEE0036',
        fromStationName: 'DAHISAR',
        fromStationCode: 'DIC',
        toStationName: 'BORIVALI',
        toStationCode: 'BVI',
        ticketType: TicketType.journey,
        bookingType: BookingType.issue,
        trainType: 'ORDINARY',
        duration: 'SINGLE',
        classType: 'SECOND',
        fare: 5,
        bookingDate: DateTime(2026, 7, 11),
        status: TicketStatus.completed,
        distanceKm: 3.0,
        passengerName: 'Rakhi sinha',
        passengerAddress: '006-yashwant sneh, YK Nagar NX Virar West, Thane, India',
        passengerIdType: 'PAN Card',
        passengerIdNumber: 'SENP******',
      ),
      BookedTicket(
        id: 'XO3MEE320G',
        fromStationName: 'VASAI ROAD',
        fromStationCode: 'BSR',
        toStationName: 'VIRAR',
        toStationCode: 'VR',
        ticketType: TicketType.journey,
        bookingType: BookingType.issue,
        trainType: 'ORDINARY',
        duration: 'SINGLE',
        classType: 'SECOND',
        fare: 10,
        bookingDate: DateTime(2026, 7, 11),
        status: TicketStatus.completed,
        distanceKm: 9.0,
        passengerName: 'Rakhi sinha',
        passengerAddress: '006-yashwant sneh, YK Nagar NX Virar West, Thane, India',
        passengerIdType: 'PAN Card',
        passengerIdNumber: 'SENP******',
      ),
      BookedTicket(
        id: 'XODHEEL01D',
        fromStationName: 'DAHISAR',
        fromStationCode: 'DIC',
        toStationName: 'BORIVALI',
        toStationCode: 'BVI',
        ticketType: TicketType.journey,
        bookingType: BookingType.issue,
        trainType: 'ORDINARY',
        duration: 'SINGLE',
        classType: 'SECOND',
        fare: 5,
        bookingDate: DateTime(2026, 7, 13),
        status: TicketStatus.completed,
        distanceKm: 3.0,
        passengerName: 'Rakhi sinha',
        passengerAddress: '006-yashwant sneh, YK Nagar NX Virar West, Thane, India',
        passengerIdType: 'PAN Card',
        passengerIdNumber: 'SENP******',
      ),
    ];
  }
}
