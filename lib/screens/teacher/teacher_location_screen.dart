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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            // Teacher's own location update (for teachers only)
            if (authProvider.isTeacher)
              SliverToBoxAdapter(
                child: _buildTeacherLocationUpdate(authProvider, locationProvider),
              ),
            
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Live Teacher Locations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            
            // Loading state
            if (locationProvider.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (locationProvider.teacherLocations.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No teachers have shared their location',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final teacher = locationProvider.teacherLocations.values
                        .toList()[index];
                    final room = locationProvider.getRoomForTeacher(teacher.id);
                    
                    return _buildTeacherCard(teacher, room);
                  },
                  childCount: locationProvider.teacherLocations.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherLocationUpdate(
    AuthProvider authProvider,
    TeacherLocationProvider locationProvider,
  ) {
    final rooms = locationProvider.getAvailableRooms();
    final currentTeacher = authProvider.currentTeacher;
    
    return Card(
      margin: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.my_location,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Update Your Location',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: currentTeacher?.currentRoomId,
              decoration: InputDecoration(
                labelText: 'Current Room',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Not in any room / Away'),
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
            if (currentTeacher?.currentRoomId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Students can see your current location',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 12,
                  ),
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
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            teacher.name.isNotEmpty ? teacher.name[0].toUpperCase() : 'T',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Text(
              teacher.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            if (teacher.isHod)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HOD',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  room != null 
                      ? '${room.roomNumber} - ${room.name}'
                      : 'Unknown room',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
            if (timeSinceUpdate != null)
              Text(
                'Updated ${_formatTimeSince(timeSinceUpdate)}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        trailing: room != null
            ? IconButton(
                onPressed: () {
                  context.read<NavigationProvider>().navigateToRoom(room);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Navigating to ${room.name}...'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.navigation),
                tooltip: 'Navigate to teacher',
              )
            : null,
        isThreeLine: true,
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
