import 'dart:convert';

class QrPayloadModel {
  final String studentId;
  final String studentName;
  final String grade;
  final String guardianName;
  final String parentMobile;
  final String parentEmail;
  final String status;
  final String approvalToken;
  final int timestamp; // Milliseconds since epoch

  QrPayloadModel({
    required this.studentId,
    this.studentName = '',
    this.grade = '',
    required this.guardianName,
    required this.parentMobile,
    required this.parentEmail,
    this.status = 'APPROVED',
    this.approvalToken = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'student_name': studentName,
      'grade': grade,
      'guardian_name': guardianName,
      'parent_mobile': parentMobile,
      'parent_email': parentEmail,
      'status': status,
      'approval_token': approvalToken,
      'timestamp': timestamp,
    };
  }

  String toJsonString() {
    return jsonEncode(toMap());
  }

  factory QrPayloadModel.fromMap(Map<String, dynamic> map) {
    return QrPayloadModel(
      studentId: map['student_id'] as String? ?? '',
      studentName: map['student_name'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
      guardianName: map['guardian_name'] as String? ?? '',
      parentMobile: map['parent_mobile'] as String? ?? '',
      parentEmail: map['parent_email'] as String? ?? '',
      status: map['status'] as String? ?? 'APPROVED',
      approvalToken: map['approval_token'] as String? ?? '',
      timestamp: (map['timestamp'] is int)
          ? map['timestamp'] as int
          : int.tryParse(map['timestamp']?.toString() ?? '') ?? 0,
    );
  }

  factory QrPayloadModel.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return QrPayloadModel.fromMap(map);
  }
}
