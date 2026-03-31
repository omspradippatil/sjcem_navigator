import '../models/models.dart';

/// Study file with extended metadata for search and bookmarking
class StudyFileExtended extends StudyFile {
  final List<String>? tags; // smart tags
  final String? teacher; // original uploader
  final String? subject;
  final int? semester;
  final String? branch;
  final bool isBookmarked;
  final DateTime? lastAccessedAt;
  final int accessCount;
  
  StudyFileExtended({
    required super.id,
    required super.folderId,
    required super.name,
    required super.fileUrl,
    required super.fileType,
    required super.fileSize,
    required super.uploadedBy,
    super.createdAt,
    super.updatedAt,
    this.tags,
    this.teacher,
    this.subject,
    this.semester,
    this.branch,
    this.isBookmarked = false,
    this.lastAccessedAt,
    this.accessCount = 0,
  });

  factory StudyFileExtended.fromJson(Map<String, dynamic> json) {
    return StudyFileExtended(
      id: json['id'] ?? '',
      folderId: json['folder_id'] ?? '',
      name: json['name'] ?? '',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? 'pdf',
        fileSize: json['file_size'] ?? json['size_bytes'] ?? 0,
        uploadedBy: json['uploaded_by'] ?? '',
        createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['uploaded_at'] != null
            ? DateTime.parse(json['uploaded_at'])
            : null),
        updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      teacher: json['teacher'],
      subject: json['subject'],
      semester: json['semester'],
      branch: json['branch'],
      isBookmarked: json['is_bookmarked'] ?? false,
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'])
          : null,
      accessCount: json['access_count'] ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'folder_id': folderId,
      'name': name,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'uploaded_by': uploadedBy,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'tags': tags,
      'teacher': teacher,
      'subject': subject,
      'semester': semester,
      'branch': branch,
      'is_bookmarked': isBookmarked,
      'last_accessed_at': lastAccessedAt?.toIso8601String(),
      'access_count': accessCount,
    };
  }

  /// Get display size (KB, MB, GB)
  String get displaySize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    if (fileSize < 1024 * 1024 * 1024) return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Get file icon based on type
  String get iconType {
    switch (fileType.toLowerCase()) {
      case 'pdf': return '📄';
      case 'doc':
      case 'docx': return '📝';
      case 'ppt':
      case 'pptx': return '🎞️';
      case 'xls':
      case 'xlsx': return '📊';
      case 'jpg':
      case 'jpeg':
      case 'png': return '🖼️';
      case 'zip':
      case 'rar': return '📦';
      case 'mp4':
      case 'avi':
      case 'mov': return '🎬';
      case 'mp3':
      case 'wav': return '🎵';
      default: return '📄';
    }
  }
}

/// Search result for study materials
class StudySearchResult {
  final StudyFileExtended file;
  final double relevanceScore; // 0-1
  final String matchType; // filename, tags, subject, teacher
  final List<String> matchedKeywords;
  
  StudySearchResult({
    required this.file,
    required this.relevanceScore,
    required this.matchType,
    required this.matchedKeywords,
  });

  bool get isHighRelevance => relevanceScore >= 0.8;
}

/// Bookmark/favorite tracking
class StudyBookmark {
  final String id;
  final String studentId;
  final String fileId;
  final DateTime bookmarkedAt;
  final String? notes; // personal notes about file
  
  StudyBookmark({
    required this.id,
    required this.studentId,
    required this.fileId,
    required this.bookmarkedAt,
    this.notes,
  });

  factory StudyBookmark.fromJson(Map<String, dynamic> json) {
    return StudyBookmark(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      fileId: json['file_id'] ?? '',
      bookmarkedAt: json['bookmarked_at'] != null
          ? DateTime.parse(json['bookmarked_at'])
          : DateTime.now(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'file_id': fileId,
      'bookmarked_at': bookmarkedAt.toIso8601String(),
      'notes': notes,
    };
  }
}

/// Recently accessed tracking
class StudyRecentFile {
  final String fileId;
  final String fileName;
  final String fileType;
  final DateTime lastAccessedAt;
  final int accessCount;
  
  StudyRecentFile({
    required this.fileId,
    required this.fileName,
    required this.fileType,
    required this.lastAccessedAt,
    this.accessCount = 1,
  });

  factory StudyRecentFile.fromJson(Map<String, dynamic> json) {
    return StudyRecentFile(
      fileId: json['file_id'] ?? '',
      fileName: json['file_name'] ?? '',
      fileType: json['file_type'] ?? 'pdf',
      lastAccessedAt: json['last_accessed_at'] != null
          ? DateTime.parse(json['last_accessed_at'])
          : DateTime.now(),
      accessCount: json['access_count'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_id': fileId,
      'file_name': fileName,
      'file_type': fileType,
      'last_accessed_at': lastAccessedAt.toIso8601String(),
      'access_count': accessCount,
    };
  }
}

/// Full-text search parameters
class StudyMaterialsSearchQuery {
  final String keywords; // Search text
  final List<String>? filterByTeacher;
  final List<String>? filterBySubject;
  final List<int>? filterBySemester;
  final List<String>? filterByBranch;
  final List<String>? filterByTags;
  final String? sortBy; // relevance, date, name, size
  final bool ascending;
  final bool bookmarkedOnly;
  
  StudyMaterialsSearchQuery({
    required this.keywords,
    this.filterByTeacher,
    this.filterBySubject,
    this.filterBySemester,
    this.filterByBranch,
    this.filterByTags,
    this.sortBy = 'relevance',
    this.ascending = false,
    this.bookmarkedOnly = false,
  });
}
