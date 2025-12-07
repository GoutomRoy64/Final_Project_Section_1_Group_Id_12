import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Auth
import '../models/course_model.dart';

class CourseProvider with ChangeNotifier {
  List<Course> _courses = [];
  bool _isLoading = false;

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;

  final CollectionReference _coursesRef = FirebaseFirestore.instance.collection('courses');

  // Helper to get current User ID
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> fetchCourses() async {
    if (_userId == null) return; // Guard: No user logged in

    _isLoading = true;
    notifyListeners();
    try {
      // FILTER: Only get courses created by THIS user
      final snapshot = await _coursesRef.where('userId', isEqualTo: _userId).get();

      _courses = snapshot.docs.map((doc) {
        return Course.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (error) {
      print("Error: $error");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCourse(String name, String code) async {
    if (_userId == null) return;

    try {
      final newDoc = _coursesRef.doc();
      final newCourse = Course(id: newDoc.id, name: name, code: code);

      // SAVE: Add userId to the document
      Map<String, dynamic> data = newCourse.toMap();
      data['userId'] = _userId;

      await newDoc.set(data);
      _courses.add(newCourse);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateCourse(String id, String newName, String newCode) async {
    try {
      final updatedCourse = Course(id: id, name: newName, code: newCode);

      // Ensure we preserve the userId (or specific fields)
      await _coursesRef.doc(id).update({
        'name': newName,
        'code': newCode,
      });

      final index = _courses.indexWhere((c) => c.id == id);
      if (index >= 0) _courses[index] = updatedCourse;
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      await _coursesRef.doc(id).delete();
      _courses.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }
}