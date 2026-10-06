import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ticket.dart';
import 'api_service.dart';

/// Abstract repository for LOCO Tickets.
abstract class TicketRepository {
  Future<List<BookedTicket>> getTickets();
  Future<void> addTicket(BookedTicket ticket);
  Future<void> saveTickets(List<BookedTicket> tickets);
}

class LocalTicketRepository implements TicketRepository {
  @override
  Future<List<BookedTicket>> getTickets() => TicketStorage.getTickets();

  @override
  Future<void> addTicket(BookedTicket ticket) => TicketStorage.addTicket(ticket);

  @override
  Future<void> saveTickets(List<BookedTicket> tickets) => TicketStorage.saveTickets(tickets);
}

/// Storage & synchronization service for user tickets.
/// Connects to LOCO FastAPI backend authority with local offline caching.
class TicketStorage {
  static const String _storageKey = 'rail_two_booked_tickets';

  /// Get user tickets: Synchronizes with backend if online, otherwise serves local cache.
  static Future<List<BookedTicket>> getTickets() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Try synchronizing with backend authority if online
    try {
      final token = await ApiService.getAccessToken();
      if (token != null && token.isNotEmpty) {
        final backendTickets = await ApiService.getTickets();
        if (backendTickets.isNotEmpty) {
          final List<BookedTicket> mappedTickets = [];
          for (final t in backendTickets) {
            try {
              mappedTickets.add(BookedTicket.fromBackendJson(t));
            } catch (err) {
              debugPrint('Error mapping backend ticket: $err');
            }
          }

          if (mappedTickets.isNotEmpty) {
            await saveTickets(mappedTickets);
            return mappedTickets;
          }
        }
      }
    } catch (e) {
      debugPrint('Notice: Backend tickets sync fallback: $e');
    }

    // 2. Offline fallback from local cache
    final String? data = prefs.getString(_storageKey);
    if (data == null || data.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((e) => BookedTicket.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }


  static Future<void> saveTickets(List<BookedTicket> tickets) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(tickets.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }

  static Future<void> addTicket(BookedTicket ticket) async {
    final tickets = await getTickets();
    tickets.insert(0, ticket);
    await saveTickets(tickets);
  }
}
