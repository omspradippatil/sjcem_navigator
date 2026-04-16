# Claude Code Structure Guide

This file explains what each major part of this repository does, so an AI coding agent (like Claude Code) can quickly navigate the codebase.

## Repository Purpose

SJCEM Navigator is a multi-part project:

1. Flutter app for students and teachers (`lib/`)
2. Browser-based Admin Panel (`Admin-Panel/`)
3. Supabase SQL schema and admin SQL scripts (`database/`)

## Quick Entry Points

- Mobile app entry: `lib/main.dart`
- Admin panel entry: `Admin-Panel/index.html` + `Admin-Panel/app.js`
- Main DB schema: `database/schema.sql`
- Admin panel user/auth SQL: `database/admin_panel_users.sql`
- Project dependency/config root: `pubspec.yaml`

## Top-Level Folder Map

- `lib/`: Main Flutter application source
- `Admin-Panel/`: Standalone HTML/CSS/JS admin dashboard
- `database/`: SQL schema, admin users, and activity-log setup
- `assets/`: Map images and app icons used by the Flutter app
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: Flutter platform runners/build targets
- `test/`: Flutter tests
- `tool/`: Utility scripts (example: icon generation)
- `build/`: Generated build outputs (do not hand-edit)

## Root Files

- `README.md`: Full app overview, features, setup, and architecture notes
- `.env.example`: Template for app runtime environment values
- `pubspec.yaml`: Flutter dependencies, assets, splash/icon generators
- `analysis_options.yaml`: Dart analyzer and lint settings
- `timetable.json`: Timetable data file (JSON content, UTF-16 encoded)
- `flutter_analyze_machine.txt`: Analyzer output snapshot/log

## Flutter App (`lib/`)

### Boot and Global Setup

- `lib/main.dart`
  - Initializes Flutter bindings, orientation, UI behavior
  - Initializes offline cache, dotenv, Supabase, and Firebase
  - Registers Provider state containers
  - Starts at `SplashScreen`

### Data Models (`lib/models/`)

Domain entities used across providers/services/screens.

- `models.dart`: Barrel export for model imports
- `student.dart`, `teacher.dart`, `branch.dart`: Core identity and organizational entities
- `room.dart`, `navigation_waypoint.dart`: Indoor navigation entities
- `subject.dart`, `timetable_entry.dart`: Academic timetable entities
- `chat_message.dart`, `private_message.dart`: Messaging entities
- `poll.dart`, `announcement.dart`: Poll and announcement entities
- `study_folder.dart`, `study_file.dart`: Study material entities

### State Providers (`lib/providers/`)

`ChangeNotifier` state containers wired in `main.dart`.

- `auth_provider.dart`: Login/register/session and user identity state
- `navigation_provider.dart`: Navigation tracking, map route/position state
- `timetable_provider.dart`: Timetable loading/filtering/caching state
- `chat_provider.dart`: Branch and private chat state
- `poll_provider.dart`: Poll loading, voting, result state
- `teacher_location_provider.dart`: Teacher location visibility/update state
- `study_materials_provider.dart`: Study folder/file listing and actions

### Screens (`lib/screens/`)

UI layer grouped by feature.

- `splash_screen.dart`: Startup screen and app readiness flow
- `auth/`
  - `login_screen.dart`: Sign-in flow
  - `register_screen.dart`: Registration flow
- `home/`
  - `home_screen.dart`: Main shell/navigation for feature tabs
- `navigation/`
  - `navigation_screen.dart`: Floor map navigation UI
  - `room_mapping_dialog.dart`: Room mapping dialog/editor
  - `waypoint_mapping_dialog.dart`: Waypoint mapping dialog/editor
- `timetable/`
  - `timetable_screen.dart`: Timetable UI and interactions
- `teacher/`
  - `teacher_location_screen.dart`: Teacher location display/update UI
- `chat/`
  - `branch_chat_screen.dart`: Anonymous/branch chat interface
  - `private_chat_list_screen.dart`: Direct message thread list
  - `private_chat_screen.dart`: Direct message conversation screen
- `polls/`
  - `polls_screen.dart`: Poll list and voting screen
  - `create_poll_screen.dart`: Poll creation flow
- `study_materials/`
  - `study_materials_screen.dart`: Folder/file browsing UI
  - `create_folder_dialog.dart`: Create folder dialog
  - `upload_file_dialog.dart`: Upload file dialog
