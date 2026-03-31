# SJCEM Navigator

SJCEM Navigator is a Flutter campus app for navigation, timetable, teacher location, chat, polls, notices, and study materials.

## Core Capabilities

- Indoor navigation with waypoint routing
- Stair-based multi-floor transition flow
- Optional auto turn guidance (toggle on/off in app)
- Timetable for students and teachers
- Teacher location visibility
- Branch and private chat
- Polls and notice board
- Study materials with uploads and folders
- Offline cache and queued sync actions

## Navigation Highlights

- Cross-floor navigation prefers staircase paths
- Near-stair prompt asks user to select destination floor
- Reached button confirms floor arrival and recalibrates heading
- Turn guidance can be enabled or disabled from the navigation controls

For full navigation details, see [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md).

## Tech Stack

- Flutter + Provider
- Supabase (database, auth, realtime, storage)
- Firebase messaging + local notifications
- Sensors (`sensors_plus`, pedometer/heading integrations)

## Project Structure

```text
lib/
    main.dart
    models/
    providers/
    screens/
    services/
    utils/
database/
Admin-Panel/
```

## Getting Started

### Prerequisites

- Flutter SDK (stable)
- Android Studio / Xcode (platform-specific)
- Supabase project

### Setup

1. Install dependencies:

```bash
flutter pub get
```

2. Configure environment values (Supabase/Firebase as used in this project).

3. Run the app:

```bash
flutter run
```

## Useful Commands

```bash
flutter analyze
flutter test
flutter run
```

## Documentation

- [ARCHITECTURE_OVERVIEW.md](ARCHITECTURE_OVERVIEW.md)
- [NAVIGATION_SYSTEM.md](NAVIGATION_SYSTEM.md)
- [CONTRIBUTING.md](CONTRIBUTING.md)
- [Admin-Panel/README.md](Admin-Panel/README.md)

## Admin Panel

The standalone web admin panel is located in [Admin-Panel](Admin-Panel) and documented in [Admin-Panel/README.md](Admin-Panel/README.md).

## License

Internal/academic project usage unless specified otherwise by project owners.
- subjectId
- teacherId
- roomId
- dayOfWeek
- startTime
- endTime
```

---

## Screens & Navigation

### Authentication Flow

```
SplashScreen → LoginScreen / RegisterScreen
                    ↓
              HomeScreen (authenticated)
```

### Home Screen Tabs (Dynamic by Role)

| Tab | Student | Teacher | Guest |
|-----|---------|---------|-------|
| Navigate | ✓ | ✓ | ✓ |
| Info | ✓ (replaced) | ✓ (replaced) | ✓ |
| Timetable | ✓ | ✓ | ✗ |
| Teachers | ✓ | ✓ | ✗ |
| Chat | ✓ | ✓ | ✗ |
| Polls | ✓ | ✓ | ✗ |
| Notes | ✓ | ✓ | ✗ |

### Navigation Flow

```
HomeScreen
├── NavigationScreen
│   ├── Floor selector
│   ├── Room picker
│   └── Map with waypoints
├── TimetableScreen
│   ├── Day view
│   └── Week view
├── TeacherLocationScreen
│   └── Map with teacher markers
├── BranchChatScreen
│   └── Anonymous messages
├── PollsScreen
│   ├── Active polls
│   └── Create poll (teacher/admin)
└── StudyMaterialsScreen
    ├── Folder tree
    └── File list
```

---

## Backend & Database

### Supabase Setup

The app uses Supabase (PostgreSQL) as the backend with:

1. **Authentication** - Email/password via Supabase Auth
2. **Database** - PostgreSQL with RLS (Row Level Security)
3. **Realtime** - Live subscriptions for chat, polls, teacher locations
4. **Storage** - File uploads for study materials
5. **Edge Functions** - (Optional) Server-side logic

### Database Schema

Key tables (see `database/schema.sql`):

- `students` - Student profiles
- `teachers` - Teacher profiles  
- `branches` - Departments
- `subjects` - Subjects
- `rooms` - College rooms with coordinates
- `timetable` - Weekly schedule
- `branch_chat` - Anonymous branch messages
- `private_messages` - Direct messages
- `polls` - Poll definitions
- `poll_options` - Poll choices
- `poll_votes` - User votes
- `announcements` - Admin announcements
- `navigation_waypoints` - Map waypoints
- `study_folders` - Folder hierarchy
- `study_files` - File metadata

---

## How to Run

### Prerequisites

1. **Flutter SDK** (3.0.0+)
   ```bash
   # Windows
   choco install flutter
   
   # macOS
   brew install flutter
   
   # Linux
   sudo snap install flutter
   ```

2. **Android Studio** or **VS Code** with Flutter extension

3. **Supabase Account** - https://supabase.com

4. **Firebase Project** (for push notifications)

### Setup Steps

#### 1. Clone & Install Dependencies

```bash
git clone <repo-url>
cd sjcem_navigator
flutter pub get
```

#### 2. Configure Environment

Create `.env` file in project root:

```env
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key
ADMIN_PASSWORD=your_admin_password
```

#### 3. Setup Supabase

1. Create new Supabase project
2. Run `database/schema.sql` in SQL Editor
3. Get URL and anon key from Settings → API
4. Update `.env`

#### 4. Setup Firebase (Optional - for push notifications)

1. Create Firebase project
2. Download `google-services.json` (Android) / `GoogleService-Info.plist` (iOS)
3. Add to respective platform folders

#### 5. Run the App

```bash
# Development
flutter run

