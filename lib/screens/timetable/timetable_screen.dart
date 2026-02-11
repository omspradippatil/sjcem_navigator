import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/constants.dart';
import '../../utils/animations.dart';
import '../../utils/app_theme.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedDay = DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 7, vsync: this, initialIndex: _selectedDay);
    _loadTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    PremiumSnackBar.showError(context, message);
  }

  Future<void> _loadTimetable() async {
    try {
      final authProvider = context.read<AuthProvider>();
      final timetableProvider = context.read<TimetableProvider>();

      if (authProvider.isStudent && authProvider.currentStudent != null) {
        await timetableProvider.loadTodayTimetable(
          branchId: authProvider.currentStudent!.branchId!,
          semester: authProvider.currentStudent!.semester,
        );
        await timetableProvider.loadWeekTimetable(
          branchId: authProvider.currentStudent!.branchId!,
          semester: authProvider.currentStudent!.semester,
        );
      } else if (authProvider.isTeacher &&
          authProvider.currentTeacher != null) {
        // Load teacher's own timetable
        await timetableProvider.loadTeacherTimetable(
          teacherId: authProvider.currentTeacher!.id,
        );
      }

      // Show error if loading failed
      if (timetableProvider.error != null && mounted) {
        _showErrorSnackBar(timetableProvider.error!);
      }
    } catch (e) {
      debugPrint('Error loading timetable: $e');
      if (mounted) {
        _showErrorSnackBar('Failed to load timetable. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetableProvider = context.watch<TimetableProvider>();
    final authProvider = context.watch<AuthProvider>();

    return SafeArea(
      top: false, // Parent handles top padding
      bottom: false, // Parent handles bottom padding
      child: Column(
        children: [
          // Current/Next Class Card
          if (authProvider.isStudent)
            _buildPremiumCurrentClassCard(timetableProvider),
          if (authProvider.isTeacher)
            _buildPremiumTeacherCard(timetableProvider),

          // Offline mode indicator
          if (timetableProvider.isOfflineMode)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 16,
                    color: AppColors.warning.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Showing cached timetable. Connect to update.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Premium Day Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    indicator: BoxDecoration(
                      gradient: AppGradients.primarySubtle,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                    tabs: AppConstants.daysOfWeek.map((day) {
                      final isToday = AppConstants.daysOfWeek.indexOf(day) ==
                          DateTime.now().weekday % 7;
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isToday) ...[
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(day.substring(0, 3)),
                          ],
                        ),
                      );
                    }).toList(),
                    onTap: (index) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedDay = index;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),

          // Timetable List
          Expanded(
            child: timetableProvider.isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            gradient: AppGradients.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading timetable...',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: List.generate(7, (dayIndex) {
                      final entries =
                          timetableProvider.getTimetableForDay(dayIndex);

                      if (entries.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight
                                      .withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  dayIndex == 0
                                      ? Icons.weekend
                                      : Icons.event_busy,
                                  size: 40,
                                  color: Colors.white38,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                dayIndex == 0
                                    ? 'Sunday - Holiday!'
                                    : 'No classes scheduled',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (dayIndex == 0)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Enjoy your day off!',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        itemBuilder: (context, index) {
                          return AnimatedListItem(
                            index: index,
                            child: _buildPremiumPeriodCard(entries[index]),
                          );
                        },
                      );
                    }),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCurrentClassCard(TimetableProvider timetableProvider) {
    final currentPeriod = timetableProvider.currentPeriod;
    final nextPeriod = timetableProvider.nextPeriod;

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: currentPeriod != null
                  ? AppGradients.primary
                  : nextPeriod != null
                      ? AppGradients.secondary
                      : AppGradients.success,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gradientStart.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.calendar_today,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          timetableProvider.todayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DateFormat.yMMMd().format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (currentPeriod != null) ...[
                  _buildCurrentPeriodContent(currentPeriod, timetableProvider),
                ] else if (nextPeriod != null) ...[
                  _buildNextPeriodContent(nextPeriod, timetableProvider),
                ] else ...[
                  _buildNoClassesContent(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPeriodContent(
      TimetableEntry currentPeriod, TimetableProvider timetableProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'CURRENT CLASS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          currentPeriod.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildInfoChip(
                Icons.room_outlined, currentPeriod.room?.roomNumber ?? 'TBA'),
            const SizedBox(width: 10),
            _buildInfoChip(
                Icons.person_outlined, currentPeriod.teacher?.name ?? 'TBA'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Ends in: ${timetableProvider.formatDuration(timetableProvider.timeRemaining)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextPeriodContent(
      TimetableEntry nextPeriod, TimetableProvider timetableProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            nextPeriod.isBreak ? 'NEXT BREAK' : 'NEXT CLASS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          nextPeriod.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            if (!nextPeriod.isBreak)
              _buildInfoChip(
                  Icons.room_outlined, nextPeriod.room?.roomNumber ?? 'TBA'),
            if (!nextPeriod.isBreak) const SizedBox(width: 10),
            _buildInfoChip(Icons.access_time, nextPeriod.formattedTime),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Starts in: ${timetableProvider.formatDuration(timetableProvider.timeUntilNext)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (nextPeriod.room != null && !nextPeriod.isBreak) ...[
              const SizedBox(width: 10),
              _buildNavigateButton(nextPeriod.room!),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNoClassesContent() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline,
                color: Colors.white, size: 40),
          ),
          const SizedBox(height: 12),
          const Text(
            'No more classes today!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enjoy your free time',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigateButton(Room room) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        context.read<NavigationProvider>().navigateToRoom(room);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.navigation_rounded,
                color: AppColors.gradientStart, size: 18),
            SizedBox(width: 6),
            Text(
              'Navigate',
              style: TextStyle(
                color: AppColors.gradientStart,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumTeacherCard(TimetableProvider timetableProvider) {
    final currentPeriod = timetableProvider.currentPeriod;
    final nextPeriod = timetableProvider.nextPeriod;

    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppGradients.info,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.info.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school,
                              color: Colors.white, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          timetableProvider.todayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DateFormat.yMMMd().format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (currentPeriod != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'YOU ARE CURRENTLY TEACHING',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentPeriod.subject?.name ?? 'Unknown Subject',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoChip(Icons.room_outlined,
                          currentPeriod.room?.roomNumber ?? 'TBA'),
                      const SizedBox(width: 10),
                      _buildInfoChip(Icons.groups_outlined,
                          currentPeriod.branchName ?? 'Unknown'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Ends in: ${timetableProvider.formatDuration(timetableProvider.timeRemaining)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (currentPeriod.room != null) ...[
                        const SizedBox(width: 10),
                        _buildNavigateButton(currentPeriod.room!),
                      ],
                    ],
                  ),
                ] else if (nextPeriod != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'YOUR NEXT LECTURE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nextPeriod.subject?.name ?? 'Unknown Subject',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoChip(Icons.room_outlined,
                          nextPeriod.room?.roomNumber ?? 'TBA'),
                      const SizedBox(width: 10),
                      _buildInfoChip(Icons.groups_outlined,
                          nextPeriod.branchName ?? 'Unknown'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoChip(Icons.access_time, nextPeriod.formattedTime),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined,
                                  color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Starts in: ${timetableProvider.formatDuration(timetableProvider.timeUntilNext)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (nextPeriod.room != null) ...[
                        const SizedBox(width: 10),
                        _buildNavigateButton(nextPeriod.room!),
                      ],
                    ],
                  ),
                ] else ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.free_breakfast,
                              color: Colors.white, size: 40),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No more lectures today!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumPeriodCard(TimetableEntry entry) {
    final isCurrentPeriod = entry.isCurrentPeriod;
    final isPast = !entry.isCurrentPeriod && !entry.isUpcoming;
    final isBreak = entry.isBreak;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            decoration: BoxDecoration(
              gradient: isBreak
                  ? LinearGradient(
                      colors: [
                        AppColors.warning.withValues(alpha: 0.3),
                        AppColors.warning.withValues(alpha: 0.1),
                      ],
                    )
                  : isCurrentPeriod
                      ? AppGradients.primarySubtle
                      : null,
              color: isBreak || isCurrentPeriod
                  ? null
                  : AppColors.surface.withValues(alpha: isPast ? 0.3 : 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCurrentPeriod
                    ? AppColors.gradientStart.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: !isBreak && entry.teacher?.phone != null
                    ? () => _showPremiumTeacherInfo(entry)
                    : null,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Period Number & Time
                      Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: isBreak
                                  ? AppGradients.warning
                                  : isCurrentPeriod
                                      ? AppGradients.primary
                                      : null,
                              color: isBreak || isCurrentPeriod
                                  ? null
                                  : AppColors.surfaceLight
                                      .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: isBreak
                                  ? const Icon(Icons.free_breakfast,
                                      color: Colors.white, size: 20)
                                  : Text(
                                      '${entry.periodNumber}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: isCurrentPeriod
                                            ? Colors.white
                                            : isPast
                                                ? Colors.white38
                                                : Colors.white70,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat.jm().format(entry.startDateTime),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isPast ? Colors.white30 : Colors.white60,
                            ),
                          ),
                          Text(
                            DateFormat.jm().format(entry.endDateTime),
                            style: TextStyle(
                              fontSize: 10,
                              color: isPast
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Subject & Teacher Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isBreak
                                    ? AppColors.warning
                                    : isPast
                                        ? Colors.white38
                                        : Colors.white,
                                decoration: isPast && !isBreak
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if (!isBreak) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 14,
                                    color: isPast
                                        ? Colors.white24
                                        : Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      entry.teacher?.name ?? 'TBA',
                                      style: TextStyle(
                                        color: isPast
                                            ? Colors.white24
                                            : Colors.white54,
                                        fontSize: 12,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(
                                    Icons.room_outlined,
                                    size: 14,
                                    color: isPast
                                        ? Colors.white24
                                        : Colors.white54,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    entry.room?.roomNumber ?? 'TBA',
                                    style: TextStyle(
                                      color: isPast
                                          ? Colors.white24
                                          : Colors.white54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Text(
                                'Time to relax!',
                                style: TextStyle(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Status & Navigate Button
                      Column(
                        children: [
                          if (isCurrentPeriod && !isBreak)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppGradients.success,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'NOW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isCurrentPeriod && isBreak)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppGradients.warning,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'BREAK',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (entry.room != null && !isPast && !isBreak)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  context
                                      .read<NavigationProvider>()
                                      .navigateToRoom(entry.room!);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.navigation_rounded,
                                    color: AppColors.accent,
                                    size: 20,
                                  ),
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
        ),
      ),
    );
  }

  void _showPremiumTeacherInfo(TimetableEntry entry) {
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
                color: AppColors.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      gradient: AppGradients.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      gradient: AppGradients.primary,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.surface,
                      child: Text(
                        (entry.teacher?.name ?? 'T')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    entry.teacher?.name ?? 'Teacher',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (entry.teacher?.phone != null)
                    _buildContactRow(
                        Icons.phone, entry.teacher!.phone!, 'Phone'),
                  if (entry.teacher?.email != null)
                    _buildContactRow(
                        Icons.email_outlined, entry.teacher!.email, 'Email'),
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

  Widget _buildContactRow(IconData icon, String value, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
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
}
