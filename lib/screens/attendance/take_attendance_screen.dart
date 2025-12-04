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
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Fetch Students
    await Provider.of<StudentProvider>(context, listen: false).fetchStudents(widget.courseId);

    // 2. Fetch existing attendance for this date
    await _fetchAttendanceForDate();

    setState(() => _isLoading = false);
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
      await _fetchAttendanceForDate(); // Reload data for new date
    }
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await Provider.of<AttendanceProvider>(context, listen: false)
          .markAttendance(widget.courseId, dateKey, _attendanceStatus);

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

  @override
  Widget build(BuildContext context) {
    final students = Provider.of<StudentProvider>(context).students;
    final formattedDate = DateFormat('EEE, MMM d, yyyy').format(_selectedDate);

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

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: ListTile(
                    title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(student.rollNumber),
                    trailing: Switch(
                      value: isPresent,
                      activeColor: Colors.green,
                      inactiveThumbColor: Colors.red,
                      inactiveTrackColor: Colors.red.shade100,
                      onChanged: (val) {
                        setState(() {
                          _attendanceStatus[student.id] = val ? "Present" : "Absent";
                        });
                      },
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
                onPressed: _isLoading ? null : _saveAttendance,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SAVE ATTENDANCE", style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}