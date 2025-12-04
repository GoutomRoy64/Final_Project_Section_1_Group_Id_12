class Course {
  final String id; // This is the 'courseId' from Firebase
  final String name;
  final String code;

  Course({
    required this.id,
    required this.name,
    required this.code,
  });

  // Convert a Course object into a Map to save to Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
    };
  }

  // Create a Course object from Firebase data
  factory Course.fromMap(String id, Map<dynamic, dynamic> map) {
    return Course(
      id: id,
      name: map['name'] ?? '',
      code: map['code'] ?? '',
    );
  }
}