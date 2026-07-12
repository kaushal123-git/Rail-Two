# Implementation Plan - Flutter Railway Station Finder using S2 Geometry

Create a mobile-based Flutter application using Dart that detects the user's GPS location via the `geolocator` package, indexes the location using Google's S2 Geometry system (via the `s2geometry` package), reads railway station locations from a JSON database, and calculates the distance to recommend the nearest station.

## User Review Required

> [!IMPORTANT]
> **Flutter SDK Path Warning**: The `flutter` command is not currently configured in the system PATH. We will create the complete Flutter project structure (including the `lib/` directory, assets, and configurations). Once the files are created:
> 1. You should run `flutter create . --overwrite` in the `c:\Users\Kaushal Dubey\Desktop\Rail Two` folder to generate the platform-specific runners (Android, iOS, etc.) if they aren't already initialized.
> 2. Then run `flutter pub get` to install the dependencies.

## Proposed Changes

We will create a structured Flutter application. The architecture separates concerns into data models, storage services, location services, S2 geometry computations, and clean, beautiful UI screens.

---

### Project Configuration & Dependencies

#### [NEW] [pubspec.yaml](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/pubspec.yaml)
Define dependencies for location tracking, S2 geometry, local storage, and custom assets.
- `geolocator`: For fetching GPS coordinates.
- `s2geometry`: For converting Lat/Lng coordinates into S2 cells and computing distances.
- `path_provider`: For accessing internal storage to persist custom stations.
- `cupertino_icons`: For modern iOS-like icons.

---

### Data Models & Mock Data

#### [NEW] [station.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/models/station.dart)
A data class for a railway station containing:
- `id` (String)
- `name` (String)
- `latitude` (double)
- `longitude` (double)
- `s2CellToken` (String - calculated on creation/load)
- Helper methods for JSON serialization and S2 conversion.

#### [NEW] [default_stations.json](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/assets/default_stations.json)
Pre-populated JSON database of major railway stations with their coordinates (e.g., major hub stations) to provide immediate functionality.

---

### Core Services

#### [NEW] [s2_service.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/services/s2_service.dart)
Helper class encapsulating S2 Geometry logic:
- `latLngToCellToken(double lat, double lng)`: Converts coordinates into an S2 cell token.
- `latLngToCellId(double lat, double lng)`: Returns the numeric 64-bit S2 cell ID.
- `calculateDistance(double lat1, double lng1, double lat2, double lng2)`: Computes spherical distance in meters using `S2LatLng.getDistance(...)` multiplied by Earth's radius.

#### [NEW] [location_service.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/services/location_service.dart)
Manages location permissions and live tracking:
- Checks if location services are enabled.
- Requests permissions (Fine/Coarse location).
- Retrieves current coordinates and returns them as a stream or single future.

#### [NEW] [station_storage.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/services/station_storage.dart)
Handles reading default stations from assets, loading user-defined stations from local storage, and saving/merging them back into a single JSON file.

---

### UI Components & Screens

To deliver a premium visual experience, we'll design a cohesive visual system using custom gradients, smooth cards, modern typography, and clear visual identifiers for S2 cells.

#### [NEW] [main.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/main.dart)
App entry point. Configures a beautiful custom theme (sleek dark/indigo theme, modern typography) and mounts the Home Screen.

#### [NEW] [home_screen.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/screens/home_screen.dart)
The dashboard containing:
- **Location Status**: User's current Lat/Lng and S2 cell ID/token.
- **Nearest Station Recommendation**: A visually stunning gradient card showing the nearest station, its S2 Cell ID, and the exact distance (in km/meters).
- **Navigation Controls**: Quick access to view all stations and add new stations.

#### [NEW] [stations_list_screen.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/screens/stations_list_screen.dart)
Displays the full list of stations, sorted by distance from the user. Shows S2 cell information and coordinates for each station. Includes search filter.

#### [NEW] [add_station_screen.dart](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/lib/screens/add_station_screen.dart)
Allows adding a custom railway station. Features:
- Input fields for name, latitude, longitude.
- A "Use Current Location" autofill button.
- Real-time preview of the calculated S2 Cell Token/ID before saving.

---

### Native Permission Configuration

#### [NEW] [AndroidManifest.xml](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/android/app/src/main/AndroidManifest.xml)
Include permissions for location access:
- `android.permission.ACCESS_FINE_LOCATION`
- `android.permission.ACCESS_COARSE_LOCATION`

#### [NEW] [Info.plist](file:///c:/Users/Kaushal%20Dubey/Desktop/Rail%20Two/ios/Runner/Info.plist)
Include keys for iOS location usage:
- `NSLocationWhenInUseUsageDescription`
- `NSLocationAlwaysUsageDescription`

---

## Verification Plan

### Automated Verification
Since Dart is not in the system path, we will verify the code structure and syntax by:
1. Writing a clean, compilable project structure.
2. Confirming formatting of all `.dart` and `.json` files.
3. Reviewing package versions against compatible releases.

### Manual Verification
Once the files are created, the user can verify by:
1. Running `flutter create .` to initialize platform files.
2. Running the app on a simulator or device (`flutter run`).
3. Approving location permissions.
4. Verifying coordinates and S2 cell updates.
5. Verifying the distance calculations match local geography.
