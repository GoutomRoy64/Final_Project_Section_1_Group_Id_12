class AttendanceRecord {
  final String date; // Using date as the ID
  final Map<String, String> studentStatus; // Key: StudentID, Value: "Present" or "Absent"

  AttendanceRecord({
    required this.date,
    required this.studentStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'status': studentStatus,
    };
  }

  factory AttendanceRecord.fromMap(String date, Map<dynamic, dynamic> map) {
    // We need to safely convert the nested 'status' map
    Map<String, String> statusMap = {};
    if (map['status'] != null) {
      Map<dynamic, dynamic> rawStatus = map['status'];
      rawStatus.forEach((key, value) {
        statusMap[key.toString()] = value.toString();
      });
    }

    return AttendanceRecord(
      date: date,
      studentStatus: statusMap,
    );
  }
}