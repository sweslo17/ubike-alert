# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ubike Alert is a Flutter mobile application that monitors YouBike 2.0 bike availability in real-time across Taiwan. The app provides background monitoring with push notifications when bike counts change at watched stations, with detailed tracking of both regular bikes (YB2) and electric-assist bikes (EYB).

**Target Platform**: Android and iOS
**Data Source**: Supports all YouBike 2.0 stations across Taiwan via YouBike official API
**Core Functionality**: Real-time station monitoring, background service, local push notifications with YB2/EYB breakdown

## Development Commands

### Environment Setup
```bash
# Check Flutter environment
flutter doctor

# Install dependencies
flutter pub get

# Install iOS dependencies (macOS only)
cd ios && pod install && cd ..
```

### Running the App
```bash
# List available devices
flutter devices

# Run on specific device
flutter run -d <device-id>

# Run with verbose logging
flutter run -v
```

### Building
```bash
# Android APK (debug)
flutter build apk

# Android APK (release)
flutter build apk --release

# Android App Bundle (for Google Play)
flutter build appbundle --release

# iOS (release)
flutter build ios --release
```

### Testing & Debugging
```bash
# View logs
flutter logs

# Android logs (when app is running)
adb logcat | grep flutter

# Clean build artifacts
flutter clean
```

## Architecture

### Service Layer Architecture
The app uses a **three-service architecture** for separation of concerns:

1. **ApiService** (`lib/services/api_service.dart`): Handles all HTTP communication with YouBike official API
   - `fetchStations()`: Fetches station list from `apis.youbike.com.tw/json/station-min-yb2.json` (all Taiwan)
   - `fetchStationDetail()`: POST to `apis.youbike.com.tw/tw2/parkingInfo` for detailed bike availability
   - `fetchMultipleStationDetails()`: Batch query for multiple stations
   - Separates basic station info (list) from detailed availability data (on-demand)

2. **NotificationService** (`lib/services/notification_service.dart`): Manages local push notifications
   - Singleton pattern ensures consistent notification handling
   - `sendBikeCountNotificationWithDetails()`: Shows YB2 and EYB changes separately
   - Configures both iOS (Darwin) and Android notification channels

3. **ForegroundServiceManager** (`lib/services/foreground_service.dart`): Background monitoring via foreground service
   - Uses `flutter_foreground_task` for persistent background execution
   - `UbikeMonitorTaskHandler` runs every 60 seconds to check bike counts
   - Tracks YB2 and EYB counts separately for change detection
   - Stores monitoring state in SharedPreferences

### Data Flow for Background Monitoring
```
User selects station → ForegroundServiceManager.startService(stationNo, stationName, station)
→ SharedPreferences stores station_no and station JSON
→ UbikeMonitorTaskHandler.onRepeatEvent() (every 60s)
→ ApiService.fetchStationDetail(stationNo, baseStation)
→ Compare YB2 and EYB counts with last values
→ NotificationService.sendBikeCountNotificationWithDetails() (if changed and threshold met)
→ FlutterForegroundTask.sendDataToMain() updates UI with YB2/EYB data
```

### Data Flow for UI
```
App Launch → ApiService.fetchStations() → Display station list (no bike counts)
User taps station → Navigate to MonitorScreen
→ ApiService.fetchStationDetail() → Display YB2/EYB counts
User refreshes → ApiService.fetchStationDetail() → Update counts
```

### Key Data Structure
The app uses YouBike official API with two-tier data structure:

**Station List** (basic info):
- `station_no`, `name_tw`, `district_tw`, `address_tw`
- `lat`, `lng`, `status`
- No bike availability data

**Parking Info** (detailed availability):
- `available_spaces_detail`: Contains `yb2` and `eyb` breakdown
- `empty_spaces`: Available return slots
- `parking_spaces`: Total capacity
- Fetched on-demand when user views station details

**BikeAvailability Model**:
- Separates regular YouBike 2.0 (`yb2`) from electric-assist bikes (`eyb`)
- `total` getter provides combined count
- Used in notifications to show individual changes

## Critical Implementation Details

### API Integration Points
- **Station List API**: GET request to `apis.youbike.com.tw/json/station-min-yb2.json`
  - Returns all Taiwan stations (thousands of records)
  - Lightweight response (no availability data)
  - UTF-8 decoding required: `json.decode(utf8.decode(response.bodyBytes))`

- **Parking Info API**: POST request to `apis.youbike.com.tw/tw2/parkingInfo`
  - Request body: `{"station_no": ["500203020"]}`
  - Response wrapper: `retCode`, `retVal` with nested `data` array
  - Must check `retCode == 1` before accessing data
  - Returns `available_spaces_detail` with `yb2` and `eyb` breakdown

- **Error Handling**: All API methods return empty/null on failure (no exceptions thrown)

### Background Service Requirements
- **Android**: Requires `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `WAKE_LOCK` permissions in AndroidManifest.xml
- **Entry Points**: Methods with `@pragma('vm:entry-point')` annotation are called from native code
- **State Persistence**: SharedPreferences stores:
  - `monitoring_station_no`: Currently monitored station number
  - `monitoring_station_json`: Serialized station base info for background service
  - `last_yb2_count`: Previous YB2 count for change detection
  - `last_eyb_count`: Previous EYB count for change detection
  - `threshold`: Minimum total bikes for notifications

### Notification Handling
- **Channel IDs**:
  - `ubike_monitor_service` for foreground service (low priority)
  - `ubike_monitor` for bike count alerts (high priority)
- **iOS**: Requires explicit permission request via `DarwinInitializationSettings`
- **Android 13+**: Requires `POST_NOTIFICATIONS` runtime permission

## Code Conventions

### File Organization
- Models: Pure data classes with `fromJson`/`toJson` serialization
- Services: Singleton pattern for stateful services (NotificationService, ForegroundServiceManager)
- Screens: StatefulWidget for UI with state management

### Logging
- Use `print()` statements for debugging (visible in `flutter logs`)
- Include context in log messages, e.g., "取得站點列表時發生錯誤: $e"
- Background service logs YB2/EYB counts: "目前車輛數: YB2=$yb2, EYB=$eyb, 總計=$total"

### Error Handling
- API failures return empty lists `[]` or `null` rather than throwing
- Null safety: Use null-aware operators and default values
- Station model uses nullable fields for availability data (fetched on-demand)

## Platform-Specific Notes

### Android
- Minimum SDK: API 21 (Android 5.0)
- Core Library Desugaring enabled for Java 8+ features
- Foreground service must show persistent notification

### iOS
- CocoaPods required for dependency management
- Info.plist must declare notification usage
- Background execution limited by iOS app lifecycle policies

## Data Limitations
- **Geographic Scope**: Supports all Taiwan cities with YouBike 2.0 (Taipei, New Taipei, Taoyuan, Taichung, Tainan, Kaohsiung, etc.)
- **YouBike Version**: Only 2.0 stations (excludes 1.0 legacy stations)
- **Update Frequency**:
  - Station list API: Updates approximately every minute
  - Parking info API: Real-time data
- **Network Dependency**: Requires active internet connection for all operations
- **API Availability**: Dependent on YouBike official API service stability

## Station Model Field Names
Note the transition from old to new field naming:
- Old: `sno` → New: `stationNo`
- Old: `sna` → New: `stationName`
- Old: `sarea` → New: `district`
- Old: `ar` → New: `address`
- Old: `availableRentBikes` (total) → New: `availableSpaces` (BikeAvailability with yb2/eyb)
- Old: `availableReturnBikes` → New: `emptySpaces`
- Old: `quantity` → New: `totalSpaces`
