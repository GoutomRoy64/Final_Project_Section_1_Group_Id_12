import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/student_model.dart';

class StudentProvider with ChangeNotifier {
  List<Student> _students = [];
  bool _isLoading = false;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('students');

  // 1. Fetch students for a specific Course
  Future<void> fetchStudents(String courseId) async {
    _isLoading = true;
    // Clear previous list so UI doesn't show wrong students while loading
    _students = [];
    notifyListeners();

    try {
      // Target specific course node: /students/courseId
      final snapshot = await _dbRef.child(courseId).get();
      final List<Student> loadedStudents = [];

      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          loadedStudents.add(Student.fromMap(key, value));
        });
      }

      _students = loadedStudents;
      // Optional: Sort by Roll Number/ID
      _students.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));

    } catch (error) {
      print("Error fetching students: $error");
    }

    _isLoading = false;
    notifyListeners();
  }

  // 2. Add a student to a specific Course
  Future<void> addStudent(String courseId, String name, String rollNumber) async {
    try {
      // Path: /students/courseId/
      final newStudentRef = _dbRef.child(courseId).push();
      final newStudent = Student(
          id: newStudentRef.key!,
          name: name,
          rollNumber: rollNumber
      );

      await newStudentRef.set(newStudent.toMap());

      _students.add(newStudent);
      _students.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      notifyListeners();
    } catch (error) {
      print("Error adding student: $error");
      rethrow;
    }
  }

  // 3. Remove a student from a course
  Future<void> deleteStudent(String courseId, String studentId) async {
    try {
      // Path: /students/courseId/studentId
      await _dbRef.child(courseId).child(studentId).remove();

      _students.removeWhere((s) => s.id == studentId);
      notifyListeners();
    } catch (error) {
      print("Error deleting student: $error");
      rethrow;
    }
  }

  // 4. Update a student
  Future<void> updateStudent(String courseId, String studentId, String newName, String newRoll) async {
    try {
      final studentIndex = _students.indexWhere((s) => s.id == studentId);
      if(studentIndex >= 0) {
        final updatedStudent = Student(id: studentId, name: newName, rollNumber: newRoll);

        await _dbRef.child(courseId).child(studentId).update(updatedStudent.toMap());

        _students[studentIndex] = updatedStudent;
        notifyListeners();
      }
    } catch (error) {
      print("Error updating student: $error");
      rethrow;
    }
  }
}