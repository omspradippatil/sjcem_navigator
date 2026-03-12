import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../services/offline_cache_service.dart';
import '../utils/constants.dart';

class AuthProvider extends ChangeNotifier {
  Student? _currentStudent;
  Teacher? _currentTeacher;
  String _userType = AppConstants.userTypeGuest;
  bool _isLoading = false;
  String? _error;
  List<Branch> _branches = [];
  bool _isInitialized = false;
  final _initializationCompleter = Completer<void>();
  final _notificationService = NotificationService();

  Student? get currentStudent => _currentStudent;
  Teacher? get currentTeacher => _currentTeacher;
  String get userType => _userType;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Branch> get branches => _branches;
  bool get isInitialized => _isInitialized;

  bool get isLoggedIn => _currentStudent != null || _currentTeacher != null;
  bool get isStudent => _userType == AppConstants.userTypeStudent;
  bool get isTeacher => _userType == AppConstants.userTypeTeacher;
  bool get isGuest => _userType == AppConstants.userTypeGuest;
  bool get isAdmin => _currentTeacher?.isAdmin ?? false;
  bool get isHod => _currentTeacher?.isHod ?? false;

  String? get currentUserId {
    if (_currentStudent != null) return _currentStudent!.id;
    if (_currentTeacher != null) return _currentTeacher!.id;
    return null;
  }

  String? get currentBranchId {
    if (_currentStudent != null) return _currentStudent!.branchId;
    if (_currentTeacher != null) return _currentTeacher!.branchId;
    return null;
  }

  String get currentUserName {
    if (_currentStudent != null) return _currentStudent!.name;
    if (_currentTeacher != null) return _currentTeacher!.name;
    return 'Guest';
  }

  String get anonymousName {
    if (_currentStudent != null) return _currentStudent!.name;
    if (_currentTeacher != null) {
      return _currentTeacher!.name; // Teachers are visible
    }
    return 'Guest';
  }

  /// Get the notification service for direct access
  NotificationService get notificationService => _notificationService;

  /// Test if notifications are working
  Future<bool> testNotifications() async {
    return await _notificationService.showTestNotification();
  }

  /// Get notification status for debugging
  Future<Map<String, dynamic>> getNotificationStatus() async {
    return await _notificationService.getNotificationStatus();
  }

  /// Manually restart notification listeners
  Future<void> restartNotificationListeners() async {
    final branchId = currentBranchId;
    final userId = currentUserId;
    if (branchId != null && userId != null) {
      await _notificationService.ensureNotificationsEnabled();
      await _notificationService.startRealtimeListeners(
        userId: userId,
        branchId: branchId,
        userType: _userType,
      );
      debugPrint('🔔 Notification listeners restarted');
    } else {
      debugPrint('⚠️ Cannot restart listeners: no user/branch ID');
    }
  }

  AuthProvider() {
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    try {
      // Initialize notifications and request permission
      await _notificationService.initialize();
      await _notificationService.requestPermission();
      await _loadBranches();
    } catch (e) {
      debugPrint('Error loading branches: $e');
    }

    // Load session with timeout to prevent freezing
    try {
      await _loadSavedSession().timeout(
        const Duration(seconds: 5),
        onTimeout: () async {
          debugPrint('Session load timeout - loading from cache only');
          await _loadSessionFromCacheOnly();
        },
      );
    } catch (e) {
      debugPrint('Error loading saved session: $e');
      // Fallback to cache-only session load
      await _loadSessionFromCacheOnly();
    }

    // Mark initialization as complete
    _isInitialized = true;
    _initializationCompleter.complete();
  }

  /// Wait for the auth provider to finish initializing
  Future<void> waitForInitialization() => _initializationCompleter.future;

