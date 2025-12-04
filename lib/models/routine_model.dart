class Routine {
  final String id; // routineId
  final String courseId;
  final String day; // e.g., "Monday"
  final String time; // e.g., "10:00 AM"

  Routine({
    required this.id,
    required this.courseId,
    required this.day,
    required this.time,
  });

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'day': day,
      'time': time,
    };
  }

  factory Routine.fromMap(String id, Map<dynamic, dynamic> map) {
    return Routine(
      id: id,
      courseId: map['courseId'] ?? '',
      day: map['day'] ?? '',
      time: map['time'] ?? '',
    );
  }
}