import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Role-based feature flags for safe demo and production toggling
class FeatureFlagsProvider extends ChangeNotifier {
  static const String _flagsPrefix = 'feature_flag_';
  
  // Feature definitions with default values
  final Map<String, FeatureFlag> _flags = {
    'announcements': FeatureFlag(
      key: 'announcements',
      name: 'Announcements Tab',
      description: 'Show announcements from admins and teachers',
      defaultEnabled: true,
      requiredRoles: ['student', 'teacher', 'admin', 'hod'],
    ),
    'indoor_navigation': FeatureFlag(
      key: 'indoor_navigation',
      name: 'Indoor Navigation',
      description: 'Multi-stop waypoint navigation with floor transitions',
      defaultEnabled: true,
      requiredRoles: ['student', 'teacher'],
    ),
    'chat_threads': FeatureFlag(
      key: 'chat_threads',
      name: 'Chat Threads',
      description: 'Threaded replies and conversations',
      defaultEnabled: true,
      requiredRoles: ['student', 'teacher'],
    ),
    'study_materials_search': FeatureFlag(
      key: 'study_materials_search',
      name: 'Study Materials Search',
      description: 'Global search across folders and files',
      defaultEnabled: true,
      requiredRoles: ['student', 'teacher'],
    ),
    'polls_advanced': FeatureFlag(
      key: 'polls_advanced',
      name: 'Advanced Polls',
      description: 'Polls with scheduling and audience segmentation',
      defaultEnabled: true,
      requiredRoles: ['student', 'teacher', 'admin', 'hod'],
    ),
    'offline_sync': FeatureFlag(
      key: 'offline_sync',
      name: 'Offline Action Queue',
      description: 'Queue actions while offline and sync automatically',
      defaultEnabled: true,
      requiredRoles: ['student', 'teacher'],
    ),
    'digital_twin': FeatureFlag(
      key: 'digital_twin',
      name: 'Campus Digital Twin',
      description: 'Live campus map with occupancy and hotspots',
      defaultEnabled: false, // Demo only initially
      requiredRoles: ['student'],
    ),
    'academic_widgets': FeatureFlag(
      key: 'academic_widgets',
      name: 'Academic Widgets',
      description: 'Home widgets for upcoming classes and assignments',
      defaultEnabled: true,
      requiredRoles: ['student', 'teacher'],
    ),
    'observability': FeatureFlag(
      key: 'observability',
      name: 'Diagnostics Page',
      description: 'In-app diagnostics and performance monitoring',
      defaultEnabled: false, // Admin/Judges only
      requiredRoles: ['admin', 'hod'],
    ),
  };
  
  final Map<String, bool> _enabledFlags = {};
  SharedPreferences? _prefs;
  String _currentUserRole = 'student';
  
  String get currentUserRole => _currentUserRole;
  
  /// Initialize feature flags and load from storage
  Future<void> init({required String userRole}) async {
    _prefs = await SharedPreferences.getInstance();
    _currentUserRole = userRole;
    await _loadFlags();
    notifyListeners();
  }
  
  /// Load flags from persistent storage
  Future<void> _loadFlags() async {
    for (final flag in _flags.values) {
      final storageKey = '$_flagsPrefix${flag.key}';
      final stored = _prefs?.getBool(storageKey);
      _enabledFlags[flag.key] = stored ?? flag.defaultEnabled;
    }
  }
  
  /// Check if a feature is enabled for current user
  bool isEnabled(String featureKey) {
    final flag = _flags[featureKey];
    if (flag == null) {
      debugPrint('⚠️ Unknown feature flag: $featureKey');
      return false;
    }
    
    // Check role permission
    if (!flag.requiredRoles.contains(_currentUserRole)) {
      return false;
    }
    
    return _enabledFlags[featureKey] ?? flag.defaultEnabled;
  }
  
  /// Toggle a feature flag (admin/debug only)
  Future<void> toggle(String featureKey) async {
    if (!_flags.containsKey(featureKey)) {
      throw Exception('Unknown feature flag: $featureKey');
    }
    
    final newState = !(_enabledFlags[featureKey] ?? _flags[featureKey]!.defaultEnabled);
    _enabledFlags[featureKey] = newState;
    
    // Persist to storage
    final storageKey = '$_flagsPrefix$featureKey';
    await _prefs?.setBool(storageKey, newState);
    
    debugPrint('🚩 Feature flag "$featureKey" toggled to: $newState');
    notifyListeners();
  }
  
  /// Reset all flags to defaults
  Future<void> resetAll() async {
    _enabledFlags.clear();
    await _loadFlags();
    debugPrint('🔄 All feature flags reset to defaults');
    notifyListeners();
  }
  
  /// Get all available flags
  Map<String, FeatureFlag> getAllFlags() => Map.unmodifiable(_flags);
  
  /// Get flags status (useful for debugging)
  Map<String, bool> getFlagStatus() => Map.unmodifiable(_enabledFlags);
  
  /// Sync flags from backend (for future cloud control)
  Future<void> syncFromBackend(Map<String, bool> backendFlags) async {
    _enabledFlags.addAll(backendFlags);
    for (final entry in backendFlags.entries) {
      await _prefs?.setBool('$_flagsPrefix${entry.key}', entry.value);
    }
    debugPrint('☁️ Synced feature flags from backend');
    notifyListeners();
  }
}

/// Feature flag definition
class FeatureFlag {
  final String key;
  final String name;
  final String description;
  final bool defaultEnabled;
  final List<String> requiredRoles; // student, teacher, admin, hod
  
  FeatureFlag({
    required this.key,
    required this.name,
    required this.description,
    required this.defaultEnabled,
    required this.requiredRoles,
  });
}
