class StudyFile {
  final String id;
  final String name;
  final String folderId;
  final String fileUrl;
  final String fileType; // pdf, doc, image, etc.
  final int fileSize; // in bytes
  final String? description;
  final String uploadedBy; // teacher ID
  final int downloadCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StudyFile({
    required this.id,
    required this.name,
    required this.folderId,
    required this.fileUrl,
    required this.fileType,
    required this.fileSize,
    this.description,
    required this.uploadedBy,
    this.downloadCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  factory StudyFile.fromJson(Map<String, dynamic> json) {
    return StudyFile(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      folderId: json['folder_id'] ?? '',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? 'unknown',
      fileSize: json['file_size'] ?? 0,
      description: json['description'],
      uploadedBy: json['uploaded_by'] ?? '',
      downloadCount: json['download_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'folder_id': folderId,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'description': description,
      'uploaded_by': uploadedBy,
      'download_count': downloadCount,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'folder_id': folderId,
      'file_url': fileUrl,
      'file_type': fileType,
      'file_size': fileSize,
      'description': description,
      'uploaded_by': uploadedBy,
    };
  }

  StudyFile copyWith({
    String? id,
    String? name,
    String? folderId,
    String? fileUrl,
    String? fileType,
    int? fileSize,
    String? description,
    String? uploadedBy,
    int? downloadCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyFile(
      id: id ?? this.id,
      name: name ?? this.name,
      folderId: folderId ?? this.folderId,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileSize: fileSize ?? this.fileSize,
      description: description ?? this.description,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      downloadCount: downloadCount ?? this.downloadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  String get fileExtension {
    final parts = name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
