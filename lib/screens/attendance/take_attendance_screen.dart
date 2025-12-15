import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/routine_provider.dart';
import '../../models/routine_model.dart';
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

  // 0: Initial (Save Attendance)
  // 1: Late Mode (Save Late Attendance)
  // 2: Completed (Disabled)
  int _saveState = 0;

  // Time Validation
  bool _isWithinTimeWindow = false;
  String _timeWindowMessage = "Checking schedule...";

  // Helper for Firestore path
  String get appId => 'default-app-id';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Determine if the widget is still mounted before setting state
    if (!mounted) return;
    setState(() => _isLoading = true);

    final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final stuProvider = Provider.of<StudentProvider>(context, listen: false);
    final routineProvider = Provider.of<RoutineProvider>(context, listen: false);

    // 1. Fetch Data
    await stuProvider.fetchStudents(widget.courseId);
    await routineProvider.fetchRoutines(); // Ensure routines are loaded
    await _fetchAttendanceForDate();
    final summary = await attProvider.getAttendanceSummary(widget.courseId);

    // 2. Check Time Validity
    _checkTimeConstraint(routineProvider);

    if (mounted) {
      setState(() {
        _summaryData = summary;
        _isLoading = false;
      });
    }
  }

  void _checkTimeConstraint(RoutineProvider routineProvider) {
    if (!mounted) return;
    // Only enforce time constraint if selected date is TODAY
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    if (!isToday) {
      setState(() {
        _isWithinTimeWindow = false;
        _timeWindowMessage = "Attendance can only be taken on the current day during class time.";
      });
      return;
    }

    String dayName = DateFormat('EEEE').format(now);

    try {
      final routine = routineProvider.routines.firstWhere(
            (r) => r.courseId == widget.courseId && r.day == dayName,
      );

      // Parse Routine Time Range
      final times = _parseTimeRange(routine.time); // Returns [StartDateTime, EndDateTime]

      if (times.isNotEmpty) {
        final classStart = times[0];
        final classEnd = times[1];

        // Buffer: 10 mins before start, 10 mins after end
        final allowedStart = classStart.subtract(const Duration(minutes: 10));
        final allowedEnd = classEnd.add(const Duration(minutes: 10));

        if (now.isAfter(allowedStart) && now.isBefore(allowedEnd)) {
          setState(() {
            _isWithinTimeWindow = true;
            _timeWindowMessage = "Class is in session.";
          });
        } else {
          setState(() {
            _isWithinTimeWindow = false;
            _timeWindowMessage = "Attendance is only allowed between ${DateFormat.jm().format(allowedStart)} and ${DateFormat.jm().format(allowedEnd)}.";
          });
        }
      }
    } catch (e) {
      setState(() {
        _isWithinTimeWindow = false;
        _timeWindowMessage = "No routine found for today ($dayName). Cannot take attendance.";
      });
    }
  }

  List<DateTime> _parseTimeRange(String timeStr) {
    // Expected formats: "9:30 AM - 10:45 AM" or "9:00 AM"
    final now = DateTime.now();
    try {
      if (timeStr.contains(" - ")) {
        final parts = timeStr.split(" - ");
        return [
          _parseSingleTime(parts[0], now),
          _parseSingleTime(parts[1], now)
        ];
      } else {
        // Fallback for single time: Assume 1 hour duration
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
      try {
        final time = DateFormat.jm().parse(cleanStr);
        return DateTime(now.year, now.month, now.day, time.hour, time.minute);
      } catch (e) {
        // Fallback if parsing fails, return current time to avoid crash
        return now;
      }
    }
  }

  Future<void> _fetchAttendanceForDate() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final stuProvider = Provider.of<StudentProvider>(context, listen: false);

    // Call provider to keep it in sync, but don't rely on it for critical state logic
    try {
      await Provider.of<AttendanceProvider>(context, listen: false)
          .fetchAttendance(widget.courseId, dateKey);
    } catch (_) {}

    // Direct Firestore Fetch for robust state
    // This ensures we don't accidentally restart Phase 1 if the provider is empty
    QuerySnapshot<Map<String, dynamic>>? snap;
    try {
      snap = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('attendance')
          .where('courseId', isEqualTo: widget.courseId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();
    } catch (e) {
      debugPrint("Error fetching attendance direct: $e");
    }

    Map<String, String> newStatus = {};
    int fetchedPhase = 0;

    if (snap != null && snap.docs.isNotEmpty) {
      final data = snap.docs.first.data();

      // If 'phase' field is missing but record exists, it implies Phase 1 was done (Legacy).
      fetchedPhase = data['phase'] ?? 1;

      // Get Records to populate status
      final recordsMap = data['records'] as Map<String, dynamic>? ?? {};

      for (var student in stuProvider.students) {
        if (recordsMap.containsKey(student.id)) {
          newStatus[student.id] = recordsMap[student.id].toString();
        } else {
          // New student or missing record? Default to Present
          newStatus[student.id] = "Present";
        }
      }
    } else {
      // No record found in DB -> Phase 0
      fetchedPhase = 0;
      for (var student in stuProvider.students) {
        newStatus[student.id] = "Present"; // Default new attendance
      }
    }

    if (mounted) {
      setState(() {
        _attendanceStatus = newStatus;

        // Update State based on Phase
        if (fetchedPhase >= 2) {
          _saveState = 2; // Finalized
        } else if (fetchedPhase == 1) {
          _saveState = 1; // Late Attendance Mode
        } else {
          _saveState = 0; // Initial Mode
        }
      });
    }
  }

  Future<void> _saveAttendance() async {
    if (!_isWithinTimeWindow) return;

    setState(() => _isLoading = true);
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      // --- CRITICAL PRE-CHECK: Prevent overwriting/duplicates ---
      final checkSnap = await FirebaseFirestore.instance
          .collection('artifacts')
          .doc(appId)
          .collection('public')
          .doc('data')
          .collection('attendance')
          .where('courseId', isEqualTo: widget.courseId)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();

      if (checkSnap.docs.isNotEmpty) {
        final existingData = checkSnap.docs.first.data();
        final dbPhase = existingData['phase'] ?? 1;

        // If local state is "behind" the DB state (e.g. User thinks Phase 0, but DB is Phase 1)
        if (_saveState < dbPhase) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text("Attendance already updated! Syncing with server..."),
                    backgroundColor: Colors.orange
                )
            );
            // Reload to sync UI with DB
            await _fetchAttendanceForDate();
            setState(() => _isLoading = false);
          }
          return; // STOP SAVE
        }
      }

      // --- PROCEED IF SAFE ---

      // 1. Save Attendance Data via Provider
      await Provider.of<AttendanceProvider>(context, listen: false)
          .markAttendance(widget.courseId, dateKey, _attendanceStatus);

      // 2. Persist the Phase state to Firestore manually
      int newPhase = _saveState + 1;
      if (newPhase > 2) newPhase = 2;

      try {
        final q = FirebaseFirestore.instance
            .collection('artifacts')
            .doc(appId)
            .collection('public')
            .doc('data')
            .collection('attendance')
            .where('courseId', isEqualTo: widget.courseId)
            .where('date', isEqualTo: dateKey)
            .limit(1);

        final snap = await q.get();
        if (snap.docs.isNotEmpty) {
          await snap.docs.first.reference.update({'phase': newPhase});
        }
      } catch (e) {
        debugPrint("Error persisting phase: $e");
      }

      // 3. Update Local State immediately
      if (_saveState < 2) {
        setState(() {
          _saveState++;
        });
      }

      // Reload summary
      final summary = await Provider.of<AttendanceProvider>(context, listen: false).getAttendanceSummary(widget.courseId);

      if (mounted) {
        setState(() {
          _summaryData = summary;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Attendance Saved Successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $error")));
      }
    }
  }

  void _toggleStatus(String studentId) {
    setState(() {
      String current = _attendanceStatus[studentId] ?? "Present";

      if (_saveState == 0) {
        // --- PHASE 1: ATTENDANCE ---
        // Toggle: Present <-> Absent
        if (current == "Present") {
          _attendanceStatus[studentId] = "Absent";
        } else {
          _attendanceStatus[studentId] = "Present";
        }
      } else if (_saveState == 1) {
        // --- PHASE 2: LATE ATTENDANCE ---
        // Logic: "Only for those students who miss the first attendance"
        if (current == "Absent") {
          _attendanceStatus[studentId] = "Late";
        } else if (current == "Late") {
          _attendanceStatus[studentId] = "Absent"; // Undo Late
        }
        // Present is Locked
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final students = Provider.of<StudentProvider>(context).students;
    final formattedDate = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

    // Determine Button Text
    String buttonText = "SAVE ATTENDANCE";
    if (_saveState == 1) buttonText = "SAVE LATE ATTENDANCE";
    if (_saveState >= 2) buttonText = "ATTENDANCE SUBMITTED";

    // Button Disabled Conditions
    bool isButtonDisabled = _isLoading || _saveState >= 2 || !_isWithinTimeWindow;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'View Summary',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AttendanceSummaryScreen(courseId: widget.courseId, courseName: widget.courseName),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Info Header
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: _isWithinTimeWindow ? Colors.green.shade50 : Colors.red.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Date: $formattedDate", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(
                    _timeWindowMessage,
                    style: TextStyle(
                        color: _isWithinTimeWindow ? Colors.green[800] : Colors.red[800],
                        fontSize: 13,
                        fontWeight: FontWeight.w500
                    )
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : students.isEmpty
                ? const Center(child: Text("No students enrolled."))
                : ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final student = students[index];
                final status = _attendanceStatus[student.id] ?? "Present";

                // Determine Icons & Colors
                IconData icon = Icons.circle_outlined;
                Color color = Colors.grey;
                bool isLocked = false;

                if (status == "Present") {
                  icon = Icons.check_circle;
                  color = Colors.green;
                  // Lock 'Present' students during Late Phase
                  if (_saveState == 1) isLocked = true;
                } else if (status == "Late") {
                  icon = Icons.access_time_filled; // Late Icon
                  color = Colors.orange;
                } else {
                  // Absent
                  icon = Icons.cancel;
                  color = Colors.red;
                }

                // Override color if the whole screen is disabled or locked
                if (isButtonDisabled || isLocked) {
                  color = color.withOpacity(0.5);
                }

                // Calculate Absents from Summary
                int total = 0;
                int present = 0;
                int late = 0;
                if (_summaryData.containsKey(student.id)) {
                  total = _summaryData[student.id]?['total'] ?? 0;
                  present = _summaryData[student.id]?['present'] ?? 0;
                  late = _summaryData[student.id]?['late'] ?? 0;
                }
                int absents = total - (present + late);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    title: Row(
                      children: [
                        Expanded(child: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                        if (absents > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.red.shade200)
                            ),
                            child: Text("Abs: $absents", style: TextStyle(fontSize: 11, color: Colors.red[800], fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                    subtitle: Text(student.rollNumber),
                    trailing: InkWell(
                      onTap: (isButtonDisabled || isLocked) ? null : () => _toggleStatus(student.id),
                      borderRadius: BorderRadius.circular(30),
                      child: Padding(
                        // Reduced padding to fix RenderFlex overflow in ListTile
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: color, size: 26),
                            const SizedBox(height: 2),
                            Text(
                              status,
                              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Save Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isButtonDisabled ? null : _saveAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _saveState == 1 ? Colors.orange : Colors.indigo, // Orange for Late mode
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  )
                      : Text(buttonText, style: const TextStyle(fontSize: 18)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}