import 'package:intl/intl.dart';
import 'subject.dart';
import 'teacher.dart';
import 'room.dart';

class TimetableEntry {
  final String id;
  final String branchId;
  final int semester;
  final int dayOfWeek;
  final int periodNumber;
  final String? subjectId;
  final String? teacherId;
  final String? roomId;
  final String startTime;
  final String endTime;
  final DateTime? createdAt;
  
  // Joined data
  Subject? subject;
  Teacher? teacher;
  Room? room;

  TimetableEntry({
    required this.id,
    required this.branchId,
    required this.semester,
    required this.dayOfWeek,
    required this.periodNumber,
    this.subjectId,
    this.teacherId,
    this.roomId,
    required this.startTime,
    required this.endTime,
    this.createdAt,
    this.subject,
    this.teacher,
    this.room,
  });

  factory TimetableEntry.fromJson(Map<String, dynamic> json) {
    return TimetableEntry(
      id: json['id'] ?? '',
      branchId: json['branch_id'] ?? '',
      semester: json['semester'] ?? 1,
      dayOfWeek: json['day_of_week'] ?? 0,
      periodNumber: json['period_number'] ?? 0,
      subjectId: json['subject_id'],
      teacherId: json['teacher_id'],
      roomId: json['room_id'],
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      subject: json['subjects'] != null 
          ? Subject.fromJson(json['subjects']) 
          : null,
      teacher: json['teachers'] != null 
          ? Teacher.fromJson(json['teachers']) 
          : null,
      room: json['rooms'] != null 
          ? Room.fromJson(json['rooms']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'branch_id': branchId,
      'semester': semester,
      'day_of_week': dayOfWeek,
      'period_number': periodNumber,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'room_id': roomId,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  DateTime get startDateTime {
    final now = DateTime.now();
    final parts = startTime.split(':');
    return DateTime(now.year, now.month, now.day, 
        int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime get endDateTime {
    final now = DateTime.now();
    final parts = endTime.split(':');
    return DateTime(now.year, now.month, now.day, 
        int.parse(parts[0]), int.parse(parts[1]));
  }

  String get formattedTime {
    final start = DateFormat.jm().format(startDateTime);
    final end = DateFormat.jm().format(endDateTime);
    return '$start - $end';
  }

  bool get isCurrentPeriod {
    final now = DateTime.now();
    return now.isAfter(startDateTime) && now.isBefore(endDateTime);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    return now.isBefore(startDateTime);
  }

  Duration get timeUntilStart {
    final now = DateTime.now();
    return startDateTime.difference(now);
  }

  Duration get timeRemaining {
    final now = DateTime.now();
    return endDateTime.difference(now);
  }
}
