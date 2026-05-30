# SJCEM Navigator

A comprehensive Flutter application for **St John College of Engineering and Management (SJCEM)** providing indoor navigation, timetable management, teacher tracking, study materials, and academic communication tools.

---

## Table of Contents

1. [Overview](#overview)
2. [Complete Deep Dive Documentation](#complete-deep-dive-documentation)
3. [Features](#features)
4. [Tech Stack](#tech-stack)
5. [Project Structure](#project-structure)
6. [Data Models](#data-models)
7. [Screens & Navigation](#screens--navigation)
8. [Backend & Database](#backend--database)
9. [How to Run](#how-to-run)
10. [Configuration](#configuration)
11. [Performance Optimizations](#performance-optimizations)
12. [Offline Capabilities](#offline-capabilities)
13. [Security](#security)
14. [Admin Panel](#admin-panel)
15. [Troubleshooting](#troubleshooting)

---

## Overview

SJCEM Navigator is a production-ready Flutter application designed to help students and teachers navigate the college campus, manage timetables, share study materials, and communicate effectively. The app features a modern dark-themed UI with glassmorphic elements, smooth animations, and offline-first architecture.

### Target Users

- **Students** - Navigate rooms, view timetables, find teachers, chat with classmates, access study materials, vote in polls
- **Teachers** - Manage timetable, update location, share materials, communicate with students
- **Administrators** - Full access to manage all data via Admin Panel

---

## Complete Deep Dive Documentation

For complete architecture and file-by-file documentation of the Flutter app, Admin Panel, database, working algorithms, internal flows, and Mermaid diagrams, see:

- [FULL_APP_DEEP_DIVE.md](FULL_APP_DEEP_DIVE.md)

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
â”œâ”€â”€ main.dart                     # App entry point, initialization
â”œâ”€â”€ models/                       # Data models
â”‚   â”œâ”€â”€ models.dart              # Barrel export file
â”‚   â”œâ”€â”€ student.dart             # Student entity
â”‚   â”œâ”€â”€ teacher.dart             # Teacher entity
â”‚   â”œâ”€â”€ room.dart                # Room/location entity
â”‚   â”œâ”€â”€ subject.dart             # Subject entity
â”‚   â”œâ”€â”€ timetable_entry.dart     # Timetable slot
â”‚   â”œâ”€â”€ chat_message.dart        # Branch chat message
â”‚   â”œâ”€â”€ private_message.dart     # Private DM
â”‚   â”œâ”€â”€ poll.dart                # Poll entity
â”‚   â”œâ”€â”€ announcement.dart        # Announcements
â”‚   â”œâ”€â”€ navigation_waypoint.dart # Navigation points
â”‚   â”œâ”€â”€ study_folder.dart        # Study folder
â”‚   â”œâ”€â”€ study_file.dart          # Study file
â”‚   â””â”€â”€ branch.dart              # Department/branch
â”‚
â”œâ”€â”€ providers/                    # State management
â”‚   â”œâ”€â”€ auth_provider.dart        # Authentication state
â”‚   â”œâ”€â”€ navigation_provider.dart # Navigation state
â”‚   â”œâ”€â”€ timetable_provider.dart  # Timetable data
â”‚   â”œâ”€â”€ chat_provider.dart        # Chat messages
â”‚   â”œâ”€â”€ poll_provider.dart       # Polls & votes
â”‚   â”œâ”€â”€ teacher_location_provider.dart # Teacher tracking
â”‚   â””â”€â”€ study_materials_provider.dart  # Study materials
â”‚
â”œâ”€â”€ screens/                      # UI screens
â”‚   â”œâ”€â”€ splash_screen.dart       # Splash/loading screen
â”‚   â”œâ”€â”€ home/                     # Home container
â”‚   â”‚   â””â”€â”€ home_screen.dart     # Main navigation shell
â”‚   â”œâ”€â”€ auth/                     # Authentication
â”‚   â”‚   â”œâ”€â”€ login_screen.dart    # User login
â”‚   â”‚   â””â”€â”€ register_screen.dart # User registration
â”‚   â”œâ”€â”€ navigation/               # Indoor navigation
â”‚   â”‚   â”œâ”€â”€ navigation_screen.dart
â”‚   â”‚   â”œâ”€â”€ room_mapping_dialog.dart
â”‚   â”‚   â””â”€â”€ waypoint_mapping_dialog.dart
â”‚   â”œâ”€â”€ timetable/               # Timetable
â”‚   â”‚   â””â”€â”€ timetable_screen.dart
â”‚   â”œâ”€â”€ teacher/                 # Teacher features
â”‚   â”‚   â””â”€â”€ teacher_location_screen.dart
â”‚   â”œâ”€â”€ chat/                    # Messaging
â”‚   â”‚   â”œâ”€â”€ branch_chat_screen.dart
â”‚   â”‚   â”œâ”€â”€ private_chat_screen.dart
â”‚   â”‚   â””â”€â”€ private_chat_list_screen.dart
â”‚   â”œâ”€â”€ polls/                   # Polls
â”‚   â”‚   â”œâ”€â”€ polls_screen.dart
â”‚   â”‚   â””â”€â”€ create_poll_screen.dart
â”‚   â””â”€â”€ study_materials/         # Materials
â”‚       â”œâ”€â”€ study_materials_screen.dart
â”‚       â”œâ”€â”€ create_folder_dialog.dart
â”‚       â””â”€â”€ upload_file_dialog.dart
â”‚
â”œâ”€â”€ services/                     # Business logic
â”‚   â”œâ”€â”€ supabase_service.dart     # Supabase client
â”‚   â”œâ”€â”€ notification_service.dart # Push notifications
â”‚   â””â”€â”€ offline_cache_service.dart # Offline data
â”‚
â””â”€â”€ utils/                        # Utilities
    â”œâ”€â”€ constants.dart            # App constants
    â”œâ”€â”€ app_theme.dart            # Theme & colors
    â”œâ”€â”€ animations.dart           # Animation configs
    â”œâ”€â”€ error_handler.dart        # Error handling
    â”œâ”€â”€ performance.dart          # Performance monitoring
    â”œâ”€â”€ kalman_filter.dart        # Position smoothing
    â””â”€â”€ hash_utils.dart           # Hashing utilities
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
SplashScreen â†’ LoginScreen / RegisterScreen
                    â†“
              HomeScreen (authenticated)
```

### Home Screen Tabs (Dynamic by Role)

| Tab | Student | Teacher | Guest |
|-----|---------|---------|-------|
| Navigate | âœ“ | âœ“ | âœ“ |
| Info | âœ“ (replaced) | âœ“ (replaced) | âœ“ |
| Timetable | âœ“ | âœ“ | âœ— |
| Teachers | âœ“ | âœ“ | âœ— |
| Chat | âœ“ | âœ“ | âœ— |
| Polls | âœ“ | âœ“ | âœ— |
| Notes | âœ“ | âœ“ | âœ— |

### Navigation Flow

```
HomeScreen
â”œâ”€â”€ NavigationScreen
â”‚   â”œâ”€â”€ Floor selector
â”‚   â”œâ”€â”€ Room picker
â”‚   â””â”€â”€ Map with waypoints
â”œâ”€â”€ TimetableScreen
â”‚   â”œâ”€â”€ Day view
â”‚   â””â”€â”€ Week view
â”œâ”€â”€ TeacherLocationScreen
â”‚   â””â”€â”€ Map with teacher markers
â”œâ”€â”€ BranchChatScreen
â”‚   â””â”€â”€ Anonymous messages
â”œâ”€â”€ PollsScreen
â”‚   â”œâ”€â”€ Active polls
â”‚   â””â”€â”€ Create poll (teacher/admin)
â””â”€â”€ StudyMaterialsScreen
    â”œâ”€â”€ Folder tree
    â””â”€â”€ File list
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
3. Get URL and anon key from Settings â†’ API
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

- **Developer**: Om Pradip Patil
- **Email**: omspradippatil@gmail.com
- **College**: SJCEM (St John College of Engineering and Management)

---

## Acknowledgments

- Supabase for backend infrastructure
- Flutter team for the framework
- Open source packages used in this project

## ☕ Support

If you find this project helpful, consider [supporting me](https://ompradippatil.netlify.app/donate).

