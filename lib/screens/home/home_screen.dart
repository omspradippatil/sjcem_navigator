import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/teacher_location_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../services/offline_cache_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/animations.dart';
import '../auth/login_screen.dart';
import '../navigation/navigation_screen.dart';
import '../timetable/timetable_screen.dart';
import '../chat/branch_chat_screen.dart';
import '../chat/private_chat_list_screen.dart';
import '../polls/polls_screen.dart';
import '../teacher/teacher_location_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../study_materials/study_materials_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fabAnimationController;
  late AnimationController _navBarAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _navBarSlideAnimation;

  /// Check if any provider is in offline mode
  bool _isOfflineMode() {
    final timetableProvider = context.read<TimetableProvider>();
    final teacherLocationProvider = context.read<TeacherLocationProvider>();

    return timetableProvider.isOfflineMode ||
        teacherLocationProvider.isOfflineMode ||
        OfflineCacheService.isOffline;
  }

  @override
  void initState() {
    super.initState();
    _initializeTeacherLocation();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: AnimationDurations.mediumLong,
    );

    _navBarAnimationController = AnimationController(
      vsync: this,
      duration: AnimationDurations.long,
    );

    // Use spring curve for premium feel
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: AnimationCurves.bounce,
      ),
    );

    _navBarSlideAnimation = Tween<double>(begin: 80.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _navBarAnimationController,
        curve: AnimationCurves.emphasizedDecelerate,
      ),
    );

    // Start animations with slight delay for premium entrance
    Future.delayed(AnimationDurations.short, () {
      if (mounted) {
        _navBarAnimationController.forward();
        Future.delayed(AnimationDurations.short, () {
          if (mounted) _fabAnimationController.forward();
        });
      }
    });
  }

  /// Auto-update teacher location based on timetable
  Future<void> _initializeTeacherLocation() async {
    final authProvider = context.read<AuthProvider>();

    if (authProvider.isTeacher && authProvider.currentTeacher != null) {
      final locationProvider = context.read<TeacherLocationProvider>();

      // Start auto-location updates based on timetable
      locationProvider.startAutoLocationUpdate(authProvider.currentTeacher!.id);
    }
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _navBarAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Build navigation items based on user type
    final List<Widget> screens = [
      const NavigationScreen(),
      // Guest info screen with login button
      _buildGuestInfoScreen(),
    ];

    final List<_NavItem> navItems = [
      _NavItem(
        icon: Icons.navigation_outlined,
        activeIcon: Icons.navigation,
        label: 'Navigate',
        gradient: AppGradients.primary,
      ),
      _NavItem(
        icon: Icons.info_outlined,
        activeIcon: Icons.info,
        label: 'Info',
        gradient: AppGradients.secondary,
      ),
    ];

    // Track if FAB should be visible (hidden on chat tab to avoid overlap)
    bool showFab = authProvider.isStudent;
    int? chatTabIndex;

    if (!authProvider.isGuest) {
      // Remove the info screen added for guests
      screens.removeAt(1);
      navItems.removeAt(1);

      screens.add(const TimetableScreen());
      navItems.add(_NavItem(
        icon: Icons.schedule_outlined,
        activeIcon: Icons.schedule,
        label: 'Timetable',
        gradient: AppGradients.info,
      ));

      screens.add(const TeacherLocationScreen());
      navItems.add(_NavItem(
        icon: Icons.location_on_outlined,
        activeIcon: Icons.location_on,
        label: 'Teachers',
        gradient: AppGradients.success,
      ));

      // Show chat for students with branch OR teachers/admins
      // Track chat index for FAB visibility
      if (authProvider.currentBranchId != null ||
          authProvider.isTeacher ||
          authProvider.isAdmin) {
        chatTabIndex = screens.length;
        screens.add(const BranchChatScreen());
        navItems.add(_NavItem(
          icon: Icons.chat_bubble_outline,
          activeIcon: Icons.chat_bubble,
          label: 'Chat',
          gradient: AppGradients.accent,
        ));
      }

      // Hide FAB on chat tab to avoid overlap with send button
      showFab = authProvider.isStudent && _currentIndex != chatTabIndex;

      screens.add(const PollsScreen());
      navItems.add(_NavItem(
        icon: Icons.poll_outlined,
        activeIcon: Icons.poll,
        label: 'Polls',
        gradient: AppGradients.warning,
      ));

      // Study materials for all logged-in users
      screens.add(const StudyMaterialsScreen());
      navItems.add(_NavItem(
        icon: Icons.folder_outlined,
        activeIcon: Icons.folder,
        label: 'Notes',
        gradient: AppGradients.primarySubtle,
      ));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        extendBody: true,
        extendBodyBehindAppBar: true,
        appBar: _buildGlassmorphicAppBar(authProvider),
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    AppColors.primaryMid,
                    AppColors.primaryLight,
                  ],
                ),
              ),
            ),
            // Decorative shapes
            Positioned(
              top: -50,
              right: -80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gradientStart.withValues(alpha: 0.2),
                      AppColors.gradientStart.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 100,
              left: -50,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.15),
                      AppColors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Main content - wrapped in RepaintBoundary for performance
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top +
                    70, // Status bar + AppBar
                bottom: 100, // Space for floating nav bar
              ),
              child: RepaintBoundary(
                child: IndexedStack(
                  index: _currentIndex,
                  children: screens
                      .map((screen) => RepaintBoundary(child: screen))
                      .toList(),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedBuilder(
          animation: _navBarSlideAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _navBarSlideAnimation.value),
              child: _buildPremiumBottomNavBar(navItems),
            );
          },
        ),
        floatingActionButton: showFab
            ? ScaleTransition(
                scale: _fabScaleAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppGradients.accent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        SlidePageRoute(
                          page: const PrivateChatListScreen(),
                        ),
                      );
                    },
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    child:
                        const Icon(Icons.message_rounded, color: Colors.white),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildGuestInfoScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: AppGradients.secondary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.3),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.lock_open_rounded,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Unlock Full Features',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '• View timetable\n• Chat with classmates\n• Find teachers\n• Participate in polls',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: AppGradients.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientStart.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  SlidePageRoute(page: const LoginScreen()),
                );
              },
              icon: const Icon(Icons.login_rounded, color: Colors.white),
              label: const Text('Login / Sign Up',
                  style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildGlassmorphicAppBar(AuthProvider authProvider) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.4),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Logo and Title
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppGradients.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Colors.white, AppColors.accentLight],
                          ).createShader(bounds),
                          child: const Text(
                            'SJCEM Navigator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              authProvider.isGuest
                                  ? 'Guest Mode'
                                  : 'Welcome back!',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            // Offline indicator
                            if (_isOfflineMode()) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cloud_off_rounded,
                                      size: 10,
                                      color: AppColors.warning,
                                    ),
                                    SizedBox(width: 3),
                                    Text(
                                      'Offline',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Action buttons
                    if (authProvider.isAdmin)
                      _buildAppBarButton(
                        icon: Icons.admin_panel_settings,
                        onTap: () {
                          Navigator.of(context).push(
                            SlidePageRoute(page: const AdminPanelScreen()),
                          );
                        },
                      ),
                    const SizedBox(width: 8),
                    // Profile avatar
                    _buildProfileAvatar(authProvider),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarButton(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Icon(icon, color: Colors.white70, size: 20),
      ),
    );
  }

  Widget _buildProfileAvatar(AuthProvider authProvider) {
    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuSelection(value, authProvider),
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surface,
      itemBuilder: (context) => [
        _buildPopupMenuItem('profile', Icons.person_outline, 'Profile'),
        if (authProvider.isAdmin || authProvider.isHod)
          _buildPopupMenuItem(
              'admin', Icons.admin_panel_settings, 'Admin Panel'),
        const PopupMenuDivider(),
        if (!authProvider.isGuest)
          _buildPopupMenuItem('logout', Icons.logout, 'Logout',
              isDestructive: true)
        else
          _buildPopupMenuItem('logout', Icons.login, 'Login',
              isHighlighted: true),
      ],
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          gradient: AppGradients.primary,
          shape: BoxShape.circle,
        ),
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surface,
          child: Text(
            authProvider.currentUserName.isNotEmpty
                ? authProvider.currentUserName[0].toUpperCase()
                : 'G',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupMenuItem(
      String value, IconData icon, String title,
      {bool isDestructive = false, bool isHighlighted = false}) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDestructive
                ? AppColors.error
                : isHighlighted
                    ? AppColors.accent
                    : Colors.white70,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: isDestructive
                  ? AppColors.error
                  : isHighlighted
                      ? AppColors.accent
                      : Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuSelection(
      String value, AuthProvider authProvider) async {
    if (value == 'logout') {
      try {
        final navProvider = context.read<NavigationProvider>();
        final locationProvider = context.read<TeacherLocationProvider>();

        navProvider.stopSensors();
        locationProvider.unsubscribeFromLocationUpdates();

        await authProvider.logout();
      } catch (e) {
        debugPrint('Logout cleanup error: $e');
      }
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          SlidePageRoute(page: const LoginScreen()),
          (route) => false,
        );
      }
    } else if (value == 'profile') {
      _showProfileDialog();
    } else if (value == 'admin') {
      Navigator.of(context).push(
        SlidePageRoute(page: const AdminPanelScreen()),
      );
    }
  }

  Widget _buildPremiumBottomNavBar(List<_NavItem> navItems) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(navItems.length, (index) {
                final isSelected = _currentIndex == index;
                return _buildNavItem(navItems[index], isSelected, index);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, bool isSelected, int index) {
    return GestureDetector(
      onTap: () {
        if (_currentIndex != index) {
          HapticFeedback.selectionClick();
          setState(() => _currentIndex = index);
        }
      },
      child: AnimatedContainer(
        duration: AnimationDurations.mediumShort,
        curve: AnimationCurves.emphasized,
        clipBehavior: Clip.antiAlias,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 16 : 12,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? item.gradient : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gradientStart.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AnimationDurations.short,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: child,
                );
              },
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                key: ValueKey(isSelected),
                color: isSelected ? Colors.white : Colors.white54,
                size: 22,
              ),
            ),
            AnimatedSize(
              duration: AnimationDurations.mediumShort,
              curve: AnimationCurves.emphasized,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.centerLeft,
              child: isSelected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        item.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.0,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfileDialog() {
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header gradient line
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Avatar with gradient border
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 45,
                      backgroundColor: AppColors.surface,
                      child: Text(
                        authProvider.currentUserName.isNotEmpty
                            ? authProvider.currentUserName[0].toUpperCase()
                            : 'G',
                        style: const TextStyle(
                          fontSize: 36,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.white, AppColors.accentLight],
                    ).createShader(bounds),
                    child: Text(
                      authProvider.currentUserName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: AppGradients.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      authProvider.userType.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Profile info cards
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        if (authProvider.isStudent) ...[
                          _buildProfileInfoRow(
                            Icons.badge_outlined,
                            'Roll Number',
                            authProvider.currentStudent?.rollNumber ?? 'N/A',
                          ),
                          _buildDivider(),
                          _buildProfileInfoRow(
                            Icons.school_outlined,
                            'Semester',
                            '${authProvider.currentStudent?.semester ?? 'N/A'}',
                          ),
                          _buildDivider(),
                          _buildProfileInfoRow(
                            Icons.fingerprint,
                            'Anonymous ID',
                            authProvider.currentStudent?.anonymousId ?? 'N/A',
                          ),
                        ],
                        if (authProvider.isTeacher) ...[
                          _buildProfileInfoRow(
                            Icons.phone_outlined,
                            'Phone',
                            authProvider.currentTeacher?.phone ?? 'Not set',
                          ),
                          if (authProvider.isHod) ...[
                            _buildDivider(),
                            _buildProfileInfoRow(
                              Icons.workspace_premium,
                              'Role',
                              'Head of Department',
                            ),
                          ],
                          if (authProvider.isAdmin) ...[
                            _buildDivider(),
                            _buildProfileInfoRow(
                              Icons.admin_panel_settings,
                              'Role',
                              'Administrator',
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.edit_outlined,
                          label: 'Edit Profile',
                          onTap: () {
                            Navigator.of(context).pop();
                            _showEditProfileDialog();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.lock_outline,
                          label: 'Password',
                          onTap: () {
                            Navigator.of(context).pop();
                            _showChangePasswordDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontWeight: FontWeight.w600),
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
  }

  Widget _buildProfileInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog() {
    final authProvider = context.read<AuthProvider>();
    final nameController = TextEditingController(
      text: authProvider.currentUserName,
    );
    final phoneController = TextEditingController(
      text: authProvider.isStudent
          ? authProvider.currentStudent?.phone ?? ''
          : authProvider.currentTeacher?.phone ?? '',
    );
    final semesterController = TextEditingController(
      text: authProvider.isStudent
          ? authProvider.currentStudent?.semester.toString() ?? ''
          : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.edit_outlined,
                            size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildEditField(
                    controller: nameController,
                    label: 'Name',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildEditField(
                    controller: phoneController,
                    label: 'Phone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),
                  if (authProvider.isStudent) ...[
                    const SizedBox(height: 16),
                    _buildEditField(
                      controller: semesterController,
                      label: 'Semester',
                      icon: Icons.school_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppGradients.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final phone = phoneController.text.trim();
                              final semester =
                                  int.tryParse(semesterController.text.trim());

                              bool success;
                              if (authProvider.isStudent) {
                                success =
                                    await authProvider.updateStudentProfile(
                                  name: name.isNotEmpty ? name : null,
                                  phone: phone.isNotEmpty ? phone : null,
                                  semester: semester,
                                );
                              } else {
                                success =
                                    await authProvider.updateTeacherProfile(
                                  name: name.isNotEmpty ? name : null,
                                  phone: phone.isNotEmpty ? phone : null,
                                );
                              }

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (mounted) {
                                if (success) {
                                  PremiumSnackBar.show(
                                      context: context,
                                      message: 'Profile updated successfully',
                                      type: SnackBarType.success);
                                } else {
                                  PremiumSnackBar.showError(
                                      context, 'Failed to update profile');
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white),
                            child: const Text('Save'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 20, color: AppColors.accent),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  void _showChangePasswordDialog() {
    final authProvider = context.read<AuthProvider>();
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AppGradients.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.lock_outline,
                            size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Change Password',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildPasswordField(
                    controller: currentPasswordController,
                    label: 'Current Password',
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: newPasswordController,
                    label: 'New Password',
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    controller: confirmPasswordController,
                    label: 'Confirm Password',
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppGradients.accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextButton(
                            onPressed: () async {
                              final currentPassword =
                                  currentPasswordController.text;
                              final newPassword = newPasswordController.text;
                              final confirmPassword =
                                  confirmPasswordController.text;

                              if (currentPassword.isEmpty ||
                                  newPassword.isEmpty) {
                                PremiumSnackBar.showError(
                                    context, 'Please fill all fields');
                                return;
                              }

                              if (newPassword.length < 6) {
                                PremiumSnackBar.showError(context,
                                    'Password must be at least 6 characters');
                                return;
                              }

                              if (newPassword != confirmPassword) {
                                PremiumSnackBar.showError(
                                    context, 'Passwords do not match');
                                return;
                              }

                              final success = await authProvider.changePassword(
                                currentPassword,
                                newPassword,
                              );

                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              if (mounted) {
                                if (success) {
                                  PremiumSnackBar.show(
                                      context: context,
                                      message: 'Password changed successfully',
                                      type: SnackBarType.success);
                                } else {
                                  PremiumSnackBar.showError(
                                      context,
                                      authProvider.error ??
                                          'Failed to change password');
                                }
                              }
                            },
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white),
                            child: const Text('Change'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.key, size: 20, color: AppColors.accent),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// Navigation item model
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final LinearGradient gradient;

  _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.gradient,
  });
}
