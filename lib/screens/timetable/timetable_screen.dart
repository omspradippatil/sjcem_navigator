import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/timetable_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../utils/constants.dart';

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
    _tabController = TabController(length: 7, vsync: this, initialIndex: _selectedDay);
    _loadTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
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
    } else if (authProvider.isTeacher && authProvider.currentTeacher?.branchId != null) {
      // Teachers can view their branch's timetable
      await timetableProvider.loadTodayTimetable(
        branchId: authProvider.currentTeacher!.branchId!,
        semester: 1, // Show first semester by default for teachers
      );
      await timetableProvider.loadWeekTimetable(
        branchId: authProvider.currentTeacher!.branchId!,
        semester: 1,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final timetableProvider = context.watch<TimetableProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Column(
      children: [
        // Current/Next Class Card
        if (authProvider.isStudent)
          _buildCurrentClassCard(timetableProvider),
        
        // Day Tabs
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: AppConstants.daysOfWeek.map((day) {
              final isToday = AppConstants.daysOfWeek.indexOf(day) == 
                  DateTime.now().weekday % 7;
              return Tab(
                child: Text(
                  day.substring(0, 3),
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    color: isToday 
                        ? Theme.of(context).colorScheme.primary 
                        : null,
                  ),
                ),
              );
            }).toList(),
            onTap: (index) {
              setState(() {
                _selectedDay = index;
              });
            },
          ),
        ),
        
        // Timetable List
        Expanded(
          child: timetableProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: List.generate(7, (dayIndex) {
                    final entries = timetableProvider.getTimetableForDay(dayIndex);
                    
                    if (entries.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              dayIndex == 0 
                                  ? Icons.weekend 
                                  : Icons.event_busy,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              dayIndex == 0 
                                  ? 'Sunday - Holiday' 
                                  : 'No classes scheduled',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
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
                        return _buildPeriodCard(entries[index]);
                      },
                    );
                  }),
                ),
        ),
      ],
    );
  }

  Widget _buildCurrentClassCard(TimetableProvider timetableProvider) {
    final currentPeriod = timetableProvider.currentPeriod;
    final nextPeriod = timetableProvider.nextPeriod;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timetableProvider.todayName,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              Text(
                DateFormat.yMMMd().format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (currentPeriod != null) ...[
            const Text(
              'CURRENT CLASS',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              currentPeriod.subject?.name ?? 'Unknown Subject',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.room, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  currentPeriod.room?.roomNumber ?? 'TBA',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.person, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  currentPeriod.teacher?.name ?? 'TBA',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Ends in: ${timetableProvider.formatDuration(timetableProvider.timeRemaining)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ] else if (nextPeriod != null) ...[
            const Text(
              'NEXT CLASS',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextPeriod.subject?.name ?? 'Unknown Subject',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.room, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  nextPeriod.room?.roomNumber ?? 'TBA',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.access_time, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  nextPeriod.formattedTime,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.white70, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Starts in: ${timetableProvider.formatDuration(timetableProvider.timeUntilNext)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (nextPeriod.room != null)
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<NavigationProvider>().navigateToRoom(
                        nextPeriod.room!,
                      );
                      // Switch to navigation tab
                    },
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            const Center(
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.white70, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'No more classes today!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPeriodCard(TimetableEntry entry) {
    final isCurrentPeriod = entry.isCurrentPeriod;
    final isPast = !entry.isCurrentPeriod && !entry.isUpcoming;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isCurrentPeriod
          ? Theme.of(context).colorScheme.primaryContainer
          : isPast
              ? Theme.of(context).colorScheme.surfaceContainerHighest
              : null,
      child: InkWell(
        onTap: entry.teacher?.phone != null
            ? () => _showTeacherInfo(entry)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Period Number & Time
              Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isCurrentPeriod
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${entry.periodNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isCurrentPeriod
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    entry.startTime.substring(0, 5),
                    style: TextStyle(
                      fontSize: 11,
                      color: isPast ? Colors.grey : null,
                    ),
                  ),
                  Text(
                    entry.endTime.substring(0, 5),
                    style: TextStyle(
                      fontSize: 11,
                      color: isPast ? Colors.grey : Colors.grey[600],
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
                      entry.subject?.name ?? 'Unknown Subject',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isPast ? Colors.grey : null,
                        decoration: isPast ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: isPast ? Colors.grey : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.teacher?.name ?? 'TBA',
                          style: TextStyle(
                            color: isPast ? Colors.grey : Colors.grey[600],
                            fontSize: 13,
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
                          color: isPast ? Colors.grey : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          entry.room?.roomNumber ?? 'TBA',
                          style: TextStyle(
                            color: isPast ? Colors.grey : Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Status & Navigate Button
              Column(
                children: [
                  if (isCurrentPeriod)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
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
                  if (entry.room != null && !isPast)
                    IconButton(
                      onPressed: () {
                        context.read<NavigationProvider>().navigateToRoom(
                          entry.room!,
                        );
                      },
                      icon: const Icon(Icons.navigation),
                      tooltip: 'Navigate to room',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTeacherInfo(TimetableEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.teacher?.name ?? 'Teacher'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.teacher?.phone != null)
              ListTile(
                leading: const Icon(Icons.phone),
                title: Text(entry.teacher!.phone!),
                subtitle: const Text('Phone'),
                contentPadding: EdgeInsets.zero,
              ),
            if (entry.teacher?.email != null)
              ListTile(
                leading: const Icon(Icons.email),
                title: Text(entry.teacher!.email),
                subtitle: const Text('Email'),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
