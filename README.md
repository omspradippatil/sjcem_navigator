# SJCEM Navigator

A comprehensive Flutter application for SJCEM (St John College of Engineering and Management) providing indoor navigation, timetable management, teacher tracking, and academic resources.

## Features

- **Indoor Navigation** - Navigate through college buildings with floor-wise maps
- **Teacher Location Tracking** - Real-time tracking of teacher locations
- **Timetable Management** - View and manage class schedules
- **Study Materials** - Access and share study resources
- **Branch Chat** - Anonymous chat within departments
- **Polls & Announcements** - Create and participate in college polls
- **Web Admin Panel (HTML)** - Manage rooms, teachers, students, and timetables from a standalone HTML dashboard

## Screenshots

*Add screenshots here*

---

## How to Run on Your PC

### Prerequisites

1. **Flutter SDK** (3.0.0 or higher)
   - Download from: https://docs.flutter.dev/get-started/install
   - Add Flutter to your PATH

2. **Android Studio** or **VS Code** with Flutter extension

3. **Git** - https://git-scm.com/downloads

4. **Supabase Account** (for backend) - https://supabase.com

---

### Step 1: Clone the Repository

```bash
git clone https://github.com/your-username/sjcem_navigator.git
cd sjcem_navigator
```

---

### Step 2: Install Dependencies

```bash
flutter pub get
```

---

### Step 3: Setup Supabase Backend

1. Create a new project at [Supabase](https://supabase.com)

2. Go to **SQL Editor** in Supabase dashboard

3. Copy the contents of `database/schema.sql` and run it in the SQL Editor

4. Get your Supabase credentials:
   - Go to **Settings** > **API**
   - Copy the **Project URL** and **anon public key**

5. Update `lib/utils/constants.dart` with your credentials:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_ANON_KEY';
   ```

---

### Step 4: Generate App Icons

```bash
dart run flutter_launcher_icons
```

---

### Step 5: Generate Splash Screen

```bash
dart run flutter_native_splash:create
```

---

### Step 6: Run the App

#### Option A: Android Emulator/Device
```bash
flutter run
```

#### Option B: Chrome (Web)
```bash
flutter run -d chrome
```

#### Option C: Windows Desktop
```bash
flutter run -d windows
```

---

### Step 7: Build Release APK

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

---

## Troubleshooting

### Common Issues

**1. Flutter not found**
```bash
# Add Flutter to PATH (Windows)
setx PATH "%PATH%;C:\flutter\bin"
```

**2. Android SDK not found**
```bash
flutter doctor --android-licenses
```

**3. Gradle build fails**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**4. Pub get failed**
```bash
flutter clean
flutter pub cache repair
flutter pub get
```

---

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── providers/                # State management (Provider)
├── screens/                  # UI screens
│   ├── auth/                # Login/Register screens
│   ├── chat/                # Chat screens
│   ├── home/                # Home & dashboard
│   ├── navigation/          # Indoor navigation
│   ├── study_materials/     # Study resources
│   └── timetable/           # Timetable screens
├── services/                 # API & backend services
└── utils/                    # Utilities & constants

assets/
├── icons/                    # App icons
└── maps/                     # Floor map images

database/
└── schema.sql               # Supabase database schema

Admin-Panel/
├── index.html               # Standalone admin dashboard (HTML only)
├── styles.css               # Dashboard styling
├── app.js                   # Dashboard logic (Supabase + UI)
└── .env.example             # Environment template for admin panel
```

---

## Tech Stack

- **Frontend**: Flutter 3.0+
- **State Management**: Provider
- **Backend**: Supabase (PostgreSQL)
- **Authentication**: Custom (Supabase)
- **Real-time**: Supabase Realtime
- **Storage**: Supabase Storage

---

## Admin Access

Default admin password: `SJCEM`

---

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## License

This project is for educational purposes at SJCEM.

---

## Contact

For queries, contact the development team.
E mail - omspradippatil@gmail.com
