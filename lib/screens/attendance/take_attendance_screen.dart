import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';
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
  Map<String, Map<String, dynamic>> _summaryData = {}; // Stores historical stats
  bool _isLoading = false;

  // 0: First Save (Save Attendance)
  // 1: Second Save (Save Late Attendance)
  // 2: Disabled (Saved)
  int _saveState = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final stuProvider = Provider.of<StudentProvider>(context, listen: false);

    // 1. Fetch Students
    await stuProvider.fetchStudents(widget.courseId);

    // 2. Fetch existing attendance for this date
    await _fetchAttendanceForDate();

    // 3. Fetch Historical Summary (To calculate Absents)
    final summary = await attProvider.getAttendanceSummary(widget.courseId);

    setState(() {
      _summaryData = summary;
      _isLoading = false;
    });
  }

  Future<void> _fetchAttendanceForDate() async {
    final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final attProvider = Provider.of<AttendanceProvider>(context, listen: false);
    final stuProvider = Provider.of<StudentProvider>(context, listen: false);

    await attProvider.fetchAttendance(widget.courseId, dateKey);

    // Initialize local map based on fetched data OR default to "Present"
    final record = attProvider.currentDateRecord;
    Map<String, String> newStatus = {};

    for (var student in stuProvider.students) {
      if (record != null && record.studentStatus.containsKey(student.id)) {
        // Use existing status
        newStatus[student.id] = record.studentStatus[student.id]!;
      } else {
        // Default to "Present" if no record exists
        newStatus[student.id] = "Present";
      }
    }

    setState(() {
      _attendanceStatus = newStatus;
      // If record exists in DB, we treat it as "Saved Once" (State 1)
      // Otherwise it's "New" (State 0)
      if (record != null) {
        _saveState = 1;
      } else {
        _saveState = 0;
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      // Reload everything including summary when date changes (optional, but good for consistency)
      await _loadData();
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await Provider.of<AttendanceProvider>(context, listen: false)
          .markAttendance(widget.courseId, dateKey, _attendanceStatus);

      // Update Button State logic
      if (_saveState < 2) {
        setState(() {
          _saveState++;
        });
      }

      // Reload summary to reflect new changes immediately
      final summary = await Provider.of<AttendanceProvider>(context, listen: false).getAttendanceSummary(widget.courseId);
      setState(() {
        _summaryData = summary;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Attendance Saved Successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $error")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to change status: Present <-> Absent
  void _toggleStatus(String studentId) {
    setState(() {
      String current = _attendanceStatus[studentId] ?? "Present";
      if (current == "Present") {
        _attendanceStatus[studentId] = "Absent";
      } else {
        _attendanceStatus[studentId] = "Present";
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

    // Determine if Button is disabled
    bool isButtonDisabled = _isLoading || _saveState >= 2;

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
          // Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Date: $formattedDate", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text("Change"),
                )
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
                final isPresent = status == "Present";

                // Calculate Absents from Summary Data
                int totalClasses = 0;
                int presentClasses = 0;

                if (_summaryData.containsKey(student.id)) {
                  totalClasses = _summaryData[student.id]?['total'] ?? 0;
                  presentClasses = _summaryData[student.id]?['present'] ?? 0;
                }
                int absents = totalClasses - presentClasses;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              student.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Absent Count Indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.withOpacity(0.3))
                            ),
                            child: Text(
                              "Abs: $absents",
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[700]
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(student.rollNumber),
                      trailing: InkWell(
                        onTap: isButtonDisabled ? null : () => _toggleStatus(student.id),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Icon(
                            isPresent ? Icons.check_circle : Icons.circle_outlined,
                            color: isButtonDisabled
                                ? Colors.grey
                                : (isPresent ? Colors.green : Colors.grey),
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Save Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: isButtonDisabled ? null : _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  disabledForegroundColor: Colors.white70,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(buttonText, style: const TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}