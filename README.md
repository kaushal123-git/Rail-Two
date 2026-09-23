# 🚉 Railway Station Finder

A Flutter mobile app that finds your nearest railway station using GPS location and Google's S2 Geometry system for fast, accurate distance calculations.

## Features

- Detects the user's live GPS location via the `geolocator` package
- Indexes locations using Google's S2 Geometry (`s2geometry` package) for efficient spatial lookups
- Calculates spherical distance to recommend the nearest railway station
- Ships with a default JSON database of major railway stations
- Add your own custom stations, with an auto-fill "Use Current Location" option and a live preview of the calculated S2 Cell ID
- Browse all stations sorted by distance, with search/filter
- Clean, modern dark/indigo UI

## Tech Stack

- **Flutter / Dart**
- `geolocator` — GPS location and permissions
- `s2geometry` — S2 cell indexing and distance calculations
- `path_provider` — local persistence for custom stations

## Project Structure

```
lib/
├── main.dart                  # App entry point and theme
├── models/
│   └── station.dart           # Station data model (id, name, lat/lng, S2 cell token)
├── services/
│   ├── s2_service.dart        # Lat/Lng ↔ S2 cell conversion, distance calculation
│   ├── location_service.dart  # Location permissions and GPS retrieval
│   └── station_storage.dart   # Loads default + custom stations, persists to local storage
└── screens/
    ├── home_screen.dart          # Dashboard: current location, nearest station card
    ├── stations_list_screen.dart # All stations sorted by distance, with search
    └── add_station_screen.dart   # Add a custom station with live S2 preview
assets/
└── default_stations.json      # Pre-populated railway station coordinates
```

## Getting Started

### Prerequisites

- Flutter SDK installed and on your PATH

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

Grant location permissions when prompted so the app can detect your current position and recommend the nearest station.

## Author

Built by [Kaushal Dubey](https://github.com/kaushal123-git)
