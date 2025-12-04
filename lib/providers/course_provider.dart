import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/course_model.dart';

class CourseProvider with ChangeNotifier {
  List<Course> _courses = [];
  bool _isLoading = false;

  List<Course> get courses => _courses;
  bool get isLoading => _isLoading;

  // Reference to the main 'courses' node in Firebase
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('courses');

  // 1. Fetch all courses from Firebase
  Future<void> fetchCourses() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _dbRef.get();
      final List<Course> loadedCourses = [];

      if (snapshot.exists) {
        // Convert Firebase Map to List of Course objects
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          loadedCourses.add(Course.fromMap(key, value));
        });
      }

      _courses = loadedCourses;
    } catch (error) {
      print("Error fetching courses: $error");
      // Handle error appropriately in production
    }

    _isLoading = false;
    notifyListeners();
  }

  // 2. Add a new course
  Future<void> addCourse(String name, String code) async {
    try {
      // push() creates a unique ID (key) automatically
      final newCourseRef = _dbRef.push();
      final newCourse = Course(id: newCourseRef.key!, name: name, code: code);

      await newCourseRef.set(newCourse.toMap());

      // Update local list immediately (Optimistic update)
      _courses.add(newCourse);
      notifyListeners();
    } catch (error) {
      print("Error adding course: $error");
      rethrow;
    }
  }

  // 3. Update an existing course
  Future<void> updateCourse(String id, String newName, String newCode) async {
    try {
      final courseIndex = _courses.indexWhere((c) => c.id == id);
      if (courseIndex >= 0) {
        final updatedCourse = Course(id: id, name: newName, code: newCode);

        // Update specific path in Firebase
        await _dbRef.child(id).update(updatedCourse.toMap());

        _courses[courseIndex] = updatedCourse;
        notifyListeners();
      }
    } catch (error) {
      print("Error updating course: $error");
      rethrow;
    }
  }

  // 4. Delete a course
  Future<void> deleteCourse(String id) async {
    try {
      await _dbRef.child(id).remove();
      _courses.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (error) {
      print("Error deleting course: $error");
      rethrow;
    }
  }
}