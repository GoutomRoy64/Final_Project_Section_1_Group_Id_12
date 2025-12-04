import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/attendance_model.dart';

class AttendanceProvider with ChangeNotifier {
  // Stores the attendance record for the specific date we are currently viewing
  AttendanceRecord? _currentDateRecord;
  bool _isLoading = false;

  AttendanceRecord? get currentDateRecord => _currentDateRecord;
  bool get isLoading => _isLoading;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('attendance');

  // 1. Save or Update Attendance for a specific Date
  Future<void> markAttendance(String courseId, String date, Map<String, String> statusMap) async {
    try {
      // Path: /attendance/courseId/date/
      // We explicitly wrap it in 'status' to match the model structure
      await _dbRef.child(courseId).child(date).set({
        'status': statusMap,
      });

      // Update local state if we are currently viewing this date
      _currentDateRecord = AttendanceRecord(date: date, studentStatus: statusMap);
      notifyListeners();
    } catch (error) {
      print("Error marking attendance: $error");
      rethrow;
    }
  }

  // 2. Fetch Attendance for a specific Date
  Future<void> fetchAttendance(String courseId, String date) async {
    _isLoading = true;
    _currentDateRecord = null; // Reset while loading
    notifyListeners();

    try {
      final snapshot = await _dbRef.child(courseId).child(date).get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

        // We wrap the data in a map structure that our Model expects
        // The model expects { 'status': ... } but snapshot.value IS that map if we queried the date node
        // Actually, based on the save structure above, snapshot.value will be { 'status': {...} }
        _currentDateRecord = AttendanceRecord.fromMap(date, data);
      } else {
        // If no data exists for this date, we create an empty record
        _currentDateRecord = AttendanceRecord(date: date, studentStatus: {});
      }
    } catch (error) {
      print("Error fetching attendance: $error");
    }

    _isLoading = false;
    notifyListeners();
  }

  // 3. Calculate Attendance Summary (Total Classes, Present Count, Percentage)
  // Returns a Map: { studentId: { 'present': 5, 'total': 10, 'percent': 50.0 } }
  Future<Map<String, Map<String, dynamic>>> getAttendanceSummary(String courseId) async {
    _isLoading = true;
    notifyListeners();

    Map<String, Map<String, dynamic>> summary = {};

    try {
      // Fetch ALL dates for this course
      final snapshot = await _dbRef.child(courseId).get();

      if (snapshot.exists) {
        Map<dynamic, dynamic> allDates = snapshot.value as Map<dynamic, dynamic>;

        // Iterate through every date (e.g., "2023-10-01", "2023-10-02")
        allDates.forEach((dateKey, dateValue) {
          if (dateValue['status'] != null) {
            Map<dynamic, dynamic> statusMap = dateValue['status'];

            // Iterate through every student in that date
            statusMap.forEach((studentId, status) {
              // Initialize if not exists
              if (!summary.containsKey(studentId)) {
                summary[studentId] = {'present': 0, 'total': 0, 'percent': 0.0};
              }

              // Increment total classes for this student
              summary[studentId]!['total'] += 1;

              // Increment present count
              if (status == 'Present') {
                summary[studentId]!['present'] += 1;
              }
            });
          }
        });

        // Final Calculation of Percentage
        summary.forEach((studentId, data) {
          double percent = (data['present'] / data['total']) * 100;
          summary[studentId]!['percent'] = double.parse(percent.toStringAsFixed(1));
        });
      }
    } catch (error) {
      print("Error calculating summary: $error");
    }

    _isLoading = false;
    notifyListeners();
    return summary;
  }
}