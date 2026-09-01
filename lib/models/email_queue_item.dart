class EmailQueueItem {
  final int? id;
  final String parentEmail;
  final String parentMobile;
  final String studentName;
  final String guardianName;
  final String pickupTimestamp;
  final int isSent; // 0 = No (Pending), 1 = Yes (Sent)
  final String? errorMessage;

  EmailQueueItem({
    this.id,
    required this.parentEmail,
    required this.parentMobile,
    required this.studentName,
    required this.guardianName,
    required this.pickupTimestamp,
    this.isSent = 0,
    this.errorMessage,
  });

  bool get sent => isSent == 1;

  Map<String, dynamic> toSqliteMap() {
    final map = <String, dynamic>{
      'parent_email': parentEmail,
      'parent_mobile': parentMobile,
      'student_name': studentName,
      'guardian_name': guardianName,
      'pickup_timestamp': pickupTimestamp,
      'is_sent': isSent,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory EmailQueueItem.fromSqliteMap(Map<String, dynamic> map) {
    return EmailQueueItem(
      id: map['id'] as int?,
      parentEmail: (map['parent_email'] as String?) ?? '',
      parentMobile: (map['parent_mobile'] as String?) ?? '',
      studentName: (map['student_name'] as String?) ?? '',
      guardianName: (map['guardian_name'] as String?) ?? '',
      pickupTimestamp: (map['pickup_timestamp'] as String?) ?? '',
      isSent: (map['is_sent'] as int?) ?? 0,
      errorMessage: map['error_message'] as String?,
    );
  }

  EmailQueueItem copyWith({
    int? id,
    String? parentEmail,
    String? parentMobile,
    String? studentName,
    String? guardianName,
    String? pickupTimestamp,
    int? isSent,
    String? errorMessage,
  }) {
    return EmailQueueItem(
      id: id ?? this.id,
      parentEmail: parentEmail ?? this.parentEmail,
      parentMobile: parentMobile ?? this.parentMobile,
      studentName: studentName ?? this.studentName,
      guardianName: guardianName ?? this.guardianName,
      pickupTimestamp: pickupTimestamp ?? this.pickupTimestamp,
      isSent: isSent ?? this.isSent,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
