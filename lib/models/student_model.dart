class StudentModel {
  final String id;
  final String name;
  final String grade;
  final String supervisor;
  final String parentEmail;
  final String parentMobile;
  final String guardianName;
  final String? photoPath;
  final String status; // 'PENDING_APPROVAL', 'APPROVED', 'REJECTED'
  final int updatedAt;

  StudentModel({
    required this.id,
    required this.name,
    required this.grade,
    required this.supervisor,
    required this.parentEmail,
    required this.parentMobile,
    required this.guardianName,
    this.photoPath,
    this.status = 'PENDING_APPROVAL',
    required this.updatedAt,
  });

  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isPending => status.toUpperCase() == 'PENDING_APPROVAL' || status.toUpperCase() == 'PENDING';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isRevoked => status.toUpperCase() == 'REVOKED';

  Map<String, dynamic> toSqliteMap() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
      'supervisor': supervisor,
      'parent_email': parentEmail,
      'parent_mobile': parentMobile,
      'guardian_name': guardianName,
      'photo_path': photoPath,
      'status': status,
      'updated_at': updatedAt,
    };
  }

  factory StudentModel.fromSqliteMap(Map<String, dynamic> map) {
    return StudentModel(
      id: map['id'] as String,
      name: map['name'] as String,
      grade: map['grade'] as String,
      supervisor: map['supervisor'] as String,
      parentEmail: map['parent_email'] as String,
      parentMobile: (map['parent_mobile'] as String?) ?? '',
      guardianName: map['guardian_name'] as String,
      photoPath: map['photo_path'] as String?,
      status: (map['status'] as String?) ?? 'PENDING_APPROVAL',
      updatedAt: (map['updated_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'student_id': id,
      'name': name,
      'grade': grade,
      'supervisor': supervisor,
      'parent_email': parentEmail,
      'parent_mobile': parentMobile,
      'guardian_name': guardianName,
      'photo_url': photoPath,
      'status': status,
      'submitted_at': updatedAt,
      'approved_at': isApproved ? updatedAt : null,
    };
  }

  factory StudentModel.fromFirestoreMap(Map<String, dynamic> map, String docId) {
    return StudentModel(
      id: docId.isNotEmpty ? docId : (map['student_id'] as String? ?? ''),
      name: map['name'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
      supervisor: map['supervisor'] as String? ?? '',
      parentEmail: map['parent_email'] as String? ?? '',
      parentMobile: map['parent_mobile'] as String? ?? '',
      guardianName: map['guardian_name'] as String? ?? '',
      photoPath: map['photo_url'] as String?,
      status: map['status'] as String? ?? 'PENDING_APPROVAL',
      updatedAt: (map['submitted_at'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? grade,
    String? supervisor,
    String? parentEmail,
    String? parentMobile,
    String? guardianName,
    String? photoPath,
    String? status,
    int? updatedAt,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      grade: grade ?? this.grade,
      supervisor: supervisor ?? this.supervisor,
      parentEmail: parentEmail ?? this.parentEmail,
      parentMobile: parentMobile ?? this.parentMobile,
      guardianName: guardianName ?? this.guardianName,
      photoPath: photoPath ?? this.photoPath,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
