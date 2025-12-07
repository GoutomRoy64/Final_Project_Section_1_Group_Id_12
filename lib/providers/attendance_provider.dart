import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_model.dart';

class AttendanceProvider with ChangeNotifier {
  AttendanceRecord? _currentDateRecord;
  bool _isLoading = false;

  AttendanceRecord? get currentDateRecord => _currentDateRecord;
  bool get isLoading => _isLoading;

  final CollectionReference _attRef = FirebaseFirestore.instance.collection('attendance');
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  String _getDocId(String courseId, String date) => "${courseId}_$date";

  Future<void> markAttendance(String courseId, String date, Map<String, String> statusMap) async {
    if (_userId == null) return;
    try {
      final docId = _getDocId(courseId, date);

      await _attRef.doc(docId).set({
        'courseId': courseId,
        'date': date,
        'status': statusMap,
        'userId': _userId, // TAGGING RECORD
      });

      _currentDateRecord = AttendanceRecord(date: date, studentStatus: statusMap);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> fetchAttendance(String courseId, String date) async {
    _isLoading = true;
    _currentDateRecord = null;
    notifyListeners();

    try {
      final docId = _getDocId(courseId, date);
      final doc = await _attRef.doc(docId).get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        _currentDateRecord = AttendanceRecord.fromMap(date, data);
      } else {
        _currentDateRecord = AttendanceRecord(date: date, studentStatus: {});
      }
    } catch (error) {
      print("Error: $error");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, Map<String, dynamic>>> getAttendanceSummary(String courseId) async {
    _isLoading = true;
    notifyListeners();

    Map<String, Map<String, dynamic>> summary = {};

    try {
      final snapshot = await _attRef.where('courseId', isEqualTo: courseId).get();

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        if (data['status'] != null) {
          Map<String, dynamic> statusMap = data['status'];

          statusMap.forEach((studentId, status) {
            if (!summary.containsKey(studentId)) {
              summary[studentId] = {'present': 0, 'total': 0, 'percent': 0.0};
            }
            summary[studentId]!['total'] += 1;
            if (status == 'Present') {
              summary[studentId]!['present'] += 1;
            }
          });
        }
      }

      summary.forEach((studentId, data) {
        if (data['total'] > 0) {
          double percent = (data['present'] / data['total']) * 100;
          summary[studentId]!['percent'] = double.parse(percent.toStringAsFixed(1));
        }
      });

    } catch (error) {
      print("Error: $error");
    }

    _isLoading = false;
    notifyListeners();
    return summary;
  }
}