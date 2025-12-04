class Student {
  final String id; // The database key
  final String name;
  final String rollNumber; // The 'studentId' field in your image

  Student({
    required this.id,
    required this.name,
    required this.rollNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentName': name,
      'studentId': rollNumber,
    };
  }

  factory Student.fromMap(String id, Map<dynamic, dynamic> map) {
    return Student(
      id: id,
      name: map['studentName'] ?? '',
      rollNumber: map['studentId'] ?? '',
    );
  }
}