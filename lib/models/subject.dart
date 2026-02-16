class Subject {
  final String id;
  final String name;
  final String code;
  final String? branchId;
  final int semester;
  final int credits;
  final bool isLab;
  final DateTime? createdAt;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    this.branchId,
    required this.semester,
    this.credits = 3,
    this.isLab = false,
    this.createdAt,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      branchId: json['branch_id'],
      semester: json['semester'] ?? 1,
      credits: json['credits'] ?? 3,
      isLab: json['is_lab'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'branch_id': branchId,
      'semester': semester,
      'credits': credits,
      'is_lab': isLab,
    };
  }
}
