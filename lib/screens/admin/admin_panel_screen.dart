import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../models/teacher.dart';
import '../../models/student.dart';
import '../../models/room.dart';
import '../../models/branch.dart';
import '../../models/poll.dart';
import '../../models/subject.dart';
import '../../models/timetable_entry.dart';
import '../../utils/constants.dart';

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
  late TabController _tabController;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
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
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings,
                    size: 80,
                    color: Colors.red.shade700,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Admin Authentication',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter admin password to access the panel',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 300,
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Admin Password',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        errorText: _passwordError,
                      ),
                      onSubmitted: (_) => _verifyPassword(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 200,
                    child: ElevatedButton(
                      onPressed: _verifyPassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'ACCESS PANEL',
                        style: TextStyle(fontSize: 16),
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

  Widget _buildAdminPanel() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllData,
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              setState(() {
                _isAuthenticated = false;
                _passwordController.clear();
              });
            },
            tooltip: 'Lock Panel',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.person), text: 'Teachers'),
            Tab(icon: Icon(Icons.school), text: 'Students'),
            Tab(icon: Icon(Icons.room), text: 'Rooms'),
            Tab(icon: Icon(Icons.business), text: 'Branches'),
            Tab(icon: Icon(Icons.poll), text: 'Polls'),
            Tab(icon: Icon(Icons.book), text: 'Subjects'),
            Tab(icon: Icon(Icons.schedule), text: 'Timetable'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
      floatingActionButton: _buildFAB(),
    );
  }

  Widget? _buildFAB() {
    return FloatingActionButton(
      backgroundColor: Colors.red.shade700,
      foregroundColor: Colors.white,
      onPressed: () {
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
      child: const Icon(Icons.add),
    );
  }

  // Dashboard Tab
  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  _buildStatCard(
                      'Teachers', _teachers.length, Icons.person, Colors.blue),
                  _buildStatCard(
                      'Students', _students.length, Icons.school, Colors.green),
                  _buildStatCard(
                      'Rooms', _rooms.length, Icons.room, Colors.orange),
                  _buildStatCard('Branches', _branches.length, Icons.business,
                      Colors.purple),
                  _buildStatCard(
                      'Polls', _polls.length, Icons.poll, Colors.teal),
                  _buildStatCard(
                      'Subjects', _subjects.length, Icons.book, Colors.indigo),
                  _buildStatCard('Timetable', _timetableEntries.length,
                      Icons.schedule, Colors.pink),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const Text(
            'Quick Stats',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildQuickStatRow('HOD Teachers',
                      _teachers.where((t) => t.isHod).length.toString()),
                  _buildQuickStatRow('Admin Teachers',
                      _teachers.where((t) => t.isAdmin).length.toString()),
                  _buildQuickStatRow('Active Polls',
                      _polls.where((p) => p.isActive).length.toString()),
                  _buildQuickStatRow('Total Rooms', _rooms.length.toString()),
                  _buildQuickStatRow('Floor 3 Rooms',
                      _rooms.where((r) => r.floor == 3).length.toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.8), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: Colors.white),
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
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Teachers Tab
  Widget _buildTeachersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _teachers.length,
      itemBuilder: (context, index) {
        final teacher = _teachers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: teacher.isHod ? Colors.orange : Colors.blue,
              child: Text(teacher.name[0].toUpperCase()),
            ),
            title: Text(teacher.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(teacher.email, overflow: TextOverflow.ellipsis),
                Text('Branch: ${_getBranchName(teacher.branchId)}'),
                Wrap(
                  spacing: 4,
                  children: [
                    if (teacher.isHod)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('HOD',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                    if (teacher.isAdmin)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Admin',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ),
                  ],
                ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleTeacherAction(value, teacher),
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'assign_subjects', child: Text('Assign Subjects')),
                PopupMenuItem(
                    value: 'toggle_hod',
                    child: Text(teacher.isHod ? 'Remove HOD' : 'Make HOD')),
                PopupMenuItem(
                    value: 'toggle_admin',
                    child:
                        Text(teacher.isAdmin ? 'Remove Admin' : 'Make Admin')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
            ),
          ),
        );
      },
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green,
              child: Text(student.name[0].toUpperCase()),
            ),
            title: Text(student.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.email),
                Text(
                    'Roll: ${student.rollNumber} | Semester: ${student.semester}'),
                Text('Branch: ${student.branchId ?? 'Not Assigned'}'),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleStudentAction(value, student),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'view', child: Text('View Details')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
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
        title: Text(student.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${student.email}'),
            Text('Roll Number: ${student.rollNumber}'),
            Text('Semester: ${student.semester}'),
            Text('Branch ID: ${student.branchId ?? 'Not Assigned'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Rooms Tab
  Widget _buildRoomsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.room, color: Colors.white),
            ),
            title: Text(room.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Type: ${room.roomType}'),
                Text('Floor: ${room.floor} | Room: ${room.roomNumber}'),
                if (room.displayName != null)
                  Text('Display: ${room.displayName}'),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleRoomAction(value, room),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _branches.length,
      itemBuilder: (context, index) {
        final branch = _branches[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.purple,
              child: Text(branch.code[0].toUpperCase()),
            ),
            title: Text(branch.name),
            subtitle: Text('Code: ${branch.code}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleBranchAction(value, branch),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _polls.length,
      itemBuilder: (context, index) {
        final poll = _polls[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: poll.isActive ? Colors.green : Colors.grey,
              child: const Icon(Icons.poll, color: Colors.white),
            ),
            title: Text(poll.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    'Options: ${poll.options.map((o) => o.optionText).join(", ")}'),
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: poll.isActive ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    poll.isActive ? 'Active' : 'Inactive',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handlePollAction(value, poll),
              itemBuilder: (context) => [
                PopupMenuItem(
                    value: 'toggle',
                    child: Text(poll.isActive ? 'Deactivate' : 'Activate')),
                const PopupMenuItem(
                    value: 'results', child: Text('View Results')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Poll Results'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poll.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...poll.options.map((option) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(option.optionText),
                    Text('${option.voteCount} votes'),
                  ],
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Subjects Tab
  Widget _buildSubjectsTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final subject = _subjects[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.indigo,
              child: Text(subject.code[0].toUpperCase()),
            ),
            title: Text(subject.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Code: ${subject.code}'),
                Text(
                    'Branch: ${subject.branchId ?? 'All'} | Semester: ${subject.semester} | Credits: ${subject.credits}'),
              ],
            ),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleSubjectAction(value, subject),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete', style: TextStyle(color: Colors.red))),
              ],
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
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
