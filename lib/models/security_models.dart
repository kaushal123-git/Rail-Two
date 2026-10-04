enum LocationTrustLevel {
  trusted,
  uncertain,
  suspicious,
  critical,
}

enum SecurityEventType {
  gpsSpoofing,
  impossibleSpeed,
  ticketReuse,
  geofenceAnomaly,
  multipleDevices,
}

class SecurityEvent {
  final String id;
  final DateTime timestamp;
  final String title;
  final SecurityEventType type;
  final String description;
  final int riskScore; // 0-100
  final bool requiresAction;

  SecurityEvent({
    required this.id,
    required this.timestamp,
    required this.title,
    required this.type,
    required this.description,
    required this.riskScore,
    this.requiresAction = false,
  });
}