# Specific device
flutter run -d chrome
flutter run -d windows
flutter run -d <android-device-id>
```

#### 6. Build Release

```bash
# Android APK
flutter build apk --release

# Web
flutter build web

# Windows
flutter build windows
```

---

## Configuration

### Constants (lib/utils/constants.dart)

| Constant | Description | Default |
|----------|-------------|---------|
| `mapWidth` | Floor map width in pixels | 1007.0 |
| `mapHeight` | Floor map height in pixels | 989.0 |
| `stepLengthPixels` | Step detection sensitivity | 8.97 |
| `processNoise` | Kalman filter noise | 0.01 |
| `measurementNoise` | Kalman filter noise | 0.1 |

### Theme Configuration

Default theme is **dark mode** with:
- Primary: Deep purple (#1a1a2e)
- Accent: Cyan (#00d9ff)
- Glassmorphic effects with blur

---

## Performance Optimizations

### Implemented Features

1. **RepaintBoundary** - Reduces unnecessary repaints
2. **IndexedStack** - Maintains state without rebuilding
3. **Lazy Loading** - Chat messages loaded on demand
4. **Image Caching** - Floor maps cached locally
5. **Background Sync** - Non-blocking data sync
6. **Release Mode Optimizations** - Debug prints disabled

### Kalman Filter

Position smoothing algorithm for accurate navigation:

```
processNoise = 0.01    // Prediction uncertainty
measurementNoise = 0.1 // Sensor noise
```

---

## Offline Capabilities

### OfflineCacheService

- SQLite-based local database
- Syncs navigation waypoints on startup
- Caches timetable data
- Stores teacher locations
- Works seamlessly with offline indicator

### Offline Mode Indicators

- Cloud icon in app bar when offline
- Graceful degradation of features
- Data persists across sessions

---

## Security

### Implemented Measures

1. **Password Hashing** - SHA-256 with salt
2. **Environment Variables** - Credentials in `.env`
3. **Row Level Security** - Supabase RLS policies
4. **Anonymous IDs** - Chat uses hashed IDs, not real names

### Best Practices

- Never commit `.env` to git
- Use Supabase anon key (not service role)
- Validate all inputs
- Implement rate limiting (Supabase)

---

## Admin Panel

### Web-Based Dashboard

Located in `Admin-Panel/`:

| File | Purpose |
|------|---------|
| `index.html` | Main dashboard UI |
| `styles.css` | Dashboard styling |
| `app.js` | Supabase integration |
| `.env.example` | Environment template |

### Admin Features

- Manage rooms (add/edit coordinates)
- Manage teachers
- Manage students
- View/edit timetable
- View polls and results

### Access

```
URL: Admin-Panel/index.html
Password: Configured in .env (ADMIN_PASSWORD)
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Flutter not found | Add Flutter to PATH |
| Android SDK missing | Run `flutter doctor --android-licenses` |
| Build fails | Run `flutter clean && flutter pub get` |
| Supabase connection error | Check URL and anon key |
| Location not updating | Check permissions |
| Notifications not working | Setup Firebase |

### Debug Commands

```bash
# Clean build
flutter clean

# Check dependencies
flutter pub deps

# Analyze code
flutter analyze

# Run tests
flutter test
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | Initial | Basic navigation |
| 2.0.0 | Added | Chat, polls, materials |
| 3.0.0 | Major | Dark theme, realtime, offline |

---

## License

This project is developed for **St John College of Engineering and Management** for educational purposes.

---

## Contact

- **Developer**: Om Spradip Patil
- **Email**: omspradippatil@gmail.com
- **College**: SJCEM (St John College of Engineering and Management)

---

## Acknowledgments

- Supabase for backend infrastructure
- Flutter team for the framework
- Open source packages used in this project
