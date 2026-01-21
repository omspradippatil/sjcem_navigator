import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../models/models.dart';
import '../services/supabase_service.dart';
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
    if (_currentStudent != null) return _currentStudent!.anonymousId;
    if (_currentTeacher != null) {
      return _currentTeacher!.name; // Teachers are visible
    }
    return 'Guest';
  }

  AuthProvider() {
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    try {
      await _loadBranches();
    } catch (e) {
      debugPrint('Error loading branches: $e');
    }

    // Load session with timeout to prevent freezing
    try {
      await _loadSavedSession().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint(
              'Session load timeout - proceeding without cached session');
        },
      );
    } catch (e) {
      debugPrint('Error loading saved session: $e');
    }

    // Mark initialization as complete
    _isInitialized = true;
    _initializationCompleter.complete();
  }

  /// Wait for the auth provider to finish initializing
  Future<void> waitForInitialization() => _initializationCompleter.future;

  Future<void> _loadBranches() async {
    try {
      _branches = await SupabaseService.getBranches();
      // Don't notify - branches load in background silently
    } catch (e) {
      debugPrint('Error loading branches: $e');
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

        if (savedUserType == AppConstants.userTypeStudent) {
          // Try to reload student data from network
          try {
            final response = await SupabaseService.client
                .from('students')
                .select()
                .eq('id', savedUserId)
                .maybeSingle();

            if (response != null) {
              _currentStudent = Student.fromJson(response);
              // Update cached data
              await _saveSessionDetails();
            } else {
              // Use cached data if available
              _loadCachedStudentData(prefs, savedUserId);
            }
          } catch (e) {
            // Network error - use cached data
            debugPrint('Network error, using cached student data: $e');
            _loadCachedStudentData(prefs, savedUserId);
          }
        } else if (savedUserType == AppConstants.userTypeTeacher) {
          // Try to reload teacher data from network
          try {
            final response = await SupabaseService.client
                .from('teachers')
                .select()
                .eq('id', savedUserId)
                .maybeSingle();

            if (response != null) {
              _currentTeacher = Teacher.fromJson(response);
              // Update cached data
              await _saveSessionDetails();
            } else {
              // Use cached data if available
              _loadCachedTeacherData(prefs, savedUserId);
            }
          } catch (e) {
            // Network error - use cached data
            debugPrint('Network error, using cached teacher data: $e');
            _loadCachedTeacherData(prefs, savedUserId);
          }
        }
        // Don't notify during init - SplashScreen checks isLoggedIn directly
      }
    } catch (e) {
      debugPrint('Error loading saved session: $e');
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
        _error = 'Registration failed. Email may already exist.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
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
        _error = 'Registration failed. Email may already exist.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: ${e.toString()}';
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

  Future<void> logout() async {
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
