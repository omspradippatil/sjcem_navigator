import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../utils/hash_utils.dart';

class SupabaseService {
  static final SupabaseClient _client = Supabase.instance.client;
  
  static SupabaseClient get client => _client;
  
  // =============================================
  // AUTHENTICATION (Custom SQL-based)
  // =============================================
  
  /// Register a new student
  static Future<Student?> registerStudent({
    required String email,
    required String password,
    required String name,
    required String rollNumber,
    required String branchId,
    required int semester,
    String? phone,
  }) async {
    try {
      final passwordHash = HashUtils.hashPassword(password);
      final anonymousId = HashUtils.generateAnonymousId();
      
      final response = await _client
          .from('students')
          .insert({
            'email': email,
            'password_hash': passwordHash,
            'name': name,
            'roll_number': rollNumber,
            'branch_id': branchId,
            'semester': semester,
            'anonymous_id': anonymousId,
            'phone': phone,
          })
          .select()
          .single();
      
      return Student.fromJson(response);
    } catch (e) {
      print('Error registering student: $e');
      return null;
    }
  }
  
  /// Login student
  static Future<Student?> loginStudent(String email, String password) async {
    try {
      final passwordHash = HashUtils.hashPassword(password);
      
      final response = await _client
          .from('students')
          .select()
          .eq('email', email)
          .eq('password_hash', passwordHash)
          .maybeSingle();
      
      if (response != null) {
        return Student.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error logging in student: $e');
      return null;
    }
  }
  
  /// Register a new teacher
  static Future<Teacher?> registerTeacher({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? branchId,
    bool isHod = false,
    bool isAdmin = false,
  }) async {
    try {
      final passwordHash = HashUtils.hashPassword(password);
      
      final response = await _client
          .from('teachers')
          .insert({
            'email': email,
            'password_hash': passwordHash,
            'name': name,
            'phone': phone,
            'branch_id': branchId,
            'is_hod': isHod,
            'is_admin': isAdmin,
          })
          .select()
          .single();
      
      return Teacher.fromJson(response);
    } catch (e) {
      print('Error registering teacher: $e');
      return null;
    }
  }
  
  /// Login teacher
  static Future<Teacher?> loginTeacher(String email, String password) async {
    try {
      final passwordHash = HashUtils.hashPassword(password);
      
      final response = await _client
          .from('teachers')
          .select()
          .eq('email', email)
          .eq('password_hash', passwordHash)
          .maybeSingle();
      
      if (response != null) {
        return Teacher.fromJson(response);
      }
      return null;
    } catch (e) {
      print('Error logging in teacher: $e');
      return null;
    }
  }
  
  // =============================================
  // BRANCHES
  // =============================================
  
  static Future<List<Branch>> getBranches() async {
    try {
      final response = await _client
          .from('branches')
          .select()
          .order('name');
      
      return (response as List)
          .map((b) => Branch.fromJson(b))
          .toList();
    } catch (e) {
      print('Error fetching branches: $e');
      return [];
    }
  }
  
  // =============================================
  // ROOMS
  // =============================================
  
  static Future<List<Room>> getRooms() async {
    try {
      final response = await _client
          .from('rooms')
          .select()
          .order('room_number');
      
      return (response as List)
          .map((r) => Room.fromJson(r))
          .toList();
    } catch (e) {
      print('Error fetching rooms: $e');
      return [];
    }
  }
  
  static Future<Room?> getRoomById(String id) async {
    try {
      final response = await _client
          .from('rooms')
          .select()
          .eq('id', id)
          .single();
      
      return Room.fromJson(response);
    } catch (e) {
      print('Error fetching room: $e');
      return null;
    }
  }
  
  static Future<Room?> createRoom(Room room) async {
    try {
      final response = await _client
          .from('rooms')
          .insert(room.toInsertJson())
          .select()
          .single();
      
      return Room.fromJson(response);
    } catch (e) {
      print('Error creating room: $e');
      return null;
    }
  }
  
  static Future<bool> updateRoom(Room room) async {
    try {
      await _client
          .from('rooms')
          .update({
            'name': room.name,
            'x_coordinate': room.xCoordinate,
            'y_coordinate': room.yCoordinate,
            'room_type': room.roomType,
          })
          .eq('id', room.id);
      
      return true;
    } catch (e) {
      print('Error updating room: $e');
      return false;
    }
  }
  
  // =============================================
  // TIMETABLE
  // =============================================
  
  static Future<List<TimetableEntry>> getTimetable({
    required String branchId,
    required int semester,
    int? dayOfWeek,
  }) async {
    try {
      var query = _client
          .from('timetable')
          .select('''
            *,
            subjects(*),
            teachers(*),
            rooms(*)
          ''')
          .eq('branch_id', branchId)
          .eq('semester', semester);
      
      if (dayOfWeek != null) {
        query = query.eq('day_of_week', dayOfWeek);
      }
      
      final response = await query.order('period_number');
      
      return (response as List)
          .map((t) => TimetableEntry.fromJson(t))
          .toList();
    } catch (e) {
      print('Error fetching timetable: $e');
      return [];
    }
  }
  
  static Future<List<TimetableEntry>> getTodayTimetable({
    required String branchId,
    required int semester,
  }) async {
    final today = DateTime.now().weekday % 7; // 0 = Sunday
    return getTimetable(
      branchId: branchId,
      semester: semester,
      dayOfWeek: today,
    );
  }
  
  // =============================================
  // TEACHER LOCATION
  // =============================================
  
  static Future<bool> updateTeacherLocation(String teacherId, String? roomId) async {
    try {
      await _client
          .from('teachers')
          .update({
            'current_room_id': roomId,
            'current_room_updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', teacherId);
      
      // Also log to history
      if (roomId != null) {
        await _client.from('teacher_location_history').insert({
          'teacher_id': teacherId,
          'room_id': roomId,
        });
      }
      
      return true;
    } catch (e) {
      print('Error updating teacher location: $e');
      return false;
    }
  }
  
  static Future<List<Teacher>> getTeachersWithLocation() async {
    try {
      final response = await _client
          .from('teachers')
          .select()
          .not('current_room_id', 'is', null);
      
      return (response as List)
          .map((t) => Teacher.fromJson(t))
          .toList();
    } catch (e) {
      print('Error fetching teachers with location: $e');
      return [];
    }
  }
  
  static RealtimeChannel subscribeToTeacherLocations(
    void Function(Map<String, dynamic>) callback,
  ) {
    return _client
        .channel('teacher-locations')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'teachers',
          callback: (payload) => callback(payload.newRecord),
        )
        .subscribe();
  }
  
  // =============================================
  // BRANCH CHAT (Anonymous)
  // =============================================
  
  static Future<List<ChatMessage>> getBranchMessages(String branchId, {int limit = 50}) async {
    try {
      final response = await _client
          .from('branch_chat_messages')
          .select()
          .eq('branch_id', branchId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (response as List)
          .map((m) => ChatMessage.fromJson(m))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error fetching branch messages: $e');
      return [];
    }
  }
  
  static Future<ChatMessage?> sendBranchMessage({
    required String branchId,
    required String senderId,
    required String senderType,
    required String anonymousName,
    required String message,
  }) async {
    try {
      final response = await _client
          .from('branch_chat_messages')
          .insert({
            'branch_id': branchId,
            'sender_id': senderId,
            'sender_type': senderType,
            'anonymous_name': anonymousName,
            'message': message,
          })
          .select()
          .single();
      
      return ChatMessage.fromJson(response);
    } catch (e) {
      print('Error sending branch message: $e');
      return null;
    }
  }
  
  static RealtimeChannel subscribeToBranchChat(
    String branchId,
    void Function(ChatMessage) callback,
  ) {
    return _client
        .channel('branch-chat-$branchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'branch_chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'branch_id',
            value: branchId,
          ),
          callback: (payload) => callback(ChatMessage.fromJson(payload.newRecord)),
        )
        .subscribe();
  }
  
  // =============================================
  // PRIVATE MESSAGES
  // =============================================
  
  static Future<List<PrivateMessage>> getPrivateMessages(
    String userId1,
    String userId2,
    {int limit = 50}
  ) async {
    try {
      final response = await _client
          .from('private_messages')
          .select()
          .or('and(sender_id.eq.$userId1,receiver_id.eq.$userId2),and(sender_id.eq.$userId2,receiver_id.eq.$userId1)')
          .order('created_at', ascending: false)
          .limit(limit);
      
      return (response as List)
          .map((m) => PrivateMessage.fromJson(m))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error fetching private messages: $e');
      return [];
    }
  }
  
  static Future<PrivateMessage?> sendPrivateMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    try {
      final response = await _client
          .from('private_messages')
          .insert({
            'sender_id': senderId,
            'receiver_id': receiverId,
            'message': message,
          })
          .select()
          .single();
      
      return PrivateMessage.fromJson(response);
    } catch (e) {
      print('Error sending private message: $e');
      return null;
    }
  }
  
