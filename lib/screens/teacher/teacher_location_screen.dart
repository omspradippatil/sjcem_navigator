import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_location_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/app_theme.dart';
import '../home/home_screen.dart';

class TeacherLocationScreen extends StatefulWidget {
  const TeacherLocationScreen({super.key});

  @override
  State<TeacherLocationScreen> createState() => _TeacherLocationScreenState();
}

class _TeacherLocationScreenState extends State<TeacherLocationScreen> {
  String _searchQuery = '';
  bool _showOnlyAvailable = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<TeacherLocationProvider>();
    await provider.loadTeacherLocations();
    provider.subscribeToLocationUpdates();
  }

  @override
  void dispose() {
    context.read<TeacherLocationProvider>().unsubscribeFromLocationUpdates();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final locationProvider = context.watch<TeacherLocationProvider>();

    // Filter teachers based on search and availability
    final allTeachers = locationProvider.teacherLocations.values.toList();
    final filteredTeachers = allTeachers.where((teacher) {
      final matchesSearch = _searchQuery.isEmpty ||
          teacher.name.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesAvailable =
          !_showOnlyAvailable || teacher.currentRoomId != null;
      return matchesSearch && matchesAvailable;
    }).toList();

    // Sort: available first, then by name
    filteredTeachers.sort((a, b) {
      if (a.currentRoomId != null && b.currentRoomId == null) return -1;
      if (a.currentRoomId == null && b.currentRoomId != null) return 1;
      return a.name.compareTo(b.name);
    });

    final availableCount =
        allTeachers.where((t) => t.currentRoomId != null).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.dark,
      ),
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppColors.accent,
        backgroundColor: AppColors.cardDark,
        child: CustomScrollView(
          slivers: [
            // Teacher's own location update (for teachers only)
            if (authProvider.isTeacher)
              SliverToBoxAdapter(
                child: _buildPremiumTeacherLocationUpdate(
                    authProvider, locationProvider),
              ),

            // Search and filter bar
            SliverToBoxAdapter(
              child: _buildPremiumSearchBar(availableCount, allTeachers.length),
            ),

            // Stats bar
            SliverToBoxAdapter(
              child: _buildPremiumStatsBar(availableCount, allTeachers.length),
            ),

            // Loading state
            if (locationProvider.isLoading)
              SliverFillRemaining(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: AppGradients.primarySubtle,
                      shape: BoxShape.circle,
                    ),
                    child: const CircularProgressIndicator(
                      color: AppColors.accent,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              )
            else if (filteredTeachers.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final teacher = filteredTeachers[index];
                      final room =
                          locationProvider.getRoomForTeacher(teacher.id);
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) => Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(30 * (1 - value), 0),
                            child: child,
                          ),
                        ),
                        child: _buildPremiumTeacherCard(teacher, room),
                      );
                    },
                    childCount: filteredTeachers.length,
                  ),
                ),
              ),

            // Bottom padding
            const SliverToBoxAdapter(
              child: SizedBox(height: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: AppGradients.primarySubtle,
                shape: BoxShape.circle,
                boxShadow: [AppShadows.glowPrimary],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    AppGradients.primary.createShader(bounds),
                child: Icon(
                  _searchQuery.isNotEmpty
                      ? Icons.search_off_rounded
                      : Icons.location_off_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'No teachers match "$_searchQuery"'
                : _showOnlyAvailable
                    ? 'No teachers are currently available'
                    : 'No teachers have shared their location',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          if (_showOnlyAvailable) ...[
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  _showOnlyAvailable = false;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [AppShadows.glowPrimary],
                ),
                child: const Text(
                  'Show all teachers',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumSearchBar(int available, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // Search field
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.glassDark,
                      AppColors.glassDark.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 1,
                  ),
                ),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search teachers...',
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.7)),
                    prefixIcon: ShaderMask(
                      shaderCallback: (bounds) =>
                          AppGradients.primary.createShader(bounds),
                      child:
                          const Icon(Icons.search_rounded, color: Colors.white),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                color: AppColors.textSecondary),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: false,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _showOnlyAvailable = !_showOnlyAvailable;
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: _showOnlyAvailable ? AppGradients.primary : null,
                    color: _showOnlyAvailable ? null : AppColors.glassDark,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _showOnlyAvailable
                          ? Colors.transparent
                          : AppColors.glassBorder,
                    ),
                    boxShadow:
                        _showOnlyAvailable ? [AppShadows.glowPrimary] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showOnlyAvailable
                            ? Icons.check_circle_rounded
                            : Icons.filter_alt_outlined,
                        size: 16,
                        color: _showOnlyAvailable
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Available Now',
                        style: TextStyle(
                          color: _showOnlyAvailable
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (available > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$available online',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumStatsBar(int available, int total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.glassDark,
                  AppColors.glassDark.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.glassBorder,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPremiumStatItem(
                  Icons.people_rounded,
                  '$total',
                  'Total',
                  AppColors.info,
                ),
                Container(height: 35, width: 1, color: AppColors.glassBorder),
                _buildPremiumStatItem(
                  Icons.location_on_rounded,
                  '$available',
                  'Available',
                  AppColors.success,
                ),
                Container(height: 35, width: 1, color: AppColors.glassBorder),
                _buildPremiumStatItem(
                  Icons.location_off_rounded,
                  '${total - available}',
                  'Away',
                  AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumTeacherLocationUpdate(
    AuthProvider authProvider,
    TeacherLocationProvider locationProvider,
  ) {
    final rooms = locationProvider.getAvailableRooms();
    final currentTeacher = authProvider.currentTeacher;
    final isLocationSet = currentTeacher?.currentRoomId != null;

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient:
                  isLocationSet ? AppGradients.success : AppGradients.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                isLocationSet
                    ? BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      )
                    : AppShadows.glowPrimary,
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isLocationSet
                              ? Icons.check_circle_rounded
                              : Icons.my_location_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Location',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLocationSet
                                  ? 'Students can see your location'
                                  : 'Set your location so students can find you',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isLocationSet)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: DropdownButtonFormField<String?>(
                      initialValue: rooms.any((r) => r.id == currentTeacher?.currentRoomId)
                          ? currentTeacher?.currentRoomId
                          : null,
                      decoration: InputDecoration(
                        labelText: 'Current Room',
                        labelStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        prefixIcon: const Icon(Icons.room_rounded,
                            color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.cardDark,
                      ),
                      dropdownColor: AppColors.cardDark,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                      iconEnabledColor: Colors.white70,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            '🚶 Not in any room / Away',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        ...rooms.map((room) {
                          return DropdownMenuItem(
                            value: room.id,
                            child: Text(
                              '${room.roomNumber} - ${room.name}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          );
                        }),
                      ],
                      onChanged: (roomId) async {
                        HapticFeedback.lightImpact();
                        await locationProvider.updateMyLocation(
                          currentTeacher!.id,
                          roomId,
                        );
                      },
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

  Widget _buildPremiumTeacherCard(Teacher teacher, Room? room) {
    final timeSinceUpdate = teacher.currentRoomUpdatedAt != null
        ? DateTime.now().difference(teacher.currentRoomUpdatedAt!)
        : null;
    final isAvailable = teacher.currentRoomId != null;
    final isRecentUpdate =
        timeSinceUpdate != null && timeSinceUpdate.inMinutes < 30;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAvailable
                    ? [
                        AppColors.success.withValues(alpha: 0.15),
                        AppColors.glassDark,
                      ]
                    : [
                        AppColors.glassDark,
                        AppColors.glassDark.withValues(alpha: 0.7),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isAvailable
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.glassBorder,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: room != null
                    ? () {
                        HapticFeedback.lightImpact();
                        context.read<NavigationProvider>().navigateToRoom(room);
                        PremiumSnackBar.showInfo(
                            context, 'Navigating to ${teacher.name}...');
                        // Switch to navigation tab (index 0 = map)
                        HomeScreen.tabSwitchNotifier.value = 0;
                      }
                    : null,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Avatar with status indicator
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: isAvailable
                                  ? AppGradients.success
                                  : AppGradients.secondary,
                            ),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.cardDark,
                              ),
                              child: Center(
                                child: Text(
                                  teacher.name.isNotEmpty
                                      ? teacher.name[0].toUpperCase()
                                      : 'T',
                                  style: TextStyle(
                                    fontSize: 22,
                                    color: isAvailable
                                        ? AppColors.success
                                        : AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                gradient:
                                    isAvailable ? AppGradients.success : null,
                                color: isAvailable ? null : AppColors.textMuted,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.backgroundDark, width: 2),
                              ),
                              child: isAvailable
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 10,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // Teacher info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    teacher.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.textPrimary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (teacher.isHod) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: AppGradients.warning,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'HOD',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            if (isAvailable && room != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.success
                                        .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 14,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${room.roomNumber} - ${room.name}',
                                        style: const TextStyle(
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Text(
                                '📍 Location not available',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                if (teacher.phone?.isNotEmpty == true) ...[
                                  const Icon(Icons.phone_rounded,
                                      size: 12, color: AppColors.textMuted),
                                  const SizedBox(width: 4),
                                  Text(
                                    teacher.phone!,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                if (timeSinceUpdate != null && isRecentUpdate)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 12,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _formatTimeSince(timeSinceUpdate),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Navigate button
                      if (room != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppGradients.info,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.info.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.navigation_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimeSince(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ago';
    } else {
      return '${duration.inDays}d ago';
    }
  }
}
