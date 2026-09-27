# 🚉 Rail Two - Railway Station Finder & Smart Ticketing App

A comprehensive Flutter application for discovering nearby railway stations via GPS location & Google's S2 Geometry system, booking journey & season tickets, managing user authentication with MPIN/OTP, and preventing fraud with enterprise recovery & analytics services.

---

## ✨ Features

### 📍 Station Finder & Spatial Indexing
- **Live GPS Detection**: Real-time location tracking using `geolocator`.
- **S2 Spatial Indexing**: Fast distance calculation and spatial cell indexing using `s2geometry`.
- **Custom Stations**: Add custom station coordinates with live S2 Cell ID preview.
- **Cross-Platform Support**: Seamless performance across Mobile and Web platforms with conditional helpers.

### 🎟️ Smart Ticketing & Season Passes
- **Journey Ticket Booking**: Book single/round-trip tickets between stations.
- **Season Ticket Passes**: Purchase and renew quarterly/monthly season passes.
- **Booking History**: Track active, past, and expired tickets locally via `TicketStorage`.

### 🔐 User Auth & Security
- **Authentication**: Sign-in, Login, and OTP verification flow.
- **MPIN Protection**: Set and verify a secure 4-digit MPIN for quick access.
- **Fraud Detection**: Integrated `FraudDetectionService` to evaluate suspicious booking patterns.

### 🛡️ Enterprise & Recovery Services
- **Revenue Recovery Service**: Automate collection and audit checks for unpaid journeys.
- **Error Recovery Service**: Graceful failover and retry logic for failed operations.
- **Analytics & Research Validation**: Comprehensive evaluation screens and telemetry logs.

---

## 🛠️ Project Structure

```text
lib/
├── main.dart                             # App entry point & theme configuration
├── models/
│   ├── station.dart                      # Station data model (Lat/Lng, S2 Cell Token)
│   └── ticket.dart                       # Ticket & Season pass data models
├── services/
│   ├── s2_service.dart                   # S2 spatial indexing & distance logic
│   ├── location_service.dart             # GPS location retrieval & permissions
│   ├── station_storage.dart              # Default & custom station storage
│   ├── ticket_storage.dart               # Local ticketing persistence
│   ├── auth_service.dart                 # Authentication & MPIN management
│   ├── fraud_detection_service.dart      # Fraud prevention & risk evaluation
│   ├── revenue_recovery_service.dart     # Unpaid fare collection & recovery logic
│   ├── error_recovery_service.dart       # Error handling & failover strategies
│   ├── analytics_evaluation_service.dart # Usage analytics & performance tracking
│   ├── s2_helper_*.dart                  # Conditional platform handlers for S2 (Web/Native)
│   └── custom_station_persistence_*.dart # Conditional platform storage handlers
└── screens/
    ├── home_screen.dart                  # Main dashboard & nearest station summary
    ├── stations_list_screen.dart         # Station lookup & distance filtering
    ├── add_station_screen.dart           # Custom station entry with live S2 preview
    ├── login_screen.dart                 # User login interface
    ├── signin_screen.dart                # Account registration
    ├── otp_verification_screen.dart      # OTP validation screen
    ├── set_mpin_screen.dart              # MPIN creation & setup
    ├── booking_screen.dart               # Ticket booking interface
    ├── season_booking_screen.dart        # Season pass creation interface
    ├── my_bookings_screen.dart           # Active & past ticket history
    └── research_validation_screen.dart   # System validation & analytics screen
assets/
└── default_stations.json                 # Pre-populated station dataset
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) installed (Dart 3.0+)
- Android Studio / Xcode / VS Code configured with Flutter plugins

### 1. Clone the repository

```bash
git clone https://github.com/kaushal123-git/Rail-Two.git
cd Rail-Two
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run the app

```bash
flutter run
```

---

## 👤 Author

Built by [Kaushal Dubey](https://github.com/kaushal123-git)
