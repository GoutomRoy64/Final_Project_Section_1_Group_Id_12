import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- ADDED THIS IMPORT
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/routine_provider.dart';
import 'attendance_summary_screen.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const TakeAttendanceScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, String> _attendanceStatus = {};
  Map<String, Map<String, dynamic>> _summaryData = {};
  bool _isLoading = false;

  // --- ATTENDANCE PHASES ---
  // 0: Initial (Can Mark Present/Absent) -> Button: "Save Attendance"
  // 1: Late Mode (Can Mark Late only)     -> Button: "Save Late Attendance"
  // 2: Completed (Read Only)              -> Button: "Submitted & Locked"
  int _saveState = 0;

  // --- TIME CONSTRAINTS ---
  bool _isWithinTimeWindow = false;
  String _statusMessage = "Checking schedule...";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final stuProvider = Provider.of<StudentProvider>(context, listen: false);
    final routineProvider = Provider.of<RoutineProvider>(context, listen: false);

    // 1. Fetch Necessary Data
    await stuProvider.fetchStudents(widget.courseId);
    await routineProvider.fetchRoutines();

    // 2. Fetch Existing Attendance Status from DB
    await _fetchAttendanceStatus();

    // 3. Get Summary Statistics for UI (Calculated Locally for Accuracy)
    await _fetchSummaryStats();

    // 4. Validate Time (Is class running right now?)
    _checkTimeConstraint(routineProvider);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- LOGIC: CALCULATE STATS LOCALLY ---
  // Fixes the issue where 'Late' count wasn't updating because Provider might miss it.
  Future<void> _fetchSummaryStats() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('courseId', isEqualTo: widget.courseId)
          .get();

      Map<String, Map<String, dynamic>> summary = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final statusMap = data['status'] as Map<String, dynamic>? ?? {};

        statusMap.forEach((studentId, status) {
          if (!summary.containsKey(studentId)) {
            summary[studentId] = {'present': 0, 'late': 0, 'total': 0};
          }
          summary[studentId]!['total'] = (summary[studentId]!['total'] ?? 0) + 1;

          if (status == 'Present') {
            summary[studentId]!['present'] = (summary[studentId]!['present'] ?? 0) + 1;
          } else if (status == 'Late') {
            summary[studentId]!['late'] = (summary[studentId]!['late'] ?? 0) + 1;
          }
        });
      }

      if (mounted) {
        setState(() {
          _summaryData = summary;
        });
      }
    } catch (e) {
      print("Error calculating summary: $e");
    }
  }

  // --- LOGIC: STRICT TIME WINDOW ---
  void _checkTimeConstraint(RoutineProvider routineProvider) {
    if (!mounted) return;

    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    // Rule 1: Must be Today
    if (!isToday) {
      setState(() {
        _isWithinTimeWindow = false;
        _statusMessage = "Attendance is only allowed on the current day.";
      });
      return;
    }

    String dayName = DateFormat('EEEE').format(now); // e.g., "Monday"

    try {
      // Find routine for this course & day
      final routine = routineProvider.routines.firstWhere(
            (r) => r.courseId == widget.courseId && r.day == dayName,
      );

      // Parse Times
      final times = _parseTimeRange(routine.time);
      if (times.isNotEmpty) {
        final classStart = times[0];
        final classEnd = times[1];

        // Strict Window: 5 min buffer before start, 5 min buffer after end
        final allowedStart = classStart.subtract(const Duration(minutes: 5));
        final allowedEnd = classEnd.add(const Duration(minutes: 5));

        if (now.isAfter(allowedStart) && now.isBefore(allowedEnd)) {
          setState(() {
            _isWithinTimeWindow = true;
            _statusMessage = "Class is in session. Attendance Allowed.";
          });
        } else {
          setState(() {
            _isWithinTimeWindow = false;
            _statusMessage = "Attendance Allowed only between ${DateFormat.jm().format(allowedStart)} - ${DateFormat.jm().format(allowedEnd)}";
          });
        }
      }
    } catch (e) {
      setState(() {
        _isWithinTimeWindow = false;
        _statusMessage = "No class routine found for today ($dayName).";
      });
    }
  }

  List<DateTime> _parseTimeRange(String timeStr) {
    final now = DateTime.now();
    try {
      if (timeStr.contains(" - ")) {
        final parts = timeStr.split(" - ");
        return [
          _parseSingleTime(parts[0], now),
          _parseSingleTime(parts[1], now)
        ];
      } else {
        final start = _parseSingleTime(timeStr, now);
        return [start, start.add(const Duration(hours: 1))];
      }
    } catch (e) {
      return [];
    }
  }

  DateTime _parseSingleTime(String t, DateTime now) {
    String cleanStr = t.replaceAll(RegExp(r'[\u202F\u00A0]'), ' ').trim();
    try {
      final time = DateFormat("h:mm a").parse(cleanStr);
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } catch (_) {
      final time = DateFormat.jm().parse(cleanStr);
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    }
  }

  // --- LOGIC: FETCH & DETERMINE PHASE ---
  Future<void> _fetchAttendanceStatus() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final stuProvider = Provider.of<StudentProvider>(context, listen: false);
    final docId = "${widget.courseId}_$dateKey";

    try {
      // FIX: Use the 'attendance' root collection directly to match your Project Structure
      final docSnap = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId)
          .get();

      Map<String, String> newStatus = {};
      int fetchedPhase = 0;

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        fetchedPhase = data['phase'] ?? 1; // If record exists but no phase, assume 1

        final recordsMap = data['status'] as Map<String, dynamic>? ?? {};

        for (var student in stuProvider.students) {
          newStatus[student.id] = recordsMap[student.id]?.toString() ?? "Present";
        }
      } else {
        // No record = Phase 0
        fetchedPhase = 0;
        for (var student in stuProvider.students) {
          newStatus[student.id] = "Present";
        }
      }

      if (mounted) {
        setState(() {
          _attendanceStatus = newStatus;
          _saveState = fetchedPhase > 2 ? 2 : fetchedPhase;
        });
      }
    } catch (e) {
      print("Error fetching attendance: $e");
    }
  }

  // --- LOGIC: SAVE (2-STEP PROCESS) ---
  Future<void> _saveAttendance() async {
    if (!_isWithinTimeWindow) return;
    if (_saveState >= 2) return; // Locked

    setState(() => _isLoading = true);
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      // 1. Calculate New Phase (0 -> 1, or 1 -> 2)
      int newPhase = _saveState + 1;

      // 2. Prepare Data
      final docId = "${widget.courseId}_$dateKey";

      // FIX: Use the correct 'attendance' collection
      final docRef = FirebaseFirestore.instance
          .collection('attendance')
          .doc(docId);

      await docRef.set({
        'courseId': widget.courseId,
        'date': dateKey,
        'status': _attendanceStatus,
        'phase': newPhase, // Explicitly save phase
        'userId': Provider.of<AttendanceProvider>(context, listen: false).userIdForSave
      }, SetOptions(merge: true));

      // 3. Update UI
      setState(() {
        _saveState = newPhase;
      });

      // Update Summary (Recalculate locally to ensure 'Late' is counted)
      await _fetchSummaryStats();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        String msg = newPhase == 1 ? "Attendance Saved!" : "Late Attendance Saved! Record Locked.";
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
      }

    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $error")));
      }
    }
  }

  // --- LOGIC: TOGGLE STATUS ---
  void _toggleStatus(String studentId) {
    if (_saveState >= 2 || !_isWithinTimeWindow) return; // Locked or Wrong Time

    setState(() {
      String current = _attendanceStatus[studentId] ?? "Present";

      if (_saveState == 0) {
        // Phase 1 Logic: Present <-> Absent
        if (current == "Present") {
          _attendanceStatus[studentId] = "Absent";
        } else {
          _attendanceStatus[studentId] = "Present";
        }
      } else if (_saveState == 1) {
        // Phase 2 Logic: Absent <-> Late (Present is locked)
        if (current == "Absent") {
          _attendanceStatus[studentId] = "Late";
        } else if (current == "Late") {
          _attendanceStatus[studentId] = "Absent";
        }
        // "Present" students cannot be changed in Phase 2
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = Provider.of<StudentProvider>(context).students;
    final formattedDate = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

    // Button Text Logic
    String buttonText = "SAVE ATTENDANCE";
    Color buttonColor = Colors.indigo;

    if (_saveState == 1) {
      buttonText = "SAVE LATE ATTENDANCE";
      buttonColor = Colors.orange;
    } else if (_saveState >= 2) {
      buttonText = "LOCKED";
      buttonColor = Colors.grey;
    }

    bool isDisabled = _isLoading || _saveState >= 2 || !_isWithinTimeWindow;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceSummaryScreen(courseId: widget.courseId, courseName: widget.courseName))),
          )
        ],
      ),
      body: Column(
        children: [
          // STATUS BANNER
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: _isWithinTimeWindow ? Colors.green.shade50 : Colors.red.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Date: $formattedDate", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: _saveState == 0 ? Colors.blue.shade100 : (_saveState == 1 ? Colors.orange.shade100 : Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4)
                      ),
                      child: Text(
                        _saveState == 0 ? "Step 1: Roll Call" : (_saveState == 1 ? "Step 2: Late Marking" : "Finalized"),
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                    _statusMessage,
                    style: TextStyle(
                        color: _isWithinTimeWindow ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.w600
                    )
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                final status = _attendanceStatus[student.id] ?? "Present";

                // Visual Styles
                IconData icon = Icons.check_circle;
                Color color = Colors.green;
                bool isItemLocked = false;

                if (status == "Present") {
                  icon = Icons.check_circle;
                  color = Colors.green;
                  // Present students are locked in Step 2 (Late Marking)
                  if (_saveState == 1) isItemLocked = true;
                } else if (status == "Late") {
                  icon = Icons.access_time_filled;
                  color = Colors.orange;
                } else {
                  icon = Icons.cancel;
                  color = Colors.red;
                }

                if (isDisabled || isItemLocked) color = color.withOpacity(0.3);

                // Stats
                int total = _summaryData[student.id]?['total'] ?? 0;
                int present = _summaryData[student.id]?['present'] ?? 0;
                int late = _summaryData[student.id]?['late'] ?? 0;
                int absents = total - (present + late);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${student.rollNumber} • Absents: $absents • Late: $late"),
                    trailing: InkWell(
                      onTap: (isDisabled || isItemLocked) ? null : () => _toggleStatus(student.id),
                      child: Padding(
                        // FIX: Reduced padding to prevent Overflow error
                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: color, size: 28),
                            Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold))
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // SUBMIT BUTTON
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: isDisabled ? null : _saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(buttonText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Extension to safely get userId in provider logic without context if needed,
// though strictly we used context above.
extension ProviderHelpers on AttendanceProvider {
  String? get userIdForSave => FirebaseAuth.instance.currentUser?.uid;
}