import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_location_provider.dart';
import '../../providers/navigation_provider.dart';

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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Teacher's own location update (for teachers only)
            if (authProvider.isTeacher)
              SliverToBoxAdapter(
                child:
                    _buildTeacherLocationUpdate(authProvider, locationProvider),
              ),

            // Search and filter bar
            SliverToBoxAdapter(
              child: _buildSearchBar(availableCount, allTeachers.length),
            ),

            // Stats bar
            SliverToBoxAdapter(
              child: _buildStatsBar(availableCount, allTeachers.length),
            ),

            // Loading state
            if (locationProvider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredTeachers.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.location_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No teachers match "$_searchQuery"'
                            : _showOnlyAvailable
                                ? 'No teachers are currently available'
                                : 'No teachers have shared their location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_showOnlyAvailable) ...[
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _showOnlyAvailable = false;
                            });
                          },
                          child: const Text('Show all teachers'),
                        ),
                      ],
                    ],
                  ),
                ),
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
                      return _buildTeacherCard(teacher, room);
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

  Widget _buildSearchBar(int available, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          // Search field
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search teachers...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Filter chips
          Row(
            children: [
              FilterChip(
                label: const Text('Available Now'),
                selected: _showOnlyAvailable,
                onSelected: (selected) {
                  setState(() {
                    _showOnlyAvailable = selected;
                  });
                },
                avatar: Icon(
                  _showOnlyAvailable
                      ? Icons.check_circle
                      : Icons.filter_alt_outlined,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              if (available > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$available online',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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

  Widget _buildStatsBar(int available, int total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.people,
            '$total',
            'Total Teachers',
            Colors.blue,
          ),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _buildStatItem(
            Icons.location_on,
            '$available',
            'Available',
            Colors.green,
          ),
          Container(height: 30, width: 1, color: Colors.grey.shade300),
          _buildStatItem(
            Icons.location_off,
            '${total - available}',
            'Away',
            Colors.grey,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherLocationUpdate(
    AuthProvider authProvider,
    TeacherLocationProvider locationProvider,
  ) {
    final rooms = locationProvider.getAvailableRooms();
    final currentTeacher = authProvider.currentTeacher;
    final isLocationSet = currentTeacher?.currentRoomId != null;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLocationSet
              ? [Colors.green.shade400, Colors.teal.shade400]
              : [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isLocationSet
                    ? Colors.green
                    : Theme.of(context).colorScheme.primary)
                .withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isLocationSet ? Icons.check_circle : Icons.my_location,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Your Location',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        isLocationSet
                            ? 'Students can see your location'
                            : 'Set your location so students can find you',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLocationSet)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility, size: 14, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String?>(
                value: currentTeacher?.currentRoomId,
                decoration: InputDecoration(
                  labelText: 'Current Room',
                  prefixIcon: const Icon(Icons.room),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('🚶 Not in any room / Away'),
                  ),
                  ...rooms.map((room) {
                    return DropdownMenuItem(
                      value: room.id,
                      child: Text('${room.roomNumber} - ${room.name}'),
                    );
                  }),
                ],
                onChanged: (roomId) async {
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
    );
  }

  Widget _buildTeacherCard(Teacher teacher, Room? room) {
    final timeSinceUpdate = teacher.currentRoomUpdatedAt != null
        ? DateTime.now().difference(teacher.currentRoomUpdatedAt!)
        : null;
    final isAvailable = teacher.currentRoomId != null;
    final isRecentUpdate =
        timeSinceUpdate != null && timeSinceUpdate.inMinutes < 30;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isAvailable ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isAvailable
            ? BorderSide(color: Colors.green.shade200)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: room != null
            ? () {
                context.read<NavigationProvider>().navigateToRoom(room);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.navigation, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Navigating to ${teacher.name}...'),
                      ],
                    ),
                    backgroundColor: Colors.blue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
                // Switch to navigation tab
                DefaultTabController.of(context).animateTo(0);
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar with status indicator
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isAvailable
                        ? Colors.green.shade50
                        : Colors.grey.shade100,
                    child: Text(
                      teacher.name.isNotEmpty
                          ? teacher.name[0].toUpperCase()
                          : 'T',
                      style: TextStyle(
                        fontSize: 22,
                        color: isAvailable ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: isAvailable
                          ? const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
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
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (teacher.isHod) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.amber, Colors.orange],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'HOD',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (isAvailable && room != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${room.roomNumber} - ${room.name}',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        '📍 Location not available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (teacher.phone?.isNotEmpty == true) ...[
                          Icon(Icons.phone, size: 12, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(
                            teacher.phone!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (timeSinceUpdate != null && isRecentUpdate)
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeSince(timeSinceUpdate),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.navigation,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                ),
            ],
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
