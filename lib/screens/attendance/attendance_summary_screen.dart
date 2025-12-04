import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import '../../providers/attendance_provider.dart';

class AttendanceSummaryScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const AttendanceSummaryScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<AttendanceSummaryScreen> createState() => _AttendanceSummaryScreenState();
}

class _AttendanceSummaryScreenState extends State<AttendanceSummaryScreen> {
  bool _isLoading = true;
  Map<String, Map<String, dynamic>> _summaryData = {};

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    // Ensure we have students loaded to get their names
    await Provider.of<StudentProvider>(context, listen: false).fetchStudents(widget.courseId);

    // Calculate summary
    final data = await Provider.of<AttendanceProvider>(context, listen: false).getAttendanceSummary(widget.courseId);

    setState(() {
      _summaryData = data;
      _isLoading = false;
    });
  }

  Color _getPercentageColor(double percent) {
    if (percent >= 75) return Colors.green;
    if (percent >= 50) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final students = Provider.of<StudentProvider>(context).students;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Summary'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
          ? const Center(child: Text("No students to show summary for."))
          : Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[200],
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("Student", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Center(child: Text("Total", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("Present", style: TextStyle(fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text("%", style: TextStyle(fontWeight: FontWeight.bold)))),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: students.length,
              separatorBuilder: (ctx, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = students[index];
                final stats = _summaryData[student.id];

                final int total = stats?['total'] ?? 0;
                final int present = stats?['present'] ?? 0;
                final double percent = stats?['percent'] ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
                  child: Row(
                    children: [
                      // Name & ID
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                            Text(student.rollNumber, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      // Total Classes
                      Expanded(child: Center(child: Text(total.toString()))),
                      // Present Classes
                      Expanded(child: Center(child: Text(present.toString()))),
                      // Percentage
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _getPercentageColor(percent).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              "${percent.toStringAsFixed(0)}%",
                              style: TextStyle(
                                color: _getPercentageColor(percent),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}