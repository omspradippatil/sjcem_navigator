import 'package:postgres/postgres.dart';
import 'dart:async';
import '../models/models.dart';
import '../utils/hash_utils.dart';
import '../utils/constants.dart';

class PostgresService {
  static Connection? _connection;
  static bool _isConnecting = false;
  static Completer<void>? _connectionCompleter;

  /// Initialize database connection with retry logic
  static Future<void> initialize() async {
    if (_isConnecting) {
      await _connectionCompleter?.future;
      return;
    }

    _isConnecting = true;
    _connectionCompleter = Completer<void>();
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        _connection = await Connection.open(
          Endpoint(
            host: AppConstants.dbHost,
            port: AppConstants.dbPort,
            database: AppConstants.dbName,
            username: AppConstants.dbUser,
            password: AppConstants.dbPassword,
          ),
          settings: ConnectionSettings(
            sslMode: SslMode.disable,
            connectTimeout: const Duration(seconds: 30),
            queryTimeout: const Duration(seconds: 30),
          ),
        );

        print('PostgreSQL connection established');
        _isConnecting = false;
        _connectionCompleter?.complete();
        return;
      } catch (e) {
        retryCount++;
        print('Connection attempt $retryCount failed: $e');
        if (retryCount >= maxRetries) {
          _isConnecting = false;
          _connectionCompleter?.complete();
          rethrow;
        }
        await Future.delayed(Duration(seconds: 2 * retryCount));
      }
    }
  }

  /// Ensure connection is active, reconnect if needed
  static Future<void> _ensureConnected() async {
    if (_connection == null) {
      await initialize();
    }
  }

  /// Execute query with automatic reconnection
  static Future<Result> _query(String sql,
      {Map<String, dynamic>? parameters}) async {
    await _ensureConnected();
    try {
      return await _connection!
          .execute(Sql.named(sql), parameters: parameters ?? {});
    } catch (e) {
      // Try reconnecting once on connection error
      if (e.toString().contains('connection') ||
          e.toString().contains('closed')) {
        _connection = null;
        await initialize();
        return await _connection!
            .execute(Sql.named(sql), parameters: parameters ?? {});
      }
      rethrow;
    }
  }

  /// Close database connection
  static Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }

  /// Check if connected
  static bool get isConnected => _connection != null;

  // =============================================
  // HELPER METHODS
  // =============================================

  /// Convert Result row to Map
  static Map<String, dynamic> _rowToMap(ResultRow row, List<String> columns) {
    final map = <String, dynamic>{};
    for (int i = 0; i < columns.length && i < row.length; i++) {
      map[columns[i]] = row[i];
    }
    return map;
  }

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
      final now = DateTime.now().toIso8601String();

      final result = await _query(
        '''
        INSERT INTO students (email, password_hash, name, roll_number, branch_id, semester, phone, created_at)
        VALUES (@email, @password_hash, @name, @roll_number, @branch_id, @semester, @phone, @created_at)
        RETURNING *
        ''',
        parameters: {
          'email': email,
          'password_hash': passwordHash,
          'name': name,
          'roll_number': rollNumber,
          'branch_id': branchId,
          'semester': semester,
          'phone': phone,
          'created_at': now,
        },
      );

      if (result.isNotEmpty) {
        final columns = [
          'id',
          'email',
          'password_hash',
          'name',
          'roll_number',
          'branch_id',
          'semester',
          'phone',
          'created_at'
        ];
        return Student.fromJson(_rowToMap(result.first, columns));
      }
      return null;
    } catch (e) {
      print('Error registering student: $e');
      return null;
    }
  }

  /// Login student with email and password
  static Future<Student?> loginStudent({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _query(
        'SELECT * FROM students WHERE email = @email',
        parameters: {'email': email},
      );

      if (result.isEmpty) return null;

      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'roll_number',
        'branch_id',
        'semester',
        'phone',
        'created_at'
      ];
      final row = _rowToMap(result.first, columns);
      final storedHash = row['password_hash'] as String?;

      if (storedHash != null &&
          HashUtils.verifyPassword(password, storedHash)) {
        return Student.fromJson(row);
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
  }) async {
    try {
      final passwordHash = HashUtils.hashPassword(password);
      final now = DateTime.now().toIso8601String();

      final result = await _query(
        '''
        INSERT INTO teachers (email, password_hash, name, phone, branch_id, is_hod, created_at)
        VALUES (@email, @password_hash, @name, @phone, @branch_id, @is_hod, @created_at)
        RETURNING *
        ''',
        parameters: {
          'email': email,
          'password_hash': passwordHash,
          'name': name,
          'phone': phone,
          'branch_id': branchId,
          'is_hod': isHod,
          'created_at': now,
        },
      );

      if (result.isNotEmpty) {
        final columns = [
          'id',
          'email',
          'password_hash',
          'name',
          'phone',
          'branch_id',
          'is_hod',
          'is_admin',
          'current_room_id',
          'current_room_updated_at',
          'is_active',
          'last_login',
          'created_at',
          'updated_at'
        ];
        return Teacher.fromJson(_rowToMap(result.first, columns));
      }
      return null;
    } catch (e) {
      print('Error registering teacher: $e');
      return null;
    }
  }

  /// Login teacher with email and password
  static Future<Teacher?> loginTeacher({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _query(
        'SELECT * FROM teachers WHERE email = @email',
        parameters: {'email': email},
      );

      if (result.isEmpty) return null;

      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'phone',
        'branch_id',
        'is_hod',
        'is_admin',
        'current_room_id',
        'current_room_updated_at',
        'is_active',
        'last_login',
        'created_at',
        'updated_at'
      ];
      final row = _rowToMap(result.first, columns);
      final storedHash = row['password_hash'] as String?;

      if (storedHash != null &&
          HashUtils.verifyPassword(password, storedHash)) {
        return Teacher.fromJson(row);
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

  /// Get all branches
  static Future<List<Branch>> getBranches() async {
    try {
      final result = await _query('SELECT * FROM branches ORDER BY name');
      final columns = ['id', 'name', 'code', 'created_at'];
      return result
          .map((row) => Branch.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching branches: $e');
      return [];
    }
  }

  // =============================================
  // ROOMS & NAVIGATION
  // =============================================

  /// Get rooms by floor
  static Future<List<Room>> getRoomsByFloor(int floor) async {
    try {
      final result = await _query(
        'SELECT * FROM rooms WHERE floor = @floor ORDER BY room_number',
        parameters: {'floor': floor},
      );
      final columns = [
        'id',
        'room_number',
        'room_name',
        'room_type',
        'floor',
        'x_coordinate',
        'y_coordinate',
        'description',
        'capacity',
        'created_at'
      ];
      return result
          .map((row) => Room.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching rooms: $e');
      return [];
    }
  }

  /// Get all rooms
  static Future<List<Room>> getAllRooms() async {
    try {
      final result =
          await _query('SELECT * FROM rooms ORDER BY floor, room_number');
      final columns = [
        'id',
        'room_number',
        'room_name',
        'room_type',
        'floor',
        'x_coordinate',
        'y_coordinate',
        'description',
        'capacity',
        'created_at'
      ];
      return result
          .map((row) => Room.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching all rooms: $e');
      return [];
    }
  }

  /// Get room by ID
  static Future<Room?> getRoomById(String roomId) async {
    try {
      final result = await _query(
        'SELECT * FROM rooms WHERE id = @id',
        parameters: {'id': roomId},
      );
      if (result.isEmpty) return null;
      final columns = [
        'id',
        'room_number',
        'room_name',
        'room_type',
        'floor',
        'x_coordinate',
        'y_coordinate',
        'description',
        'capacity',
        'created_at'
      ];
      return Room.fromJson(_rowToMap(result.first, columns));
    } catch (e) {
      print('Error fetching room: $e');
      return null;
    }
  }

  /// Search rooms
  static Future<List<Room>> searchRooms(String query) async {
    try {
      final result = await _query(
        '''
        SELECT * FROM rooms 
        WHERE room_number ILIKE @query 
        OR room_name ILIKE @query 
        OR room_type ILIKE @query
        ORDER BY room_number
        ''',
        parameters: {'query': '%$query%'},
      );
      final columns = [
        'id',
        'room_number',
        'room_name',
        'room_type',
        'floor',
        'x_coordinate',
        'y_coordinate',
        'description',
        'capacity',
        'created_at'
      ];
      return result
          .map((row) => Room.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error searching rooms: $e');
      return [];
    }
  }

  // =============================================
  // TIMETABLE
  // =============================================

  /// Get timetable for branch and semester
  static Future<List<TimetableEntry>> getTimetable({
    required String branchId,
    required int semester,
    String? dayOfWeek,
  }) async {
    try {
      String sql = '''
        SELECT t.*, s.name as subject_name, s.code as subject_code, 
               r.room_number, r.room_name, r.floor as room_floor,
               te.name as teacher_name
        FROM timetable t
        LEFT JOIN subjects s ON t.subject_id = s.id
        LEFT JOIN rooms r ON t.room_id = r.id
        LEFT JOIN teachers te ON t.teacher_id = te.id
        WHERE t.branch_id = @branch_id AND t.semester = @semester
      ''';

      final params = <String, dynamic>{
        'branch_id': branchId,
        'semester': semester,
      };

      if (dayOfWeek != null) {
        sql += ' AND t.day_of_week = @day_of_week';
        params['day_of_week'] = dayOfWeek;
      }

      sql += ' ORDER BY t.day_of_week, t.start_time';

      final result = await _query(sql, parameters: params);
      final columns = [
        'id',
        'branch_id',
        'semester',
        'subject_id',
        'teacher_id',
        'room_id',
        'day_of_week',
        'start_time',
        'end_time',
        'created_at',
        'subject_name',
        'subject_code',
        'room_number',
        'room_name',
        'room_floor',
        'teacher_name'
      ];
      return result
          .map((row) => TimetableEntry.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching timetable: $e');
      return [];
    }
  }

  // =============================================
  // TEACHERS
  // =============================================

  /// Get all teachers
  static Future<List<Teacher>> getTeachers() async {
    try {
      final result = await _query('SELECT * FROM teachers ORDER BY name');
      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'phone',
        'branch_id',
        'is_hod',
        'is_admin',
        'current_room_id',
        'current_room_updated_at',
        'is_active',
        'last_login',
        'created_at',
        'updated_at'
      ];
      return result
          .map((row) => Teacher.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching teachers: $e');
      return [];
    }
  }

  /// Get teacher by ID
  static Future<Teacher?> getTeacherById(String teacherId) async {
    try {
      final result = await _query(
        'SELECT * FROM teachers WHERE id = @id',
        parameters: {'id': teacherId},
      );
      if (result.isEmpty) return null;
      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'phone',
        'branch_id',
        'is_hod',
        'is_admin',
        'current_room_id',
        'current_room_updated_at',
        'is_active',
        'last_login',
        'created_at',
        'updated_at'
      ];
      return Teacher.fromJson(_rowToMap(result.first, columns));
    } catch (e) {
      print('Error fetching teacher: $e');
      return null;
    }
  }

  /// Search teachers by name
  static Future<List<Teacher>> searchTeachers(String query) async {
    try {
      final result = await _query(
        '''
        SELECT * FROM teachers 
        WHERE name ILIKE @query OR email ILIKE @query
        ORDER BY name
        ''',
        parameters: {'query': '%$query%'},
      );
      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'phone',
        'branch_id',
        'is_hod',
        'is_admin',
        'current_room_id',
        'current_room_updated_at',
        'is_active',
        'last_login',
        'created_at',
        'updated_at'
      ];
      return result
          .map((row) => Teacher.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error searching teachers: $e');
      return [];
    }
  }

  // =============================================
  // CHAT MESSAGES
  // =============================================

  /// Get chat messages for branch and semester
  static Future<List<ChatMessage>> getChatMessages({
    required String branchId,
    required int semester,
    int limit = 50,
  }) async {
    try {
      final result = await _query(
        '''
        SELECT cm.*, s.name as sender_name 
        FROM chat_messages cm
        LEFT JOIN students s ON cm.sender_id = s.id
        WHERE cm.branch_id = @branch_id AND cm.semester = @semester
        ORDER BY cm.created_at DESC
        LIMIT @limit
        ''',
        parameters: {
          'branch_id': branchId,
          'semester': semester,
          'limit': limit,
        },
      );
      final columns = [
        'id',
        'sender_id',
        'branch_id',
        'semester',
        'message',
        'created_at',
        'sender_name'
      ];
      return result
          .map((row) => ChatMessage.fromJson(_rowToMap(row, columns)))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error fetching chat messages: $e');
      return [];
    }
  }

  /// Send chat message
  static Future<ChatMessage?> sendChatMessage({
    required String senderId,
    required String branchId,
    required int semester,
    required String message,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final result = await _query(
        '''
        INSERT INTO chat_messages (sender_id, branch_id, semester, message, created_at)
        VALUES (@sender_id, @branch_id, @semester, @message, @created_at)
        RETURNING *
        ''',
        parameters: {
          'sender_id': senderId,
          'branch_id': branchId,
          'semester': semester,
          'message': message,
          'created_at': now,
        },
      );
      if (result.isNotEmpty) {
        final columns = [
          'id',
          'sender_id',
          'branch_id',
          'semester',
          'message',
          'created_at'
        ];
        return ChatMessage.fromJson(_rowToMap(result.first, columns));
      }
      return null;
    } catch (e) {
      print('Error sending chat message: $e');
      return null;
    }
  }

  // =============================================
  // PRIVATE MESSAGES
  // =============================================

  /// Get private messages between two users
  static Future<List<PrivateMessage>> getPrivateMessages({
    required String senderId,
    required String receiverId,
    int limit = 50,
  }) async {
    try {
      final result = await _query(
        '''
        SELECT * FROM private_messages
        WHERE (sender_id = @sender_id AND receiver_id = @receiver_id)
           OR (sender_id = @receiver_id AND receiver_id = @sender_id)
        ORDER BY created_at DESC
        LIMIT @limit
        ''',
        parameters: {
          'sender_id': senderId,
          'receiver_id': receiverId,
          'limit': limit,
        },
      );
      final columns = [
        'id',
        'sender_id',
        'receiver_id',
        'message',
        'is_read',
        'created_at'
      ];
      return result
          .map((row) => PrivateMessage.fromJson(_rowToMap(row, columns)))
          .toList()
          .reversed
          .toList();
    } catch (e) {
      print('Error fetching private messages: $e');
      return [];
    }
  }

  /// Send private message
  static Future<PrivateMessage?> sendPrivateMessage({
    required String senderId,
    required String receiverId,
    required String message,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();
      final result = await _query(
        '''
        INSERT INTO private_messages (sender_id, receiver_id, message, created_at)
        VALUES (@sender_id, @receiver_id, @message, @created_at)
        RETURNING *
        ''',
        parameters: {
          'sender_id': senderId,
          'receiver_id': receiverId,
          'message': message,
          'created_at': now,
        },
      );
      if (result.isNotEmpty) {
        final columns = [
          'id',
          'sender_id',
          'receiver_id',
          'message',
          'is_read',
          'created_at'
        ];
        return PrivateMessage.fromJson(_rowToMap(result.first, columns));
      }
      return null;
    } catch (e) {
      print('Error sending private message: $e');
      return null;
    }
  }

  /// Get conversations for a user
  static Future<List<Student>> getConversations(String userId) async {
    try {
      final result = await _query(
        '''
        SELECT DISTINCT s.* FROM students s
        INNER JOIN private_messages pm ON (
          (pm.sender_id = @user_id AND pm.receiver_id = s.id)
          OR (pm.receiver_id = @user_id AND pm.sender_id = s.id)
        )
        WHERE s.id != @user_id
        ORDER BY s.name
        ''',
        parameters: {'user_id': userId},
      );
      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'roll_number',
        'branch_id',
        'semester',
        'phone',
        'created_at'
      ];
      return result
          .map((row) => Student.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching conversations: $e');
      return [];
    }
  }

  // =============================================
  // POLLS
  // =============================================

  /// Get polls for branch and semester
  static Future<List<Poll>> getPolls({
    required String branchId,
    required int semester,
  }) async {
    try {
      final result = await _query(
        '''
        SELECT p.*, 
               s.name as creator_name,
               COALESCE(
                 json_agg(
                   json_build_object(
                     'id', po.id,
                     'option_text', po.option_text,
                     'vote_count', (SELECT COUNT(*) FROM poll_votes pv WHERE pv.option_id = po.id)
                   )
                 ) FILTER (WHERE po.id IS NOT NULL), '[]'
               ) as options
        FROM polls p
        LEFT JOIN students s ON p.created_by = s.id
        LEFT JOIN poll_options po ON po.poll_id = p.id
        WHERE p.branch_id = @branch_id AND p.semester = @semester
        GROUP BY p.id, s.name
        ORDER BY p.created_at DESC
        ''',
        parameters: {
          'branch_id': branchId,
          'semester': semester,
        },
      );
      final columns = [
        'id',
        'branch_id',
        'semester',
        'question',
        'created_by',
        'expires_at',
        'is_active',
        'created_at',
        'creator_name',
        'options'
      ];
      return result
          .map((row) => Poll.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching polls: $e');
      return [];
    }
  }

  /// Create a new poll
  static Future<Poll?> createPoll({
    required String branchId,
    required int semester,
    required String question,
    required String createdBy,
    required List<String> options,
    DateTime? expiresAt,
  }) async {
    try {
      final now = DateTime.now().toIso8601String();

      // Insert poll
      final pollResult = await _query(
        '''
        INSERT INTO polls (branch_id, semester, question, created_by, expires_at, created_at)
        VALUES (@branch_id, @semester, @question, @created_by, @expires_at, @created_at)
        RETURNING *
        ''',
        parameters: {
          'branch_id': branchId,
          'semester': semester,
          'question': question,
          'created_by': createdBy,
          'expires_at': expiresAt?.toIso8601String(),
          'created_at': now,
        },
      );

      if (pollResult.isEmpty) return null;

      final pollColumns = [
        'id',
        'branch_id',
        'semester',
        'question',
        'created_by',
        'expires_at',
        'is_active',
        'created_at'
      ];
      final pollMap = _rowToMap(pollResult.first, pollColumns);
      final pollId = pollMap['id'] as String;

      // Insert options
      for (final option in options) {
        await _query(
          '''
          INSERT INTO poll_options (poll_id, option_text)
          VALUES (@poll_id, @option_text)
          ''',
          parameters: {
            'poll_id': pollId,
            'option_text': option,
          },
        );
      }

      // Fetch complete poll with options
      final polls = await getPolls(branchId: branchId, semester: semester);
      return polls.firstWhere((p) => p.id == pollId);
    } catch (e) {
      print('Error creating poll: $e');
      return null;
    }
  }

  /// Vote on a poll option
  static Future<bool> votePoll({
    required String optionId,
    required String voterId,
  }) async {
    try {
      await _query(
        '''
        INSERT INTO poll_votes (option_id, voter_id)
        VALUES (@option_id, @voter_id)
        ON CONFLICT (option_id, voter_id) DO NOTHING
        ''',
        parameters: {
          'option_id': optionId,
          'voter_id': voterId,
        },
      );
      return true;
    } catch (e) {
      print('Error voting on poll: $e');
      return false;
    }
  }

  /// Check if user has voted on poll
  static Future<String?> getUserVote(String pollId, String voterId) async {
    try {
      final result = await _query(
        '''
        SELECT pv.option_id FROM poll_votes pv
        INNER JOIN poll_options po ON pv.option_id = po.id
        WHERE po.poll_id = @poll_id AND pv.voter_id = @voter_id
        ''',
        parameters: {
          'poll_id': pollId,
          'voter_id': voterId,
        },
      );
      if (result.isEmpty) return null;
      return result.first[0] as String?;
    } catch (e) {
      print('Error checking user vote: $e');
      return null;
    }
  }

  // =============================================
  // TEACHER LOCATION
  // =============================================

  /// Update teacher location
  static Future<bool> updateTeacherLocation({
    required String teacherId,
    required String roomId,
    bool isAvailable = true,
  }) async {
    try {
      await _query(
        '''
        UPDATE teachers 
        SET current_room_id = @room_id, 
            current_room_updated_at = @updated_at
        WHERE id = @teacher_id
        ''',
        parameters: {
          'teacher_id': teacherId,
          'room_id': roomId,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      return true;
    } catch (e) {
      print('Error updating teacher location: $e');
      return false;
    }
  }

  /// Auto-update ALL teacher locations based on timetable
  /// Call this periodically (every minute) to sync teacher locations
  static Future<void> autoUpdateTeacherLocations() async {
    try {
      await _query('SELECT * FROM update_all_teacher_locations()');
      // Also clear locations for teachers without current class
      await _query('SELECT * FROM clear_teacher_locations_after_class()');
    } catch (e) {
      print('Error auto-updating teacher locations: $e');
    }
  }

  /// Get teacher's scheduled room for current time
  static Future<String?> getTeacherScheduledRoom(String teacherId) async {
    try {
      final result = await _query(
        'SELECT get_teacher_scheduled_room(@teacher_id)',
        parameters: {'teacher_id': teacherId},
      );
      if (result.isNotEmpty && result.first[0] != null) {
        return result.first[0] as String;
      }
      return null;
    } catch (e) {
      print('Error getting teacher scheduled room: $e');
      return null;
    }
  }

  /// Get teacher's current and next class status
  static Future<Map<String, dynamic>?> getTeacherScheduleStatus(
      String teacherId) async {
    try {
      final result = await _query(
        'SELECT * FROM get_teacher_schedule_status(@teacher_id)',
        parameters: {'teacher_id': teacherId},
      );
      if (result.isNotEmpty) {
        final columns = [
          'current_subject',
          'current_room',
          'current_end_time',
          'next_subject',
          'next_room',
          'next_start_time'
        ];
        return _rowToMap(result.first, columns);
      }
      return null;
    } catch (e) {
      print('Error getting teacher schedule status: $e');
      return null;
    }
  }

  /// Get teachers with location
  static Future<List<Teacher>> getTeachersWithLocation() async {
    try {
      final result = await _query(
        '''
        SELECT t.*, r.room_number, r.name as room_name, r.floor as room_floor
        FROM teachers t
        LEFT JOIN rooms r ON t.current_room_id = r.id
        WHERE t.current_room_id IS NOT NULL
        ORDER BY t.name
        ''',
      );
      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'phone',
        'branch_id',
        'is_hod',
        'is_admin',
        'current_room_id',
        'current_room_updated_at',
        'is_active',
        'last_login',
        'created_at',
        'updated_at',
        'room_number',
        'room_name',
        'room_floor'
      ];
      return result
          .map((row) => Teacher.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching teachers with location: $e');
      return [];
    }
  }

  /// Get all teachers with their current location info
  static Future<List<Map<String, dynamic>>> getAllTeachersWithSchedule() async {
    try {
      final result = await _query('''
        SELECT 
          t.id,
          t.name,
          t.email,
          t.phone,
          t.is_hod,
          r.name as current_room_name,
          r.room_number as current_room_number,
          r.floor as current_floor,
          t.current_room_updated_at,
          (SELECT s.name FROM timetable tt 
           JOIN subjects s ON tt.subject_id = s.id 
           WHERE tt.teacher_id = t.id 
             AND tt.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
             AND tt.start_time <= CURRENT_TIME 
             AND tt.end_time > CURRENT_TIME
           LIMIT 1) as current_subject,
          (SELECT tt.end_time FROM timetable tt 
           WHERE tt.teacher_id = t.id 
             AND tt.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
             AND tt.start_time <= CURRENT_TIME 
             AND tt.end_time > CURRENT_TIME
           LIMIT 1) as class_ends_at,
          (SELECT s.name FROM timetable tt 
           JOIN subjects s ON tt.subject_id = s.id 
           WHERE tt.teacher_id = t.id 
             AND tt.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
             AND tt.start_time > CURRENT_TIME
           ORDER BY tt.start_time
           LIMIT 1) as next_subject,
          (SELECT tt.start_time FROM timetable tt 
           WHERE tt.teacher_id = t.id 
             AND tt.day_of_week = EXTRACT(DOW FROM CURRENT_DATE)::INTEGER
             AND tt.start_time > CURRENT_TIME
           ORDER BY tt.start_time
           LIMIT 1) as next_class_at
        FROM teachers t
        LEFT JOIN rooms r ON t.current_room_id = r.id
        WHERE t.is_active = true
        ORDER BY t.name
      ''');

      final columns = [
        'id',
        'name',
        'email',
        'phone',
        'is_hod',
        'current_room_name',
        'current_room_number',
        'current_floor',
        'current_room_updated_at',
        'current_subject',
        'class_ends_at',
        'next_subject',
        'next_class_at'
      ];
      return result.map((row) => _rowToMap(row, columns)).toList();
    } catch (e) {
      print('Error fetching all teachers with schedule: $e');
      return [];
    }
  }

  // =============================================
  // SUBJECTS
  // =============================================

  /// Get subjects by branch and semester
  static Future<List<Subject>> getSubjects({
    required String branchId,
    required int semester,
  }) async {
    try {
      final result = await _query(
        '''
        SELECT * FROM subjects 
        WHERE branch_id = @branch_id AND semester = @semester
        ORDER BY name
        ''',
        parameters: {
          'branch_id': branchId,
          'semester': semester,
        },
      );
      final columns = [
        'id',
        'name',
        'code',
        'branch_id',
        'semester',
        'credits',
        'created_at'
      ];
      return result
          .map((row) => Subject.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching subjects: $e');
      return [];
    }
  }

  // =============================================
  // ANNOUNCEMENTS
  // =============================================

  /// Get announcements
  static Future<List<Announcement>> getAnnouncements({
    String? branchId,
    int? semester,
    int limit = 20,
  }) async {
    try {
      String sql = '''
        SELECT a.*, t.name as author_name
        FROM announcements a
        LEFT JOIN teachers t ON a.author_id = t.id
        WHERE 1=1
      ''';
      final params = <String, dynamic>{'limit': limit};

      if (branchId != null) {
        sql += ' AND (a.branch_id = @branch_id OR a.branch_id IS NULL)';
        params['branch_id'] = branchId;
      }
      if (semester != null) {
        sql += ' AND (a.semester = @semester OR a.semester IS NULL)';
        params['semester'] = semester;
      }

      sql += ' ORDER BY a.created_at DESC LIMIT @limit';

      final result = await _query(sql, parameters: params);
      final columns = [
        'id',
        'title',
        'content',
        'author_id',
        'branch_id',
        'semester',
        'priority',
        'created_at',
        'author_name'
      ];
      return result
          .map((row) => Announcement.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching announcements: $e');
      return [];
    }
  }

  // =============================================
  // NAVIGATION WAYPOINTS
  // =============================================

  /// Get navigation waypoints for floor
  static Future<List<NavigationWaypoint>> getWaypoints(int floor) async {
    try {
      final result = await _query(
        'SELECT * FROM navigation_waypoints WHERE floor = @floor',
        parameters: {'floor': floor},
      );
      final columns = [
        'id',
        'floor',
        'x_coordinate',
        'y_coordinate',
        'waypoint_type',
        'connected_room_id',
        'created_at'
      ];
      return result
          .map((row) => NavigationWaypoint.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching waypoints: $e');
      return [];
    }
  }

  /// Get waypoint connections
  static Future<List<WaypointConnection>> getWaypointConnections() async {
    try {
      final result = await _query('SELECT * FROM waypoint_connections');
      final columns = [
        'id',
        'from_waypoint_id',
        'to_waypoint_id',
        'distance',
        'created_at'
      ];
      return result
          .map((row) => WaypointConnection.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching waypoint connections: $e');
      return [];
    }
  }

  // =============================================
  // STUDENT OPERATIONS
  // =============================================

  /// Get student by ID
  static Future<Student?> getStudentById(String studentId) async {
    try {
      final result = await _query(
        'SELECT * FROM students WHERE id = @id',
        parameters: {'id': studentId},
      );
      if (result.isEmpty) return null;
      final columns = [
        'id',
        'email',
        'password_hash',
        'name',
        'roll_number',
        'branch_id',
        'semester',
        'phone',
        'created_at'
      ];
      return Student.fromJson(_rowToMap(result.first, columns));
    } catch (e) {
      print('Error fetching student: $e');
      return null;
    }
  }

  /// Update student profile
  static Future<bool> updateStudentProfile({
    required String studentId,
    String? name,
    String? phone,
    int? semester,
  }) async {
    try {
      final updates = <String>[];
      final params = <String, dynamic>{'id': studentId};

      if (name != null) {
        updates.add('name = @name');
        params['name'] = name;
      }
      if (phone != null) {
        updates.add('phone = @phone');
        params['phone'] = phone;
      }
      if (semester != null) {
        updates.add('semester = @semester');
        params['semester'] = semester;
      }

      if (updates.isEmpty) return false;

      await _query(
        'UPDATE students SET ${updates.join(', ')} WHERE id = @id',
        parameters: params,
      );
      return true;
    } catch (e) {
      print('Error updating student profile: $e');
      return false;
    }
  }

  // =============================================
  // TEACHER TIMETABLE
  // =============================================

  /// Get teacher's timetable
  static Future<List<TimetableEntry>> getTeacherTimetable({
    required String teacherId,
    String? dayOfWeek,
  }) async {
    try {
      String sql = '''
        SELECT t.*, s.name as subject_name, s.code as subject_code,
               r.room_number, r.room_name, r.floor as room_floor,
               b.name as branch_name
        FROM timetable t
        LEFT JOIN subjects s ON t.subject_id = s.id
        LEFT JOIN rooms r ON t.room_id = r.id
        LEFT JOIN branches b ON t.branch_id = b.id
        WHERE t.teacher_id = @teacher_id
      ''';

      final params = <String, dynamic>{'teacher_id': teacherId};

      if (dayOfWeek != null) {
        sql += ' AND t.day_of_week = @day_of_week';
        params['day_of_week'] = dayOfWeek;
      }

      sql += ' ORDER BY t.day_of_week, t.start_time';

      final result = await _query(sql, parameters: params);
      final columns = [
        'id',
        'branch_id',
        'semester',
        'subject_id',
        'teacher_id',
        'room_id',
        'day_of_week',
        'start_time',
        'end_time',
        'created_at',
        'subject_name',
        'subject_code',
        'room_number',
        'room_name',
        'room_floor',
        'branch_name'
      ];
      return result
          .map((row) => TimetableEntry.fromJson(_rowToMap(row, columns)))
          .toList();
    } catch (e) {
      print('Error fetching teacher timetable: $e');
      return [];
    }
  }

  // =============================================
  // GENERIC QUERY METHOD
  // =============================================

  /// Execute a raw query (for advanced usage)
  static Future<List<Map<String, dynamic>>> rawQuery(String sql,
      {Map<String, dynamic>? parameters}) async {
    try {
      final result = await _query(sql, parameters: parameters);
      // For raw queries, we need column info from the result
      if (result.isEmpty) return [];

      // Get column names from schema if available
      final schema = result.schema;
      final columnNames = schema.columns
          .map((c) => c.columnName ?? 'col_${schema.columns.indexOf(c)}')
          .toList();

      return result.map((row) => _rowToMap(row, columnNames)).toList();
    } catch (e) {
      print('Error executing raw query: $e');
      return [];
    }
  }
}
