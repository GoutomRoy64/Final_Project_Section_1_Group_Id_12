import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/routine_model.dart';

class RoutineProvider with ChangeNotifier {
  List<Routine> _routines = [];
  bool _isLoading = false;

  List<Routine> get routines => _routines;
  bool get isLoading => _isLoading;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref().child('routine');

  // 1. Fetch All Routines
  Future<void> fetchRoutines() async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _dbRef.get();
      final List<Routine> loadedRoutines = [];

      if (snapshot.exists) {
        Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          loadedRoutines.add(Routine.fromMap(key, value));
        });
      }

      _routines = loadedRoutines;
    } catch (error) {
      print("Error fetching routines: $error");
    }

    _isLoading = false;
    notifyListeners();
  }

  // 2. Add a new Routine
  Future<void> addRoutine(String courseId, String day, String time) async {
    try {
      final newRoutineRef = _dbRef.push();
      final newRoutine = Routine(
        id: newRoutineRef.key!,
        courseId: courseId,
        day: day,
        time: time,
      );

      await newRoutineRef.set(newRoutine.toMap());

      _routines.add(newRoutine);
      notifyListeners();
    } catch (error) {
      print("Error adding routine: $error");
      rethrow;
    }
  }

  // 3. Update an existing Routine (This was the missing method)
  Future<void> updateRoutine(String id, String courseId, String day, String time) async {
    try {
      final index = _routines.indexWhere((r) => r.id == id);
      if (index >= 0) {
        final updatedRoutine = Routine(
          id: id,
          courseId: courseId,
          day: day,
          time: time,
        );

        await _dbRef.child(id).update(updatedRoutine.toMap());

        _routines[index] = updatedRoutine;
        notifyListeners();
      }
    } catch (error) {
      print("Error updating routine: $error");
      rethrow;
    }
  }

  // 4. Delete a Routine
  Future<void> deleteRoutine(String routineId) async {
    try {
      await _dbRef.child(routineId).remove();
      _routines.removeWhere((r) => r.id == routineId);
      notifyListeners();
    } catch (error) {
      print("Error deleting routine: $error");
      rethrow;
    }
  }

  // Helper: Get routines for a specific day
  List<Routine> getRoutinesByDay(String day) {
    return _routines.where((routine) => routine.day.toLowerCase() == day.toLowerCase()).toList();
  }
}