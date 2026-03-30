# SJCEM Navigator

A comprehensive Flutter application for **St John College of Engineering and Management (SJCEM)** providing indoor navigation, timetable management, teacher tracking, study materials, and academic communication tools.

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Tech Stack](#tech-stack)
4. [Project Structure](#project-structure)
5. [Data Models](#data-models)
6. [Screens & Navigation](#screens--navigation)
7. [Backend & Database](#backend--database)
8. [How to Run](#how-to-run)
9. [Configuration](#configuration)
10. [Performance Optimizations](#performance-optimizations)
11. [Offline Capabilities](#offline-capabilities)
12. [Security](#security)
13. [Admin Panel](#admin-panel)
14. [Troubleshooting](#troubleshooting)

---

## Overview

SJCEM Navigator is a production-ready Flutter application designed to help students and teachers navigate the college campus, manage timetables, share study materials, and communicate effectively. The app features a modern dark-themed UI with glassmorphic elements, smooth animations, and offline-first architecture.

### Target Users

- **Students** - Navigate rooms, view timetables, find teachers, chat with classmates, access study materials, vote in polls
- **Teachers** - Manage timetable, update location, share materials, communicate with students
- **Administrators** - Full access to manage all data via Admin Panel

---

## Features

### 1. Indoor Navigation

- Interactive floor-wise maps with zoom/pan
- Step-by-step navigation with real-time position tracking
- Kalman filter for accurate position smoothing
- Vibration feedback at waypoints
- Compass integration for direction
- Offline map caching

### 2. Teacher Location Tracking

- Real-time teacher location on map
- Auto-location updates based on timetable
- Global sync across all users
- Offline support with last known locations

### 3. Timetable Management

- Daily/weekly timetable view
- Student-specific (by branch, semester, batch)
- Teacher-specific timetable
- Automatic lecture notifications
- Offline caching

### 4. Study Materials

- Folder-based organization
- File upload/download (PDFs, images, documents)
- Branch and semester categorization
- Supabase Storage integration

### 5. Communication

- **Branch Chat** - Anonymous chat within departments
- **Private Chat** - Direct messaging between users
- Real-time message updates via Supabase Realtime
- Message history with pagination

### 6. Polls & Announcements

- Create and participate in polls
- Multiple choice questions
- Real-time vote counting
- Announcements from admin

### 7. User Management

- Login/Register with authentication
- Profile management
- Password change
- Role-based access (Student, Teacher, HOD, Admin)

---

## Tech Stack

### Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| Flutter | 3.0+ | UI Framework |
| Provider | 6.1.1 | State Management |
| Supabase Flutter | 2.3.0 | Backend & Realtime |
| Firebase Core/Messaging | 2.24.2/14.7.10 | Push Notifications |
| Flutter Local Notifications | 17.2.2 | In-app Notifications |

### Hardware/Sensors

| Package | Purpose |
|---------|---------|
| sensors_plus | Accelerometer for step detection |
| pedometer | Step counting |
| flutter_compass | Direction/heading |

### Utilities

| Package | Purpose |
|---------|---------|
| shared_preferences | Local key-value storage |
| flutter_dotenv | Environment variables |
| dio | HTTP client |
| permission_handler | Runtime permissions |
| file_picker | File selection |
| uuid | Unique ID generation |

---

## Project Structure

```
lib/
├── main.dart                     # App entry point, initialization
├── models/                       # Data models
│   ├── models.dart              # Barrel export file
│   ├── student.dart             # Student entity
│   ├── teacher.dart             # Teacher entity
│   ├── room.dart                # Room/location entity
│   ├── subject.dart             # Subject entity
│   ├── timetable_entry.dart     # Timetable slot
│   ├── chat_message.dart        # Branch chat message
│   ├── private_message.dart     # Private DM
│   ├── poll.dart                # Poll entity
│   ├── announcement.dart        # Announcements
│   ├── navigation_waypoint.dart # Navigation points
│   ├── study_folder.dart        # Study folder
│   ├── study_file.dart          # Study file
│   └── branch.dart              # Department/branch
│
├── providers/                    # State management
│   ├── auth_provider.dart        # Authentication state
│   ├── navigation_provider.dart # Navigation state
│   ├── timetable_provider.dart  # Timetable data
│   ├── chat_provider.dart        # Chat messages
│   ├── poll_provider.dart       # Polls & votes
│   ├── teacher_location_provider.dart # Teacher tracking
│   └── study_materials_provider.dart  # Study materials
│
├── screens/                      # UI screens
│   ├── splash_screen.dart       # Splash/loading screen
│   ├── home/                     # Home container
│   │   └── home_screen.dart     # Main navigation shell
│   ├── auth/                     # Authentication
│   │   ├── login_screen.dart    # User login
│   │   └── register_screen.dart # User registration
│   ├── navigation/               # Indoor navigation
│   │   ├── navigation_screen.dart
│   │   ├── room_mapping_dialog.dart
│   │   └── waypoint_mapping_dialog.dart
│   ├── timetable/               # Timetable
│   │   └── timetable_screen.dart
│   ├── teacher/                 # Teacher features
│   │   └── teacher_location_screen.dart
│   ├── chat/                    # Messaging
│   │   ├── branch_chat_screen.dart
│   │   ├── private_chat_screen.dart
│   │   └── private_chat_list_screen.dart
│   ├── polls/                   # Polls
│   │   ├── polls_screen.dart
│   │   └── create_poll_screen.dart
│   └── study_materials/         # Materials
│       ├── study_materials_screen.dart
│       ├── create_folder_dialog.dart
│       └── upload_file_dialog.dart
│
├── services/                     # Business logic
│   ├── supabase_service.dart     # Supabase client
│   ├── notification_service.dart # Push notifications
│   └── offline_cache_service.dart # Offline data
│
└── utils/                        # Utilities
    ├── constants.dart            # App constants
    ├── app_theme.dart            # Theme & colors
    ├── animations.dart           # Animation configs
    ├── error_handler.dart        # Error handling
    ├── performance.dart          # Performance monitoring
    ├── kalman_filter.dart        # Position smoothing
    └── hash_utils.dart           # Hashing utilities
```

### Key Files Explained

| File | Purpose |
|------|---------|
| `main.dart` | App initialization, Firebase/Supabase setup, Provider setup |
| `home_screen.dart` | Main app shell with bottom navigation, dynamic tabs based on user role |
| `auth_provider.dart` | Handles login, logout, registration, profile updates |
| `navigation_provider.dart` | Manages step detection, compass, position tracking |
| `offline_cache_service.dart` | SQLite-based offline data caching |
| `supabase_service.dart` | Database queries, real-time subscriptions |
| `app_theme.dart` | Dark theme with glassmorphic effects, gradients |

---

## Data Models

### Core Entities

```dart
// Student
- id (UUID)
- name
- email
- phone
- branchId (FK)
- semester
- batch
- rollNumber
- anonymousId (for chat)
- passwordHash

// Teacher  
- id (UUID)
- name
- email
- phone
- subjectIds (List)
- isHod
- isAdmin

// Room
- id (UUID)
- name
- floor
- x, y (map coordinates)
- type (classroom, lab, staffroom, etc.)

// Branch
- id (UUID)
- name (e.g., "Computer Science")
- code (e.g., "CS")

// Subject
- id (UUID
- name
- code

// TimetableEntry
- id (UUID)
- branchId
- semester
- batch
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
