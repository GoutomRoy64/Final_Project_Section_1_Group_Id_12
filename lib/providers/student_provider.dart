import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/student_model.dart';

class StudentProvider with ChangeNotifier {
  List<Student> _students = [];
  bool _isLoading = false;

  List<Student> get students => _students;
  bool get isLoading => _isLoading;

  final CollectionReference _studentsRef = FirebaseFirestore.instance.collection('students');
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  // We fetch by courseId, so strictly speaking this is safe IF courses are safe.
  Future<void> fetchStudents(String courseId) async {
    _isLoading = true;
    _students = [];
    notifyListeners();
    try {
      final snapshot = await _studentsRef.where('courseId', isEqualTo: courseId).get();

      _students = snapshot.docs.map((doc) {
        return Student.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      _students.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
    } catch (error) {
      print("Error: $error");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addStudent(String courseId, String name, String rollNumber) async {
    if (_userId == null) return;
    try {
      final newDoc = _studentsRef.doc();
      final newStudent = Student(id: newDoc.id, name: name, rollNumber: rollNumber);

      Map<String, dynamic> data = newStudent.toMap();
      data['courseId'] = courseId;
      data['userId'] = _userId; // TAGGING STUDENT WITH TEACHER ID

      await newDoc.set(data);
      _students.add(newStudent);
      _students.sort((a, b) => a.rollNumber.compareTo(b.rollNumber));
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteStudent(String courseId, String studentId) async {
    try {
      await _studentsRef.doc(studentId).delete();
      _students.removeWhere((s) => s.id == studentId);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateStudent(String courseId, String studentId, String newName, String newRoll) async {
    try {
      final updatedStudent = Student(id: studentId, name: newName, rollNumber: newRoll);
      Map<String, dynamic> data = updatedStudent.toMap();
      // Only update specific fields to avoid overwriting courseId/userId accidentally
      await _studentsRef.doc(studentId).update({
        'name': newName,
        'rollNumber': newRoll,
      });

      final index = _students.indexWhere((s) => s.id == studentId);
      if(index >= 0) {
        _students[index] = updatedStudent;
        notifyListeners();
      }
    } catch (error) {
      rethrow;
    }
  }
}