  Future<void> _loadBranches() async {
    try {
      _branches = await SupabaseService.getBranches()
          .timeout(const Duration(seconds: 5));
      // Cache branches for offline use
      if (_branches.isNotEmpty) {
        await OfflineCacheService.cacheBranches(_branches);
      }
      // Don't notify - branches load in background silently
    } catch (e) {
      debugPrint('Error loading branches: $e - trying offline cache');
      // Try to load from offline cache
      final cachedBranches = await OfflineCacheService.getCachedBranches();
      if (cachedBranches.isNotEmpty) {
        _branches = cachedBranches;
        debugPrint('📦 Loaded ${_branches.length} branches from offline cache');
      }
    }
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserType = prefs.getString('user_type');
      final savedUserId = prefs.getString('user_id');

      if (savedUserType != null && savedUserId != null) {
        // First, set the user type and basic data from cache
        // This ensures user stays logged in even offline
        _userType = savedUserType;

        // Pre-load cached data first for instant offline access
        if (savedUserType == AppConstants.userTypeStudent) {
          _loadCachedStudentData(prefs, savedUserId);
        } else if (savedUserType == AppConstants.userTypeTeacher) {
          _loadCachedTeacherData(prefs, savedUserId);
        }

        // Then try to refresh from network (non-blocking)
        if (savedUserType == AppConstants.userTypeStudent) {
          // Try to reload student data from network with timeout
          try {
            final response = await SupabaseService.client
                .from('students')
                .select()
                .eq('id', savedUserId)
                .maybeSingle()
                .timeout(const Duration(seconds: 3));

            if (response != null) {
              _currentStudent = Student.fromJson(response);
              // Update cached data
              await _saveSessionDetails();
            }
          } catch (e) {
            // Network error - already using cached data
            debugPrint('Network error, using cached student data: $e');
          }
        } else if (savedUserType == AppConstants.userTypeTeacher) {
          // Try to reload teacher data from network with timeout
          try {
            final response = await SupabaseService.client
                .from('teachers')
                .select()
                .eq('id', savedUserId)
                .maybeSingle()
                .timeout(const Duration(seconds: 3));

            if (response != null) {
              _currentTeacher = Teacher.fromJson(response);
              // Update cached data
              await _saveSessionDetails();
            }
          } catch (e) {
            // Network error - already using cached data
            debugPrint('Network error, using cached teacher data: $e');
          }
        }
        // Don't notify during init - SplashScreen checks isLoggedIn directly

        // Ensure notifications are enabled
        await _notificationService.ensureNotificationsEnabled();

        // Start notification listeners for restored session (only if online)
        try {
          final branchId = currentBranchId;
          if (branchId != null && currentUserId != null) {
            debugPrint(
                '🔔 Starting realtime listeners for restored session: $currentUserId');
            await _notificationService
                .startRealtimeListeners(
              userId: currentUserId!,
              branchId: branchId,
              userType: savedUserType,
            )
                .timeout(const Duration(seconds: 5), onTimeout: () {
              debugPrint(
                  '⚠️ Notification listener timeout - continuing offline');
            });
          } else {
            debugPrint(
                '⚠️ Cannot start listeners: branchId=$branchId, userId=$currentUserId');
          }
        } catch (e) {
          debugPrint('❌ Could not start notifications (offline): $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading saved session: $e');
      // Even if session load fails, try to load from cache
      await _loadSessionFromCacheOnly();
    }
  }

  /// Load session entirely from cache (no network calls)
  Future<void> _loadSessionFromCacheOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserType = prefs.getString('user_type');
      final savedUserId = prefs.getString('user_id');

      if (savedUserType != null && savedUserId != null) {
        _userType = savedUserType;

        if (savedUserType == AppConstants.userTypeStudent) {
          _loadCachedStudentData(prefs, savedUserId);
        } else if (savedUserType == AppConstants.userTypeTeacher) {
          _loadCachedTeacherData(prefs, savedUserId);
        }

        debugPrint('📦 Loaded session from cache: $_userType');
      }
    } catch (e) {
      debugPrint('Error loading session from cache: $e');
    }
  }

  void _loadCachedStudentData(SharedPreferences prefs, String savedUserId) {
    final savedUserName = prefs.getString('user_name');
    final savedBranchId = prefs.getString('branch_id');
    final savedEmail = prefs.getString('user_email');
    final savedRollNumber = prefs.getString('roll_number');
    final savedSemester = prefs.getInt('semester');
    final savedAnonymousId = prefs.getString('anonymous_id');

    if (savedUserName != null) {
      _currentStudent = Student(
        id: savedUserId,
        email: savedEmail ?? '',
        name: savedUserName,
        rollNumber: savedRollNumber ?? '',
        branchId: savedBranchId,
        semester: savedSemester ?? 1,
        anonymousId: savedAnonymousId ?? 'Anon',
      );
      _userType = AppConstants.userTypeStudent;
    }
  }

  void _loadCachedTeacherData(SharedPreferences prefs, String savedUserId) {
    final savedUserName = prefs.getString('user_name');
    final savedBranchId = prefs.getString('branch_id');
    final savedEmail = prefs.getString('user_email');
    final savedIsHod = prefs.getBool('is_hod') ?? false;
    final savedIsAdmin = prefs.getBool('is_admin') ?? false;

    if (savedUserName != null) {
      _currentTeacher = Teacher(
        id: savedUserId,
        email: savedEmail ?? '',
        name: savedUserName,
        branchId: savedBranchId,
        isHod: savedIsHod,
        isAdmin: savedIsAdmin,
      );
      _userType = AppConstants.userTypeTeacher;
    }
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_type', _userType);
    await prefs.setString('user_id', currentUserId ?? '');
    await _saveSessionDetails();
  }

  Future<void> _saveSessionDetails() async {
    final prefs = await SharedPreferences.getInstance();
    if (_currentStudent != null) {
      await prefs.setString('user_name', _currentStudent!.name);
      await prefs.setString('user_email', _currentStudent!.email);
      if (_currentStudent!.branchId != null) {
        await prefs.setString('branch_id', _currentStudent!.branchId!);
      }
      await prefs.setString('roll_number', _currentStudent!.rollNumber);
      await prefs.setInt('semester', _currentStudent!.semester);
      await prefs.setString('anonymous_id', _currentStudent!.anonymousId);
    } else if (_currentTeacher != null) {
      await prefs.setString('user_name', _currentTeacher!.name);
      await prefs.setString('user_email', _currentTeacher!.email);
      if (_currentTeacher!.branchId != null) {
        await prefs.setString('branch_id', _currentTeacher!.branchId!);
      }
      await prefs.setBool('is_hod', _currentTeacher!.isHod);
      await prefs.setBool('is_admin', _currentTeacher!.isAdmin);
    }
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_type');
    await prefs.remove('user_id');
  }

  Future<bool> loginStudent(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Add timeout to prevent freezing on network issues
      final student =
          await SupabaseService.loginStudent(email, password).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Login request timed out'),
      );

      if (student != null) {
        _currentStudent = student;
        _currentTeacher = null;
        _userType = AppConstants.userTypeStudent;
        await _saveSession();

        // Ensure notifications are properly set up
        await _notificationService.ensureNotificationsEnabled();

        // Start notification listeners
        if (student.branchId != null) {
          debugPrint(
              '🔔 Starting realtime listeners for student: ${student.id}');
          await _notificationService.startRealtimeListeners(
            userId: student.id,
            branchId: student.branchId!,
            userType: 'student',
          );
        } else {
          debugPrint(
              '⚠️ Student has no branchId, cannot start realtime listeners');
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid email or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginTeacher(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Add timeout to prevent freezing on network issues
      final teacher =
          await SupabaseService.loginTeacher(email, password).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Login request timed out'),
      );

      if (teacher != null) {
        _currentTeacher = teacher;
        _currentStudent = null;
        _userType = AppConstants.userTypeTeacher;
        await _saveSession();

        // Auto-update teacher location based on timetable
        await SupabaseService.autoUpdateTeacherLocation(teacher.id);

        // Ensure notifications are properly set up
        await _notificationService.ensureNotificationsEnabled();

        // Start notification listeners
        if (teacher.branchId != null) {
          debugPrint(
              '🔔 Starting realtime listeners for teacher: ${teacher.id}');
          await _notificationService.startRealtimeListeners(
            userId: teacher.id,
            branchId: teacher.branchId!,
            userType: 'teacher',
          );
        } else {
          debugPrint(
              '⚠️ Teacher has no branchId, cannot start realtime listeners');
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Invalid email or password';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerStudent({
    required String email,
    required String password,
    required String name,
    required String rollNumber,
    required String branchId,
    required int semester,
    String? phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final student = await SupabaseService.registerStudent(
        email: email,
        password: password,
        name: name,
        rollNumber: rollNumber,
        branchId: branchId,
        semester: semester,
        phone: phone,
      );

      if (student != null) {
        _currentStudent = student;
        _currentTeacher = null;
        _userType = AppConstants.userTypeStudent;
        await _saveSession();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Registration failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      String errorMsg = e.toString();
      // Clean up exception message
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }
      _error = errorMsg;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> registerTeacher({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? branchId,
    bool isHod = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final teacher = await SupabaseService.registerTeacher(
        email: email,
        password: password,
        name: name,
        phone: phone,
        branchId: branchId,
        isHod: isHod,
      );

      if (teacher != null) {
        _currentTeacher = teacher;
        _currentStudent = null;
        _userType = AppConstants.userTypeTeacher;
        await _saveSession();
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Registration failed. Please try again.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      String errorMsg = e.toString();
      // Clean up exception message
      if (errorMsg.startsWith('Exception: ')) {
        errorMsg = errorMsg.substring(11);
      }
      _error = errorMsg;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void continueAsGuest() {
    _userType = AppConstants.userTypeGuest;
    _currentStudent = null;
    _currentTeacher = null;
    notifyListeners();
  }

  /// Update student profile
  Future<bool> updateStudentProfile({
    String? name,
    int? semester,
    String? phone,
  }) async {
    if (_currentStudent == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (semester != null) updates['semester'] = semester;
      if (phone != null) updates['phone'] = phone;

      if (updates.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final success =
          await SupabaseService.updateStudent(_currentStudent!.id, updates);

      if (success) {
        // Update local student object
        _currentStudent = Student(
          id: _currentStudent!.id,
          email: _currentStudent!.email,
          name: name ?? _currentStudent!.name,
          rollNumber: _currentStudent!.rollNumber,
          branchId: _currentStudent!.branchId,
          semester: semester ?? _currentStudent!.semester,
          anonymousId: _currentStudent!.anonymousId,
          phone: phone ?? _currentStudent!.phone,
        );
        await _saveSessionDetails();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to update profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update teacher profile
  Future<bool> updateTeacherProfile({
    String? name,
    String? phone,
  }) async {
    if (_currentTeacher == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final updates = <String, dynamic>{};
      if (name != null && name.isNotEmpty) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;

      if (updates.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return true;
      }

      final success =
          await SupabaseService.updateTeacher(_currentTeacher!.id, updates);

      if (success) {
        // Update local teacher object
        _currentTeacher = Teacher(
          id: _currentTeacher!.id,
          email: _currentTeacher!.email,
          name: name ?? _currentTeacher!.name,
          phone: phone ?? _currentTeacher!.phone,
          branchId: _currentTeacher!.branchId,
          isHod: _currentTeacher!.isHod,
          isAdmin: _currentTeacher!.isAdmin,
          currentRoomId: _currentTeacher!.currentRoomId,
          currentRoomUpdatedAt: _currentTeacher!.currentRoomUpdatedAt,
        );
        await _saveSessionDetails();
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to update profile: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Change password
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      bool success;
      if (_currentStudent != null) {
        success = await SupabaseService.changeStudentPassword(
          _currentStudent!.id,
          currentPassword,
          newPassword,
        );
      } else if (_currentTeacher != null) {
        success = await SupabaseService.changeTeacherPassword(
          _currentTeacher!.id,
          currentPassword,
          newPassword,
        );
      } else {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!success) {
        _error = 'Current password is incorrect';
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to change password: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    // Stop notification listeners
    await _notificationService.stopRealtimeListeners();

    _currentStudent = null;
    _currentTeacher = null;
    _userType = AppConstants.userTypeGuest;
    _error = null;
    await _clearSession();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
