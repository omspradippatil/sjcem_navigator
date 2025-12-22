import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/teacher_location_provider.dart';
import '../auth/login_screen.dart';
import '../navigation/navigation_screen.dart';
import '../timetable/timetable_screen.dart';
import '../chat/branch_chat_screen.dart';
import '../chat/private_chat_list_screen.dart';
import '../polls/polls_screen.dart';
import '../teacher/teacher_location_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeTeacherLocation();
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
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // Build navigation items based on user type
    final List<Widget> screens = [
      const NavigationScreen(),
      // Guest info screen
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 60,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Sign in to unlock all features',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '• View timetable\n• Chat with classmates\n• Find teachers\n• Participate in polls',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ];

    final List<BottomNavigationBarItem> navItems = [
      const BottomNavigationBarItem(
        icon: Icon(Icons.navigation_outlined),
        activeIcon: Icon(Icons.navigation),
        label: 'Navigate',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.info_outlined),
        activeIcon: Icon(Icons.info),
        label: 'Info',
      ),
    ];

    if (!authProvider.isGuest) {
      // Remove the info screen added for guests
      screens.removeAt(1);
      navItems.removeAt(1);
      screens.add(const TimetableScreen());
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.schedule_outlined),
        activeIcon: Icon(Icons.schedule),
        label: 'Timetable',
      ));

      screens.add(const TeacherLocationScreen());
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.location_on_outlined),
        activeIcon: Icon(Icons.location_on),
        label: 'Teachers',
      ));

      if (authProvider.currentBranchId != null) {
        screens.add(const BranchChatScreen());
        navItems.add(const BottomNavigationBarItem(
          icon: Icon(Icons.chat_bubble_outline),
          activeIcon: Icon(Icons.chat_bubble),
          label: 'Chat',
        ));
      }

      screens.add(const PollsScreen());
      navItems.add(const BottomNavigationBarItem(
        icon: Icon(Icons.poll_outlined),
        activeIcon: Icon(Icons.poll),
        label: 'Polls',
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SJCEM Navigator'),
        actions: [
          if (authProvider.isStudent)
            IconButton(
              icon: const Icon(Icons.message_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivateChatListScreen(),
                  ),
                );
              },
              tooltip: 'Private Messages',
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              } else if (value == 'profile') {
                _showProfileDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline),
                  title: Text('Profile'),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
              if (!authProvider.isGuest)
                const PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  authProvider.currentUserName.isNotEmpty
                      ? authProvider.currentUserName[0].toUpperCase()
                      : 'G',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: navItems,
      ),
    );
  }

  void _showProfileDialog() {
    final authProvider = context.read<AuthProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  authProvider.currentUserName.isNotEmpty
                      ? authProvider.currentUserName[0].toUpperCase()
                      : 'G',
                  style: TextStyle(
                    fontSize: 32,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildProfileItem('Name', authProvider.currentUserName),
            if (authProvider.isStudent) ...[
              _buildProfileItem(
                'Roll Number',
                authProvider.currentStudent?.rollNumber ?? 'N/A',
              ),
              _buildProfileItem(
                'Semester',
                '${authProvider.currentStudent?.semester ?? 'N/A'}',
              ),
              _buildProfileItem(
                'Anonymous ID',
                authProvider.currentStudent?.anonymousId ?? 'N/A',
              ),
            ],
            if (authProvider.isTeacher) ...[
              _buildProfileItem(
                'Phone',
                authProvider.currentTeacher?.phone ?? 'Not set',
              ),
              if (authProvider.isHod)
                _buildProfileItem('Role', 'Head of Department'),
              if (authProvider.isAdmin)
                _buildProfileItem('Role', 'Administrator'),
            ],
            _buildProfileItem(
              'Type',
              authProvider.userType.toUpperCase(),
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

  Widget _buildProfileItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
