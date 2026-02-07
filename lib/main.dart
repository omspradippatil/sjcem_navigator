import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/auth_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/timetable_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/poll_provider.dart';
import 'providers/teacher_location_provider.dart';
import 'providers/study_materials_provider.dart';
import 'screens/splash_screen.dart';
import 'services/offline_cache_service.dart';
import 'utils/constants.dart';
import 'utils/app_theme.dart';
import 'utils/performance.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize performance detection early
  PerformanceConfig.instance;

  // Enable high refresh rate rendering (120fps where supported)
  // This makes animations buttery smooth on modern devices
  WidgetsBinding.instance.platformDispatcher.onBeginFrame;

  // Optimize for animations - disable debug rendering
  debugDisableShadows = false;
  debugRepaintRainbowEnabled = false;

  // Set system UI overlay style for premium look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.primaryDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Enable edge-to-edge display
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Prefer high refresh rates on supported devices
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize offline cache service
  await OfflineCacheService.init();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const SJCEMNavigatorApp());
}

class SJCEMNavigatorApp extends StatelessWidget {
  const SJCEMNavigatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => TimetableProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => PollProvider()),
        ChangeNotifierProvider(create: (_) => TeacherLocationProvider()),
        ChangeNotifierProvider(create: (_) => StudyMaterialsProvider()),
      ],
      child: MaterialApp(
        title: 'SJCEM Navigator',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Default to dark for premium look
        // Enable smooth scrolling behavior
        scrollBehavior: const _SmoothScrollBehavior(),
        home: const SplashScreen(),
      ),
    );
  }
}

/// Custom scroll behavior for buttery smooth scrolling
class _SmoothScrollBehavior extends ScrollBehavior {
  const _SmoothScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // Use iOS-style bouncing physics for premium feel
    return const BouncingScrollPhysics(
      decelerationRate: ScrollDecelerationRate.fast,
    );
  }

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Use stretch effect instead of glow for modern feel
    return StretchingOverscrollIndicator(
      axisDirection: details.direction,
      child: child,
    );
  }
}
