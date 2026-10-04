import '../models/ai_models.dart';

class AppGuideEngine {
  static final AppGuideEngine _instance = AppGuideEngine._internal();
  factory AppGuideEngine() => _instance;
  AppGuideEngine._internal();

  /// Formats user assistance guide responses for app features
  String getFeatureGuide(AIIntentType intent, {String? origin, String? destination}) {
    switch (intent) {
      case AIIntentType.bookTicket:
        final routeStr = (origin != null && destination != null) ? ' from $origin to $destination' : '';
        return '🎫 How to Book Tickets on LOCO:\n\n'
            '1. Tap the "Book Ticket" button below or select "Home" tab.\n'
            '2. Choose your Origin & Destination stations$routeStr.\n'
            '3. Select ticket type (Single Journey, Return, or AC Local).\n'
            '4. Complete 1-Tap Payment via wallet or UPI.\n'
            '5. Your ticket will instantly show a encrypted QR code valid offline!';

      case AIIntentType.renewPass:
        return '💳 Season Ticket (Pass) Guide:\n\n'
            '1. Select "Season Ticket" on the Home Screen.\n'
            '2. Choose duration (Monthly, Quarterly, Half-Yearly, Yearly).\n'
            '3. Select First Class, Second Class, or AC Local.\n'
            '4. Pass is automatically linked to your device ID and available offline!';

      case AIIntentType.guardianSOS:
        return '🛡️ Journey Guardian (Safety SOS) Guide:\n\n'
            '• LOCO monitors live GPS and track telemetry during your journey.\n'
            '• If your train halts for >10 minutes outside a station or detects unusual delays, Guardian alerts your emergency contacts.\n'
            '• Tap "Activate Guardian Mode" below to protect your active trip.';

      case AIIntentType.utsPolicy:
        return '📋 UTS Ticketing Policy & Rules:\n\n'
            '• Single Journey Ticket: Valid to start journey within 1 hour of booking. Must complete within 3 hours.\n'
            '• Return Ticket: Valid for return trip until midnight of the following calendar day.\n'
            '• Platform Pass: Valid for 2 hours within station premises (₹10).\n'
            '• Mobile Validation: Digital tickets are tamper-proof and cryptographically signed for offline TC inspection.';

      default:
        return '📱 LOCO App Features Overview:\n\n'
            '• 🚆 Live Routes & Track Telemetry: Real-time train tracking & delay risks.\n'
            '• 🎫 Digital UTS Ticketing: 1-Tap paperless single, return, and season passes.\n'
            '• ⚡ Coach Crowd Radar: AI coach density advice for comfortable commutes.\n'
            '• 🛡️ Journey Guardian: Automated track signal safety & emergency SOS.';
    }
  }
}
