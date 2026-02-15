import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';
import '../../models/teacher.dart';
import '../../models/student.dart';
import '../../models/room.dart';
import '../../models/branch.dart';
import '../../models/poll.dart';
import '../../models/subject.dart';
import '../../models/timetable_entry.dart';
import '../../utils/constants.dart';
import '../../utils/app_theme.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen>
    with SingleTickerProviderStateMixin {
  static const String _adminPassword = 'SJCEM';

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _passwordError;

  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();
  late TabController _tabController;

  String _searchQuery = '';

  List<Teacher> _teachers = [];
  List<Student> _students = [];
  List<Room> _rooms = [];
  List<Branch> _branches = [];
  List<Poll> _polls = [];
  List<Subject> _subjects = [];
  List<TimetableEntry> _timetableEntries = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _verifyPassword() {
    if (_passwordController.text == _adminPassword) {
      setState(() {
        _isAuthenticated = true;
        _passwordError = null;
      });
      _loadAllData();
    } else {
      setState(() {
        _passwordError = 'Invalid password. Access denied.';
      });
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.getTeachers(),
        SupabaseService.getStudents(),
        SupabaseService.getRooms(),
        SupabaseService.getBranches(),
        SupabaseService.getPolls(),
        SupabaseService.getSubjects(),
        SupabaseService.getAllTimetableEntries(),
      ]);

      setState(() {
        _teachers = results[0] as List<Teacher>;
        _students = results[1] as List<Student>;
        _rooms = results[2] as List<Room>;
        _branches = results[3] as List<Branch>;
        _polls = results[4] as List<Poll>;
        _subjects = results[5] as List<Subject>;
        _timetableEntries = results[6] as List<TimetableEntry>;
      });
    } catch (e) {
      _showError('Failed to load data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    PremiumSnackBar.showError(context, message);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    PremiumSnackBar.showSuccess(context, message);
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppGradients.primary.createShader(bounds),
              child: const Icon(Icons.search, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(
              'Search',
              style: TextStyle(color: AppColors.textPrimary),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.glassDark,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search by name, email, code...',
                  hintStyle: TextStyle(color: AppColors.textMuted),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value.toLowerCase());
                },
                onSubmitted: (_) {
                  Navigator.pop(context);
                  setState(() {});
                },
              ),
            ),
            if (_searchQuery.isNotEmpty) ...[
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _searchQuery = '';
                    _searchController.clear();
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.clear, size: 18, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Clear Search',
                          style: TextStyle(color: AppColors.error)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  // Filter helpers
  List<Teacher> get _filteredTeachers {
    if (_searchQuery.isEmpty) return _teachers;
    return _teachers
        .where((t) =>
            t.name.toLowerCase().contains(_searchQuery) ||
            t.email.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<Student> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    return _students
        .where((s) =>
            s.name.toLowerCase().contains(_searchQuery) ||
            s.email.toLowerCase().contains(_searchQuery) ||
            s.rollNumber.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<Room> get _filteredRooms {
    if (_searchQuery.isEmpty) return _rooms;
    return _rooms
        .where((r) =>
            r.name.toLowerCase().contains(_searchQuery) ||
            r.roomNumber.toLowerCase().contains(_searchQuery) ||
            r.roomType.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<Branch> get _filteredBranches {
    if (_searchQuery.isEmpty) return _branches;
    return _branches
        .where((b) =>
            b.name.toLowerCase().contains(_searchQuery) ||
            b.code.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<Poll> get _filteredPolls {
    if (_searchQuery.isEmpty) return _polls;
    return _polls
        .where((p) => p.title.toLowerCase().contains(_searchQuery))
        .toList();
  }

  List<Subject> get _filteredSubjects {
    if (_searchQuery.isEmpty) return _subjects;
    return _subjects
        .where((s) =>
            s.name.toLowerCase().contains(_searchQuery) ||
            s.code.toLowerCase().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return _buildPasswordScreen();
    }
    return _buildAdminPanel();
  }

  Widget _buildPasswordScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassDark,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: AppColors.textPrimary),
          ),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => AppGradients.error.createShader(bounds),
          child: const Text(
            'Admin Panel',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              Color(0xFF1A1A2E),
              AppColors.backgroundDark,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 400),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: AppColors.cardDark.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppColors.glassBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.error.withValues(alpha: 0.1),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.error,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.error
                                          .withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.admin_panel_settings_rounded,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Admin Authentication',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Enter admin password to access the panel',
                                style: TextStyle(color: AppColors.textMuted),
                              ),
                              const SizedBox(height: 32),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.glassDark,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _passwordError != null
                                        ? AppColors.error.withValues(alpha: 0.5)
                                        : AppColors.glassBorder,
                                  ),
                                ),
                                child: TextField(
                                  controller: _passwordController,
                                  obscureText: true,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: InputDecoration(
                                    hintText: 'Admin Password',
                                    hintStyle: const TextStyle(
                                        color: AppColors.textMuted),
                                    prefixIcon: ShaderMask(
                                      shaderCallback: (bounds) => AppGradients
                                          .error
                                          .createShader(bounds),
                                      child: const Icon(Icons.lock_rounded,
                                          color: Colors.white),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 16),
                                  ),
                                  onSubmitted: (_) => _verifyPassword(),
                                ),
                              ),
                              if (_passwordError != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.error.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.error
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 16, color: AppColors.error),
                                      const SizedBox(width: 8),
                                      Text(
                                        _passwordError!,
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  _verifyPassword();
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.error,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.error
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.security_rounded,
                                          color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'ACCESS PANEL',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPanel() {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight + 50),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              backgroundColor: AppColors.glassDark,
              elevation: 0,
              leading: IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.glassDark,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new,
                      size: 16, color: AppColors.textPrimary),
                ),
              ),
              title: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.error.createShader(bounds),
                child: const Text(
                  'Admin Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppGradients.primary.createShader(bounds),
                      child: Icon(
                        _searchQuery.isEmpty ? Icons.search : Icons.search_off,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _showSearchDialog();
                  },
                  tooltip: 'Search',
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppGradients.accent.createShader(bounds),
                      child: const Icon(Icons.refresh_rounded,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _loadAllData();
                  },
                  tooltip: 'Refresh Data',
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppGradients.error.createShader(bounds),
                      child: const Icon(Icons.lock_rounded,
                          size: 20, color: Colors.white),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _isAuthenticated = false;
                      _passwordController.clear();
                    });
                  },
                  tooltip: 'Lock Panel',
                ),
                const SizedBox(width: 8),
              ],
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppColors.error,
                indicatorWeight: 3,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                onTap: (_) {
                  // Clear search when switching tabs
                  if (_searchQuery.isNotEmpty) {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  }
                },
                tabs: const [
                  Tab(
                      icon: Icon(Icons.dashboard_rounded, size: 20),
                      text: 'Dashboard'),
                  Tab(
                      icon: Icon(Icons.person_rounded, size: 20),
                      text: 'Teachers'),
                  Tab(
                      icon: Icon(Icons.school_rounded, size: 20),
                      text: 'Students'),
                  Tab(icon: Icon(Icons.room_rounded, size: 20), text: 'Rooms'),
                  Tab(
                      icon: Icon(Icons.business_rounded, size: 20),
                      text: 'Branches'),
                  Tab(icon: Icon(Icons.poll_rounded, size: 20), text: 'Polls'),
                  Tab(
                      icon: Icon(Icons.book_rounded, size: 20),
                      text: 'Subjects'),
                  Tab(
                      icon: Icon(Icons.schedule_rounded, size: 20),
                      text: 'Timetable'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.backgroundDark,
              Color(0xFF1A1A2E),
              AppColors.backgroundDark,
            ],
          ),
        ),
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppGradients.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.4),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Loading admin data...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildDashboardTab(),
                  _buildTeachersTab(),
                  _buildStudentsTab(),
                  _buildRoomsTab(),
                  _buildBranchesTab(),
                  _buildPollsTab(),
                  _buildSubjectsTab(),
                  _buildTimetableTab(),
                ],
              ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.error,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: FloatingActionButton(
              backgroundColor: Colors.transparent,
              elevation: 0,
              onPressed: () {
                HapticFeedback.mediumImpact();
                switch (_tabController.index) {
                  case 1:
                    _showAddTeacherDialog();
                    break;
                  case 2:
                    _showAddStudentDialog();
                    break;
                  case 3:
                    _showAddRoomDialog();
                    break;
                  case 4:
                    _showAddBranchDialog();
                    break;
                  case 5:
                    _showAddPollDialog();
                    break;
                  case 6:
                    _showAddSubjectDialog();
                    break;
                  case 7:
                    _showAddTimetableDialog();
                    break;
                  default:
                    break;
                }
              },
              child: const Icon(Icons.add_rounded, color: Colors.white),
            ),
          ),
        );
      },
    );
  }

  // Dashboard Tab
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppGradients.error,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'System Overview',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildStatCard('Teachers', _teachers.length,
                      Icons.person_rounded, AppGradients.info,
                      tabIndex: 1),
                  _buildStatCard('Students', _students.length,
                      Icons.school_rounded, AppGradients.success,
                      tabIndex: 2),
                  _buildStatCard('Rooms', _rooms.length, Icons.room_rounded,
                      AppGradients.warning,
                      tabIndex: 3),
                  _buildStatCard('Branches', _branches.length,
                      Icons.business_rounded, AppGradients.primary,
                      tabIndex: 4),
                  _buildStatCard('Polls', _polls.length, Icons.poll_rounded,
                      AppGradients.accent,
                      tabIndex: 5),
                  _buildStatCard(
                      'Subjects',
                      _subjects.length,
                      Icons.book_rounded,
                      const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      tabIndex: 6),
                  _buildStatCard('Timetable', _timetableEntries.length,
                      Icons.schedule_rounded, AppGradients.error,
                      tabIndex: 7),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppGradients.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.glassDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Column(
                  children: [
                    _buildQuickStatRow(
                        'HOD Teachers',
                        _teachers.where((t) => t.isHod).length.toString(),
                        AppColors.warning),
                    _buildQuickStatRow(
                        'Admin Teachers',
                        _teachers.where((t) => t.isAdmin).length.toString(),
                        AppColors.error),
                    _buildQuickStatRow(
                        'Active Polls',
                        _polls.where((p) => p.isActive).length.toString(),
                        AppColors.success),
                    _buildQuickStatRow('Total Rooms', _rooms.length.toString(),
                        AppColors.info),
                    _buildQuickStatRow(
                        'Floor 3 Rooms',
                        _rooms.where((r) => r.floor == 3).length.toString(),
                        AppColors.primaryLight),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, int count, IconData icon, Gradient gradient,
      {int? tabIndex}) {
    return GestureDetector(
      onTap: tabIndex != null
          ? () {
              HapticFeedback.lightImpact();
              _tabController.animateTo(tabIndex);
            }
          : null,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (value * 0.2),
            child: Opacity(
              opacity: value,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: (gradient as LinearGradient)
                          .colors
                          .first
                          .withValues(alpha: 0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(
                      count.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Teachers Tab
  Widget _buildTeachersTab() {
    final teachers = _filteredTeachers;

    if (teachers.isEmpty) {
      return _buildEmptyState(
        'No teachers found',
        _searchQuery.isEmpty
            ? 'Tap + to add a new teacher'
            : 'Try a different search term',
        Icons.person_off_rounded,
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.cardDark,
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: teachers.length,
        itemBuilder: (context, index) {
          final teacher = teachers[index];
          return _buildPremiumTeacherCard(teacher);
        },
      ),
    );
  }

  Widget _buildPremiumTeacherCard(Teacher teacher) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: teacher.isHod
                                ? AppGradients.warning
                                : teacher.isAdmin
                                    ? AppGradients.error
                                    : AppGradients.info,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (teacher.isHod
                                        ? AppColors.warning
                                        : teacher.isAdmin
                                            ? AppColors.error
                                            : AppColors.info)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              teacher.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                teacher.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                teacher.email,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.info.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getBranchName(teacher.branchId),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (teacher.isHod)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.warning,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'HOD',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  if (teacher.isAdmin) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.error,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.glassDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Icon(Icons.more_vert,
                                color: AppColors.textMuted, size: 18),
                          ),
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) =>
                              _handleTeacherAction(value, teacher),
                          itemBuilder: (context) => [
                            _buildPremiumMenuItem(
                                'assign_subjects',
                                'Assign Subjects',
                                Icons.book_rounded,
                                AppGradients.primary),
                            _buildPremiumMenuItem(
                                'toggle_hod',
                                teacher.isHod ? 'Remove HOD' : 'Make HOD',
                                Icons.star_rounded,
                                AppGradients.warning),
                            _buildPremiumMenuItem(
                                'toggle_admin',
                                teacher.isAdmin ? 'Remove Admin' : 'Make Admin',
                                Icons.admin_panel_settings_rounded,
                                AppGradients.accent),
                            _buildPremiumMenuItem('delete', 'Delete',
                                Icons.delete_rounded, AppGradients.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PopupMenuItem<String> _buildPremiumMenuItem(
      String value, String label, IconData icon, LinearGradient gradient) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => gradient.createShader(bounds),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color:
                  value == 'delete' ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: AppGradients.primarySubtle,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppGradients.primary.createShader(bounds),
                      child: Icon(icon, size: 64, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _getBranchName(String? branchId) {
    if (branchId == null) return 'Not Assigned';
    final branch = _branches.firstWhere(
      (b) => b.id == branchId,
      orElse: () => Branch(id: '', name: 'Unknown', code: ''),
    );
    return branch.name;
  }

  Future<void> _handleTeacherAction(String action, Teacher teacher) async {
    try {
      switch (action) {
        case 'assign_subjects':
          _showAssignSubjectsDialog(teacher);
          break;
        case 'toggle_hod':
          await SupabaseService.updateTeacher(
              teacher.id, {'is_hod': !teacher.isHod});
          _showSuccess('Teacher HOD status updated');
          await _loadAllData();
          break;
        case 'toggle_admin':
          await SupabaseService.updateTeacher(
              teacher.id, {'is_admin': !teacher.isAdmin});
          _showSuccess('Teacher admin status updated');
          await _loadAllData();
          break;
        case 'delete':
          final confirm = await _showConfirmDialog('Delete Teacher',
              'Are you sure you want to delete ${teacher.name}?');
          if (confirm == true) {
            await SupabaseService.deleteTeacher(teacher.id);
            _showSuccess('Teacher deleted');
            await _loadAllData();
          }
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  void _showAssignSubjectsDialog(Teacher teacher) async {
    // Load current assigned subjects
    final assignedSubjects =
        await SupabaseService.getTeacherSubjects(teacher.id);
    final assignedIds = assignedSubjects.map((s) => s.id).toSet();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Assign Subjects to ${teacher.name}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _subjects.length,
                itemBuilder: (context, index) {
                  final subject = _subjects[index];
                  final isAssigned = assignedIds.contains(subject.id);
                  return CheckboxListTile(
                    title: Text(subject.name),
                    subtitle: Text('${subject.code} - Sem ${subject.semester}'),
                    value: isAssigned,
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          assignedIds.add(subject.id);
                        } else {
                          assignedIds.remove(subject.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await SupabaseService.assignTeacherSubjects(
                      teacher.id,
                      assignedIds.toList(),
                    );
                    Navigator.pop(context);
                    _showSuccess('Subjects assigned successfully');
                  } catch (e) {
                    _showError('Failed to assign subjects: $e');
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Students Tab
  Widget _buildStudentsTab() {
    final students = _filteredStudents;

    if (students.isEmpty) {
      return _buildEmptyState(
        'No students found',
        _searchQuery.isEmpty
            ? 'Tap + to add a new student'
            : 'Try a different search term',
        Icons.school_outlined,
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.cardDark,
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return _buildPremiumStudentCard(student);
        },
      ),
    );
  }

  Widget _buildPremiumStudentCard(Student student) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppGradients.success,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              student.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                student.email,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Roll: ${student.rollNumber}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.info.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Sem ${student.semester}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getBranchName(student.branchId),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.glassDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Icon(Icons.more_vert,
                                color: AppColors.textMuted, size: 18),
                          ),
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) =>
                              _handleStudentAction(value, student),
                          itemBuilder: (context) => [
                            _buildPremiumMenuItem('view', 'View Details',
                                Icons.visibility_rounded, AppGradients.primary),
                            _buildPremiumMenuItem('delete', 'Delete',
                                Icons.delete_rounded, AppGradients.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleStudentAction(String action, Student student) async {
    try {
      switch (action) {
        case 'view':
          _showStudentDetailsDialog(student);
          break;
        case 'delete':
          final confirm = await _showConfirmDialog('Delete Student',
              'Are you sure you want to delete ${student.name}?');
          if (confirm == true) {
            await SupabaseService.deleteStudent(student.id);
            _showSuccess('Student deleted');
            await _loadAllData();
          }
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  void _showStudentDetailsDialog(Student student) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppGradients.success,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  student.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: AppGradients.success,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Student',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDetailRow(Icons.email_rounded, 'Email', student.email),
            _buildDetailRow(
                Icons.badge_rounded, 'Roll Number', student.rollNumber),
            _buildDetailRow(
                Icons.school_rounded, 'Semester', '${student.semester}'),
            _buildDetailRow(Icons.business_rounded, 'Branch',
                _getBranchName(student.branchId)),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.glassDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.textMuted, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Rooms Tab
  Widget _buildRoomsTab() {
    final rooms = _filteredRooms;

    if (rooms.isEmpty) {
      return _buildEmptyState(
        'No rooms found',
        _searchQuery.isEmpty
            ? 'Tap + to add a new room'
            : 'Try a different search term',
        Icons.room_outlined,
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.cardDark,
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: rooms.length,
        itemBuilder: (context, index) {
          final room = rooms[index];
          return _buildPremiumRoomCard(room);
        },
      ),
    );
  }

  Widget _buildPremiumRoomCard(Room room) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppGradients.warning,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.warning.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.room_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                room.displayName ?? room.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Room ${room.roomNumber}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      room.roomType.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.info.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Floor ${room.floor}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.success
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${room.capacity} seats',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.glassDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Icon(Icons.more_vert,
                                color: AppColors.textMuted, size: 18),
                          ),
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) => _handleRoomAction(value, room),
                          itemBuilder: (context) => [
                            _buildPremiumMenuItem('edit', 'Edit',
                                Icons.edit_rounded, AppGradients.primary),
                            _buildPremiumMenuItem('delete', 'Delete',
                                Icons.delete_rounded, AppGradients.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRoomAction(String action, Room room) async {
    try {
      switch (action) {
        case 'edit':
          _showEditRoomDialog(room);
          break;
        case 'delete':
          final confirm = await _showConfirmDialog(
              'Delete Room', 'Are you sure you want to delete ${room.name}?');
          if (confirm == true) {
            await SupabaseService.deleteRoom(room.id);
            _showSuccess('Room deleted');
            await _loadAllData();
          }
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  // Branches Tab
  Widget _buildBranchesTab() {
    final branches = _filteredBranches;

    if (branches.isEmpty) {
      return _buildEmptyState(
        'No branches found',
        _searchQuery.isEmpty
            ? 'Tap + to add a new branch'
            : 'Try a different search term',
        Icons.business_outlined,
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.cardDark,
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: branches.length,
        itemBuilder: (context, index) {
          final branch = branches[index];
          return _buildPremiumBranchCard(branch);
        },
      ),
    );
  }

  Widget _buildPremiumBranchCard(Branch branch) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLight
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              branch.code.length >= 2
                                  ? branch.code.substring(0, 2).toUpperCase()
                                  : branch.code.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                branch.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AppGradients.primarySubtle,
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: AppColors.glassBorder),
                                ),
                                child: Text(
                                  'Code: ${branch.code}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.glassDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Icon(Icons.more_vert,
                                color: AppColors.textMuted, size: 18),
                          ),
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) =>
                              _handleBranchAction(value, branch),
                          itemBuilder: (context) => [
                            _buildPremiumMenuItem('edit', 'Edit',
                                Icons.edit_rounded, AppGradients.primary),
                            _buildPremiumMenuItem('delete', 'Delete',
                                Icons.delete_rounded, AppGradients.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleBranchAction(String action, Branch branch) async {
    try {
      switch (action) {
        case 'edit':
          _showEditBranchDialog(branch);
          break;
        case 'delete':
          final confirm = await _showConfirmDialog('Delete Branch',
              'Are you sure you want to delete ${branch.name}?');
          if (confirm == true) {
            await SupabaseService.deleteBranch(branch.id);
            _showSuccess('Branch deleted');
            await _loadAllData();
          }
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  // Polls Tab
  Widget _buildPollsTab() {
    final polls = _filteredPolls;

    if (polls.isEmpty) {
      return _buildEmptyState(
        'No polls found',
        _searchQuery.isEmpty
            ? 'Tap + to create a new poll'
            : 'Try a different search term',
        Icons.poll_outlined,
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.cardDark,
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: polls.length,
        itemBuilder: (context, index) {
          final poll = polls[index];
          return _buildPremiumPollCard(poll);
        },
      ),
    );
  }

  Widget _buildPremiumPollCard(Poll poll) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: poll.isActive
                                ? AppGradients.success
                                : AppGradients.secondary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: (poll.isActive
                                        ? AppColors.success
                                        : AppColors.textMuted)
                                    .withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.poll_rounded,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                poll.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${poll.options.length} options',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: poll.isActive
                                      ? AppGradients.success
                                      : null,
                                  color: poll.isActive
                                      ? null
                                      : AppColors.textMuted
                                          .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  poll.isActive ? 'Active' : 'Inactive',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.glassDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Icon(Icons.more_vert,
                                color: AppColors.textMuted, size: 18),
                          ),
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) => _handlePollAction(value, poll),
                          itemBuilder: (context) => [
                            _buildPremiumMenuItem(
                                'toggle',
                                poll.isActive ? 'Deactivate' : 'Activate',
                                poll.isActive
                                    ? Icons.pause_circle_rounded
                                    : Icons.play_circle_rounded,
                                poll.isActive
                                    ? AppGradients.warning
                                    : AppGradients.success),
                            _buildPremiumMenuItem('results', 'View Results',
                                Icons.analytics_rounded, AppGradients.info),
                            _buildPremiumMenuItem('delete', 'Delete',
                                Icons.delete_rounded, AppGradients.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePollAction(String action, Poll poll) async {
    try {
      switch (action) {
        case 'toggle':
          await SupabaseService.updatePoll(
              poll.id, {'is_active': !poll.isActive});
          _showSuccess('Poll status updated');
          break;
        case 'results':
          _showPollResultsDialog(poll);
          break;
        case 'delete':
          final confirm = await _showConfirmDialog(
              'Delete Poll', 'Are you sure you want to delete this poll?');
          if (confirm == true) {
            await SupabaseService.deletePoll(poll.id);
            _showSuccess('Poll deleted');
          }
          break;
      }
      await _loadAllData();
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  void _showPollResultsDialog(Poll poll) {
    final totalVotes =
        poll.options.fold<int>(0, (sum, opt) => sum + opt.voteCount);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppGradients.info,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.analytics_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Poll Results',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.glassDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.glassBorder),
                ),
                child: Text(
                  poll.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Total votes: $totalVotes',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              ...poll.options.map((option) {
                final percentage =
                    totalVotes > 0 ? (option.voteCount / totalVotes) : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option.optionText,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${option.voteCount} (${(percentage * 100).toStringAsFixed(1)}%)',
                            style: const TextStyle(
                              color: AppColors.info,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percentage,
                          backgroundColor: AppColors.glassDark,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.info,
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Subjects Tab
  Widget _buildSubjectsTab() {
    final subjects = _filteredSubjects;

    if (subjects.isEmpty) {
      return _buildEmptyState(
        'No subjects found',
        _searchQuery.isEmpty
            ? 'Tap + to add a new subject'
            : 'Try a different search term',
        Icons.book_outlined,
      );
    }

    return RefreshIndicator(
      color: AppColors.primaryLight,
      backgroundColor: AppColors.cardDark,
      onRefresh: _loadAllData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subject = subjects[index];
          return _buildPremiumSubjectCard(subject);
        },
      ),
    );
  }

  Widget _buildPremiumSubjectCard(Subject subject) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 300),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.glassDark,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: AppGradients.accent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              subject.code.length >= 2
                                  ? subject.code.substring(0, 2).toUpperCase()
                                  : subject.code.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Code: ${subject.code}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Sem ${subject.semester}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accent,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.info.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${subject.credits} Credits',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.info,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getBranchName(subject.branchId),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Actions
                        PopupMenuButton<String>(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.glassDark,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: const Icon(Icons.more_vert,
                                color: AppColors.textMuted, size: 18),
                          ),
                          color: AppColors.cardDark,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          onSelected: (value) =>
                              _handleSubjectAction(value, subject),
                          itemBuilder: (context) => [
                            _buildPremiumMenuItem('edit', 'Edit',
                                Icons.edit_rounded, AppGradients.primary),
                            _buildPremiumMenuItem('delete', 'Delete',
                                Icons.delete_rounded, AppGradients.error),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSubjectAction(String action, Subject subject) async {
    try {
      switch (action) {
        case 'edit':
          _showEditSubjectDialog(subject);
          break;
        case 'delete':
          final confirm = await _showConfirmDialog('Delete Subject',
              'Are you sure you want to delete ${subject.name}?');
          if (confirm == true) {
            await SupabaseService.deleteSubject(subject.id);
            _showSuccess('Subject deleted');
            await _loadAllData();
          }
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  // Confirm Dialog
  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppGradients.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // Add Dialogs
  void _showAddTeacherDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    String? selectedBranchId;
    bool isHod = false;
    bool isAdmin = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Teacher'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBranchId = v),
                ),
                CheckboxListTile(
                  title: const Text('Is HOD'),
                  value: isHod,
                  onChanged: (v) => setDialogState(() => isHod = v ?? false),
                ),
                CheckboxListTile(
                  title: const Text('Is Admin'),
                  value: isAdmin,
                  onChanged: (v) => setDialogState(() => isAdmin = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseService.registerTeacher(
                    email: emailController.text,
                    password: passwordController.text,
                    name: nameController.text,
                    branchId: selectedBranchId,
                    isHod: isHod,
                    isAdmin: isAdmin,
                  );
                  Navigator.pop(context);
                  _showSuccess('Teacher added successfully');
                  await _loadAllData();
                } catch (e) {
                  _showError('Failed to add teacher: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final rollController = TextEditingController();
    final semesterController = TextEditingController();
    String? selectedBranchId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Student'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                TextField(
                  controller: rollController,
                  decoration: const InputDecoration(labelText: 'Roll Number'),
                ),
                TextField(
                  controller: semesterController,
                  decoration:
                      const InputDecoration(labelText: 'Semester (1-8)'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBranchId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseService.registerStudent(
                    email: emailController.text,
                    password: passwordController.text,
                    name: nameController.text,
                    rollNumber: rollController.text,
                    branchId: selectedBranchId!,
                    semester: int.parse(semesterController.text),
                  );
                  Navigator.pop(context);
                  _showSuccess('Student added successfully');
                  await _loadAllData();
                } catch (e) {
                  _showError('Failed to add student: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRoomDialog() {
    final nameController = TextEditingController();
    final roomNumberController = TextEditingController();
    final floorController = TextEditingController();
    final roomTypeController = TextEditingController(text: 'classroom');
    final capacityController = TextEditingController(text: '60');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Room Name'),
              ),
              TextField(
                controller: roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
              ),
              TextField(
                controller: floorController,
                decoration: const InputDecoration(labelText: 'Floor'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: roomTypeController,
                decoration: const InputDecoration(
                    labelText: 'Room Type (classroom, lab, etc.)'),
              ),
              TextField(
                controller: capacityController,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService.createRoomFromMap({
                  'name': nameController.text,
                  'room_number': roomNumberController.text,
                  'floor': int.parse(floorController.text),
                  'room_type': roomTypeController.text,
                  'capacity': int.parse(capacityController.text),
                  'x_coordinate': 0.0,
                  'y_coordinate': 0.0,
                });
                Navigator.pop(context);
                _showSuccess('Room added successfully');
                await _loadAllData();
              } catch (e) {
                _showError('Failed to add room: $e');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddBranchDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Branch Name'),
            ),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Branch Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService.createBranch({
                  'name': nameController.text,
                  'code': codeController.text,
                });
                Navigator.pop(context);
                _showSuccess('Branch added successfully');
                await _loadAllData();
              } catch (e) {
                _showError('Failed to add branch: $e');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showAddPollDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final optionsController = TextEditingController();
    bool isActive = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                      labelText: 'Description (optional)'),
                ),
                TextField(
                  controller: optionsController,
                  decoration: const InputDecoration(
                    labelText: 'Options (comma separated)',
                    hintText: 'Option 1, Option 2, Option 3',
                  ),
                ),
                CheckboxListTile(
                  title: const Text('Active'),
                  value: isActive,
                  onChanged: (v) => setDialogState(() => isActive = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final options = optionsController.text
                      .split(',')
                      .map((e) => e.trim())
                      .toList();
                  await SupabaseService.createPoll(
                    title: titleController.text,
                    description: descriptionController.text.isNotEmpty
                        ? descriptionController.text
                        : null,
                    createdBy: 'admin',
                    options: options,
                  );
                  Navigator.pop(context);
                  _showSuccess('Poll added successfully');
                  await _loadAllData();
                } catch (e) {
                  _showError('Failed to add poll: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubjectDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final semesterController = TextEditingController();
    final creditsController = TextEditingController(text: '3');
    String? selectedBranchId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                ),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Subject Code'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBranchId = v),
                ),
                TextField(
                  controller: semesterController,
                  decoration:
                      const InputDecoration(labelText: 'Semester (1-8)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: creditsController,
                  decoration: const InputDecoration(labelText: 'Credits'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseService.createSubject({
                    'name': nameController.text,
                    'code': codeController.text,
                    'branch_id': selectedBranchId,
                    'semester': int.parse(semesterController.text),
                    'credits': int.parse(creditsController.text),
                  });
                  Navigator.pop(context);
                  _showSuccess('Subject added successfully');
                  await _loadAllData();
                } catch (e) {
                  _showError('Failed to add subject: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Edit Dialogs
  void _showEditRoomDialog(Room room) {
    final nameController = TextEditingController(text: room.name);
    final roomNumberController = TextEditingController(text: room.roomNumber);
    final floorController = TextEditingController(text: room.floor.toString());
    final roomTypeController = TextEditingController(text: room.roomType);
    final capacityController =
        TextEditingController(text: room.capacity.toString());
    final displayNameController =
        TextEditingController(text: room.displayName ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Room Name'),
              ),
              TextField(
                controller: roomNumberController,
                decoration: const InputDecoration(labelText: 'Room Number'),
              ),
              TextField(
                controller: floorController,
                decoration: const InputDecoration(labelText: 'Floor'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: roomTypeController,
                decoration: const InputDecoration(labelText: 'Room Type'),
              ),
              TextField(
                controller: capacityController,
                decoration: const InputDecoration(labelText: 'Capacity'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: displayNameController,
                decoration:
                    const InputDecoration(labelText: 'Display Name (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService.updateRoomFromMap(room.id, {
                  'name': nameController.text,
                  'room_number': roomNumberController.text,
                  'floor': int.parse(floorController.text),
                  'room_type': roomTypeController.text,
                  'capacity': int.parse(capacityController.text),
                  'display_name': displayNameController.text.isNotEmpty
                      ? displayNameController.text
                      : null,
                });
                Navigator.pop(context);
                _showSuccess('Room updated successfully');
                await _loadAllData();
              } catch (e) {
                _showError('Failed to update room: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditBranchDialog(Branch branch) {
    final nameController = TextEditingController(text: branch.name);
    final codeController = TextEditingController(text: branch.code);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Branch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Branch Name'),
            ),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: 'Branch Code'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await SupabaseService.updateBranch(branch.id, {
                  'name': nameController.text,
                  'code': codeController.text,
                });
                Navigator.pop(context);
                _showSuccess('Branch updated successfully');
                await _loadAllData();
              } catch (e) {
                _showError('Failed to update branch: $e');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditSubjectDialog(Subject subject) {
    final nameController = TextEditingController(text: subject.name);
    final codeController = TextEditingController(text: subject.code);
    final semesterController =
        TextEditingController(text: subject.semester.toString());
    final creditsController =
        TextEditingController(text: subject.credits.toString());
    String? selectedBranchId = subject.branchId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Subject'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Subject Name'),
                ),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Subject Code'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: selectedBranchId,
                  decoration: const InputDecoration(labelText: 'Branch'),
                  items: _branches
                      .map((b) =>
                          DropdownMenuItem(value: b.id, child: Text(b.name)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedBranchId = v),
                ),
                TextField(
                  controller: semesterController,
                  decoration: const InputDecoration(labelText: 'Semester'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: creditsController,
                  decoration: const InputDecoration(labelText: 'Credits'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseService.updateSubject(subject.id, {
                    'name': nameController.text,
                    'code': codeController.text,
                    'branch_id': selectedBranchId,
                    'semester': int.parse(semesterController.text),
                    'credits': int.parse(creditsController.text),
                  });
                  Navigator.pop(context);
                  _showSuccess('Subject updated successfully');
                  await _loadAllData();
                } catch (e) {
                  _showError('Failed to update subject: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  // Timetable Tab
  Widget _buildTimetableTab() {
    // Group entries by day
    final groupedEntries = <int, List<TimetableEntry>>{};
    for (final entry in _timetableEntries) {
      groupedEntries.putIfAbsent(entry.dayOfWeek, () => []).add(entry);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      itemBuilder: (context, dayIndex) {
        final dayEntries = groupedEntries[dayIndex] ?? [];
        final dayName = AppConstants.daysOfWeek[dayIndex];

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            title: Text(
              dayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${dayEntries.length} entries'),
            children: dayEntries.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No classes scheduled'),
                    )
                  ]
                : dayEntries.map((entry) {
                    final subjectName =
                        entry.subject?.name ?? entry.breakName ?? 'Unknown';
                    final teacherName = entry.teacher?.name ?? '-';
                    final roomName = entry.room?.effectiveName ?? '-';
                    final branchName = _getBranchName(entry.branchId);

                    return ListTile(
                      dense: true,
                      title: Text(
                        '${entry.startTime.substring(0, 5)} - ${entry.endTime.substring(0, 5)}: $subjectName',
                        style: TextStyle(
                          color: entry.isBreak ? Colors.orange : null,
                        ),
                      ),
                      subtitle: Text(
                        '$branchName Sem-${entry.semester} | $teacherName | $roomName${entry.batch != null ? ' (${entry.batch})' : ''}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            _handleTimetableAction(value, entry),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                          const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  }).toList(),
          ),
        );
      },
    );
  }

  Future<void> _handleTimetableAction(
      String action, TimetableEntry entry) async {
    try {
      switch (action) {
        case 'edit':
          _showEditTimetableDialog(entry);
          break;
        case 'delete':
          final confirm = await _showConfirmDialog(
              'Delete Entry', 'Are you sure you want to delete this entry?');
          if (confirm == true) {
            await SupabaseService.deleteTimetableEntry(entry.id);
            _showSuccess('Timetable entry deleted');
            await _loadAllData();
          }
          break;
      }
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  void _showAddTimetableDialog() {
    String? selectedBranchId;
    String? selectedSubjectId;
    String? selectedTeacherId;
    String? selectedRoomId;
    int semester = 1;
    int dayOfWeek = 1;
    int periodNumber = 1;
    String startTime = '09:00';
    String endTime = '10:00';
    String? batch;
    bool isBreak = false;
    String? breakName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Timetable Entry'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Is Break/Free Period'),
                    value: isBreak,
                    onChanged: (v) =>
                        setDialogState(() => isBreak = v ?? false),
                  ),
                  if (isBreak)
                    TextField(
                      decoration:
                          const InputDecoration(labelText: 'Break Name'),
                      onChanged: (v) => breakName = v,
                    ),
                  if (!isBreak) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedBranchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: _branches
                          .map((b) => DropdownMenuItem(
                              value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedBranchId = v),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: semester,
                      decoration: const InputDecoration(labelText: 'Semester'),
                      items: List.generate(8, (i) => i + 1)
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text('Sem $s')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => semester = v ?? 1),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: _subjects
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedSubjectId = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Teacher'),
                      items: _teachers
                          .map((t) => DropdownMenuItem(
                              value: t.id, child: Text(t.name)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedTeacherId = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoomId,
                      decoration: const InputDecoration(labelText: 'Room'),
                      items: _rooms
                          .map((r) => DropdownMenuItem(
                              value: r.id,
                              child:
                                  Text('${r.effectiveName} (${r.roomNumber})')))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedRoomId = v),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Batch (optional)', hintText: 'B1, B2'),
                      onChanged: (v) => batch = v.isEmpty ? null : v,
                    ),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: dayOfWeek,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: List.generate(7, (i) => i)
                        .map((d) => DropdownMenuItem(
                            value: d, child: Text(AppConstants.daysOfWeek[d])))
                        .toList(),
                    onChanged: (v) => setDialogState(() => dayOfWeek = v ?? 1),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: periodNumber,
                    decoration:
                        const InputDecoration(labelText: 'Period Number'),
                    items: List.generate(12, (i) => i + 1)
                        .map((p) => DropdownMenuItem(
                            value: p, child: Text('Period $p')))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => periodNumber = v ?? 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration:
                              const InputDecoration(labelText: 'Start Time'),
                          controller: TextEditingController(text: startTime),
                          onChanged: (v) => startTime = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration:
                              const InputDecoration(labelText: 'End Time'),
                          controller: TextEditingController(text: endTime),
                          onChanged: (v) => endTime = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseService.createTimetableEntry({
                    'branch_id': selectedBranchId,
                    'semester': semester,
                    'day_of_week': dayOfWeek,
                    'period_number': periodNumber,
                    'subject_id': isBreak ? null : selectedSubjectId,
                    'teacher_id': isBreak ? null : selectedTeacherId,
                    'room_id': isBreak ? null : selectedRoomId,
                    'start_time': startTime,
                    'end_time': endTime,
                    'is_break': isBreak,
                    'break_name': isBreak ? breakName : null,
                    'batch': batch,
                  });
                  Navigator.pop(context);
                  _showSuccess('Timetable entry added successfully');
                  await _loadAllData();
                } catch (e) {
                  _showError('Failed to add timetable entry: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTimetableDialog(TimetableEntry entry) {
    String? selectedBranchId = entry.branchId;
    String? selectedSubjectId = entry.subjectId;
    String? selectedTeacherId = entry.teacherId;
    String? selectedRoomId = entry.roomId;
    int semester = entry.semester;
    int dayOfWeek = entry.dayOfWeek;
    int periodNumber = entry.periodNumber;
    String startTime = entry.startTime;
    String endTime = entry.endTime;
    String? batch = entry.batch;
    bool isBreak = entry.isBreak;
    String? breakName = entry.breakName;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Timetable Entry'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    title: const Text('Is Break/Free Period'),
                    value: isBreak,
                    onChanged: (v) =>
                        setDialogState(() => isBreak = v ?? false),
                  ),
                  if (isBreak)
                    TextField(
                      decoration:
                          const InputDecoration(labelText: 'Break Name'),
                      controller: TextEditingController(text: breakName ?? ''),
                      onChanged: (v) => breakName = v,
                    ),
                  if (!isBreak) ...[
                    DropdownButtonFormField<String>(
                      initialValue: selectedBranchId,
                      decoration: const InputDecoration(labelText: 'Branch'),
                      items: _branches
                          .map((b) => DropdownMenuItem(
                              value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedBranchId = v),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: semester,
                      decoration: const InputDecoration(labelText: 'Semester'),
                      items: List.generate(8, (i) => i + 1)
                          .map((s) =>
                              DropdownMenuItem(value: s, child: Text('Sem $s')))
                          .toList(),
                      onChanged: (v) => setDialogState(() => semester = v ?? 1),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSubjectId,
                      decoration: const InputDecoration(labelText: 'Subject'),
                      items: _subjects
                          .map((s) => DropdownMenuItem(
                              value: s.id, child: Text(s.name)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedSubjectId = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedTeacherId,
                      decoration: const InputDecoration(labelText: 'Teacher'),
                      items: _teachers
                          .map((t) => DropdownMenuItem(
                              value: t.id, child: Text(t.name)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedTeacherId = v),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRoomId,
                      decoration: const InputDecoration(labelText: 'Room'),
                      items: _rooms
                          .map((r) => DropdownMenuItem(
                              value: r.id,
                              child:
                                  Text('${r.effectiveName} (${r.roomNumber})')))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedRoomId = v),
                    ),
                    TextField(
                      decoration: const InputDecoration(
                          labelText: 'Batch (optional)', hintText: 'B1, B2'),
                      controller: TextEditingController(text: batch ?? ''),
                      onChanged: (v) => batch = v.isEmpty ? null : v,
                    ),
                  ],
                  DropdownButtonFormField<int>(
                    initialValue: dayOfWeek,
                    decoration: const InputDecoration(labelText: 'Day'),
                    items: List.generate(7, (i) => i)
                        .map((d) => DropdownMenuItem(
                            value: d, child: Text(AppConstants.daysOfWeek[d])))
                        .toList(),
                    onChanged: (v) => setDialogState(() => dayOfWeek = v ?? 1),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: periodNumber,
                    decoration:
                        const InputDecoration(labelText: 'Period Number'),
                    items: List.generate(12, (i) => i + 1)
                        .map((p) => DropdownMenuItem(
                            value: p, child: Text('Period $p')))
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => periodNumber = v ?? 1),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration:
                              const InputDecoration(labelText: 'Start Time'),
                          controller: TextEditingController(text: startTime),
                          onChanged: (v) => startTime = v,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          decoration:
                              const InputDecoration(labelText: 'End Time'),
                          controller: TextEditingController(text: endTime),
                          onChanged: (v) => endTime = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await SupabaseService.updateTimetableEntry(entry.id, {
                    'branch_id': selectedBranchId,
                    'semester': semester,
                    'day_of_week': dayOfWeek,
                    'period_number': periodNumber,
                    'subject_id': isBreak ? null : selectedSubjectId,
                    'teacher_id': isBreak ? null : selectedTeacherId,
                    'room_id': isBreak ? null : selectedRoomId,
                    'start_time': startTime,
                    'end_time': endTime,
                    'is_break': isBreak,
                    'break_name': isBreak ? breakName : null,
                    'batch': batch,
                  });
                  Navigator.pop(context);
                  _showSuccess('Timetable entry updated successfully');
                  await _loadAllData();
                } catch (e) {
                  _showError('Failed to update timetable entry: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
