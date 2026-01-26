class StudyFolder {
  final String id;
  final String name;
  final String? description;
  final String? parentId; // null means root folder
  final String createdBy; // teacher ID
  final String? subjectId;
  final String? branchId;
  final int? semester;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  StudyFolder({
    required this.id,
    required this.name,
    this.description,
    this.parentId,
    required this.createdBy,
    this.subjectId,
    this.branchId,
    this.semester,
    this.createdAt,
    this.updatedAt,
  });

  factory StudyFolder.fromJson(Map<String, dynamic> json) {
    return StudyFolder(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      parentId: json['parent_id'],
      createdBy: json['created_by'] ?? '',
      subjectId: json['subject_id'],
      branchId: json['branch_id'],
      semester: json['semester'],
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
      'description': description,
      'parent_id': parentId,
      'created_by': createdBy,
      'subject_id': subjectId,
      'branch_id': branchId,
      'semester': semester,
    };
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'name': name,
      'description': description,
      'parent_id': parentId,
      'created_by': createdBy,
      'subject_id': subjectId,
      'branch_id': branchId,
      'semester': semester,
    };
  }

  StudyFolder copyWith({
    String? id,
    String? name,
    String? description,
    String? parentId,
    String? createdBy,
    String? subjectId,
    String? branchId,
    int? semester,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      createdBy: createdBy ?? this.createdBy,
      subjectId: subjectId ?? this.subjectId,
      branchId: branchId ?? this.branchId,
      semester: semester ?? this.semester,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