  static Future<bool> markMessagesAsRead(String currentUserId, String odUserId) async {
    try {
      await _client
          .from('private_messages')
          .update({'is_read': true})
          .eq('sender_id', odUserId)
          .eq('receiver_id', currentUserId)
          .eq('is_read', false);
      
      return true;
    } catch (e) {
      print('Error marking messages as read: $e');
      return false;
    }
  }
  
  static RealtimeChannel subscribeToPrivateMessages(
    String currentUserId,
    void Function(PrivateMessage) callback,
  ) {
    return _client
        .channel('private-messages-$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'private_messages',
          callback: (payload) {
            final message = PrivateMessage.fromJson(payload.newRecord);
            if (message.senderId == currentUserId || message.receiverId == currentUserId) {
              callback(message);
            }
          },
        )
        .subscribe();
  }
  
  static Future<List<Student>> getStudentsForChat(String currentUserId, String? branchId) async {
    try {
      var query = _client
          .from('students')
          .select()
          .neq('id', currentUserId);
      
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }
      
      final response = await query.order('name');
      
      return (response as List)
          .map((s) => Student.fromJson(s))
          .toList();
    } catch (e) {
      print('Error fetching students for chat: $e');
      return [];
    }
  }
  
  // =============================================
  // POLLS
  // =============================================
  
  static Future<List<Poll>> getPolls({String? branchId, bool? activeOnly}) async {
    try {
      var query = _client
          .from('polls')
          .select('''
            *,
            poll_options(*)
          ''');
      
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }
      
      if (activeOnly == true) {
        query = query.eq('is_active', true);
      }
      
      final response = await query.order('created_at', ascending: false);
      
      return (response as List)
          .map((p) => Poll.fromJson(p))
          .toList();
    } catch (e) {
      print('Error fetching polls: $e');
      return [];
    }
  }
  
  static Future<Poll?> createPoll({
    required String title,
    String? description,
    String? branchId,
    required String createdBy,
    required List<String> options,
    DateTime? endsAt,
  }) async {
    try {
      // Create poll
      final pollResponse = await _client
          .from('polls')
          .insert({
            'title': title,
            'description': description,
            'branch_id': branchId,
            'created_by': createdBy,
            'ends_at': endsAt?.toIso8601String(),
          })
          .select()
          .single();
      
      final pollId = pollResponse['id'];
      
      // Create options
      for (final option in options) {
        await _client.from('poll_options').insert({
          'poll_id': pollId,
          'option_text': option,
        });
      }
      
      // Fetch complete poll with options
      final response = await _client
          .from('polls')
          .select('''
            *,
            poll_options(*)
          ''')
          .eq('id', pollId)
          .single();
      
      return Poll.fromJson(response);
    } catch (e) {
      print('Error creating poll: $e');
      return null;
    }
  }
  
  static Future<bool> vote({
    required String pollId,
    required String optionId,
    required String studentId,
  }) async {
    try {
      await _client.from('poll_votes').insert({
        'poll_id': pollId,
        'option_id': optionId,
        'student_id': studentId,
      });
      
      return true;
    } catch (e) {
      print('Error voting: $e');
      return false;
    }
  }
  
  static Future<bool> hasVoted(String pollId, String studentId) async {
    try {
      final response = await _client
          .from('poll_votes')
          .select()
          .eq('poll_id', pollId)
          .eq('student_id', studentId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      print('Error checking vote: $e');
      return false;
    }
  }
  
  static Future<String?> getVotedOption(String pollId, String studentId) async {
    try {
      final response = await _client
          .from('poll_votes')
          .select('option_id')
          .eq('poll_id', pollId)
          .eq('student_id', studentId)
          .maybeSingle();
      
      return response?['option_id'];
    } catch (e) {
      print('Error getting voted option: $e');
      return null;
    }
  }
  
  static RealtimeChannel subscribeToPollVotes(
    String pollId,
    void Function() callback,
  ) {
    return _client
        .channel('poll-votes-$pollId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'poll_options',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'poll_id',
            value: pollId,
          ),
          callback: (_) => callback(),
        )
        .subscribe();
  }
  
  static Future<Poll?> refreshPoll(String pollId) async {
    try {
      final response = await _client
          .from('polls')
          .select('''
            *,
            poll_options(*)
          ''')
          .eq('id', pollId)
          .single();
      
      return Poll.fromJson(response);
    } catch (e) {
      print('Error refreshing poll: $e');
      return null;
    }
  }
  
  // =============================================
  // TEACHERS
  // =============================================
  
  static Future<List<Teacher>> getTeachers({String? branchId}) async {
    try {
      var query = _client.from('teachers').select();
      
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }
      
      final response = await query.order('name');
      
      return (response as List)
          .map((t) => Teacher.fromJson(t))
          .toList();
    } catch (e) {
      print('Error fetching teachers: $e');
      return [];
    }
  }
  
  static Future<Teacher?> getTeacherById(String id) async {
    try {
      final response = await _client
          .from('teachers')
          .select()
          .eq('id', id)
          .single();
      
      return Teacher.fromJson(response);
    } catch (e) {
      print('Error fetching teacher: $e');
      return null;
    }
  }
  
  // =============================================
  // SUBJECTS
  // =============================================
  
  static Future<List<Subject>> getSubjects({String? branchId, int? semester}) async {
    try {
      var query = _client.from('subjects').select();
      
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }
      
      if (semester != null) {
        query = query.eq('semester', semester);
      }
      
      final response = await query.order('name');
      
      return (response as List)
          .map((s) => Subject.fromJson(s))
          .toList();
    } catch (e) {
      print('Error fetching subjects: $e');
      return [];
    }
  }
}
