import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/routine_model.dart';

class RoutineProvider with ChangeNotifier {
  List<Routine> _routines = [];
  bool _isLoading = false;

  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;

  final CollectionReference _routineRef = FirebaseFirestore.instance.collection('routines');

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  Future<void> fetchRoutines() async {
    if (_userId == null) return;

    _isLoading = true;
    notifyListeners();
    try {
      // FILTER: Only fetch routines created by current user
      final snapshot = await _routineRef.where('userId', isEqualTo: _userId).get();

      _routines = snapshot.docs.map((doc) {
        return Routine.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (error) {
      print("Error: $error");
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addRoutine(String courseId, String day, String time) async {
    if (_userId == null) return;

    try {
      final newDoc = _routineRef.doc();
      final newRoutine = Routine(id: newDoc.id, courseId: courseId, day: day, time: time);

      // SAVE with userId
      Map<String, dynamic> data = newRoutine.toMap();
      data['userId'] = _userId;

      await newDoc.set(data);
      _routines.add(newRoutine);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> updateRoutine(String id, String courseId, String day, String time) async {
    try {
      final updatedRoutine = Routine(id: id, courseId: courseId, day: day, time: time);
      await _routineRef.doc(id).update(updatedRoutine.toMap());

      final index = _routines.indexWhere((r) => r.id == id);
      if (index >= 0) _routines[index] = updatedRoutine;
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  Future<void> deleteRoutine(String routineId) async {
    try {
      await _routineRef.doc(routineId).delete();
      _routines.removeWhere((r) => r.id == routineId);
      notifyListeners();
    } catch (error) {
      rethrow;
    }
  }

  List<Routine> getRoutinesByDay(String day) {
    return _routines.where((routine) => routine.day.toLowerCase() == day.toLowerCase()).toList();
  }
}