- `admin/`
  - Currently empty placeholder folder in this workspace state

### Services (`lib/services/`)

Backend access and cross-feature platform services.

- `supabase_service.dart`: Supabase CRUD/query layer for app modules
- `offline_cache_service.dart`: SharedPreferences-based offline caching/sync helpers
- `notification_service.dart`: Local notifications + Supabase realtime listeners

### Utilities (`lib/utils/`)

- `constants.dart`: Environment-backed constants and app constants
- `app_theme.dart`: Theme and color definitions
- `animations.dart`: Shared animation presets/helpers
- `error_handler.dart`: Error parsing and user-friendly handling
- `performance.dart`: Performance monitoring/config
- `kalman_filter.dart`: Sensor/navigation smoothing logic
- `hash_utils.dart`: Hashing helpers (password/ID workflows)

### Reusable Widgets (`lib/widgets/`)

- `app_tour.dart`: App tour/onboarding style reusable widget logic

## Admin Panel (`Admin-Panel/`)

Standalone web app (not Flutter) for operational data management.

### Main Files

- `Admin-Panel/index.html`: Dashboard layout and module containers
- `Admin-Panel/styles.css`: Panel styling/theme
- `Admin-Panel/app.js`: Main panel runtime, module config/state, orchestration
- `Admin-Panel/env.js`: Local runtime config (ignored from git)
- `Admin-Panel/env.js.example`: Template for `env.js`
- `Admin-Panel/.env` and `.env.example`: Optional env source for tooling/fallback
- `Admin-Panel/generate-env.js`: Build/deploy helper to generate `env.js`
- `Admin-Panel/netlify.toml`: Netlify deployment settings
- `Admin-Panel/package.json`: Panel build/tooling scripts
- `Admin-Panel/README.md`: Admin panel setup, deploy, and usage notes

### Admin Script Modules (`Admin-Panel/scripts/`)

- `core-env.js`: Reads/deobfuscates runtime env and initializes Supabase client
- `auth-session.js`: Login/logout/session lock and user scope behavior
- `dashboard.js`: Dashboard cards/charts/system health rendering
- `data-access.js`: Data queries, scoping, and option loading helpers
- `editor-crud.js`: Dynamic create/edit form rendering and CRUD submit flow
- `ui-controller.js`: Toolbar/table rendering, module switching, UI state sync
- `realtime-notifications.js`: Realtime sync queue and health indicators
- `backup-manager.js`: JSON/CSV backup, restore, and backup scheduling
- `ocr-import.js`: OCR/timetable text parsing and subject/timetable import helpers

## Database (`database/`)

- `database/schema.sql`
  - Core app schema (students, teachers, rooms, subjects, timetable, chat, polls, etc.)
  - Includes indexes and compatibility migrations/guards
- `database/admin_panel_users.sql`
  - Admin panel user table and RLS policies
  - Admin activity log table and policies

## Assets (`assets/`)

- `assets/maps/Floor0.png` to `assets/maps/Floor4.png`: Indoor map images used in navigation UI
- `assets/icons/app_icon.png`: Primary app icon
- `assets/icons/app_icon_foreground.png`: Adaptive icon foreground
- `assets/icons/splash_logo.png`: Splash branding image

## Tests and Tools

- `test/widget_test.dart`: Basic Flutter widget test scaffold
- `tool/generate_icons.dart`: Utility script to generate placeholder icons/splash assets

## Platform Runners

Standard Flutter platform folders:

- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`

Treat these mostly as platform host/build configuration unless implementing platform-specific behavior.

## Generated or Machine Output (Usually Do Not Edit)

- `build/`
- `.dart_tool/`
- `android/build/`
- Other generated subfolders under build artifacts

## Safe Change Navigation Hints

Use this quick mapping when deciding where to edit:

1. Feature UI changes: `lib/screens/...`
2. App state/business flow: `lib/providers/...`
3. Backend and data operations: `lib/services/supabase_service.dart`
4. Offline behavior: `lib/services/offline_cache_service.dart`
5. Notification behavior: `lib/services/notification_service.dart`
6. Admin dashboard behavior: `Admin-Panel/app.js` + `Admin-Panel/scripts/...`
7. Schema or access/policy changes: `database/schema.sql` and/or `database/admin_panel_users.sql`
