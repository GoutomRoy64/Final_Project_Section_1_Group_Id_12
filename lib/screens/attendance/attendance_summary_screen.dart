import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import '../../providers/student_provider.dart';
import '../../models/student_model.dart';

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

  // List of all dates class was taken (e.g. ["2025-12-01", "2025-12-02"])
  List<String> _classDates = [];

  // Map of StudentID -> { Date -> Status }
  Map<String, Map<String, String>> _attendanceMatrix = {};

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    final stuProvider = Provider.of<StudentProvider>(context, listen: false);

    // 1. Ensure we have the latest student list
    await stuProvider.fetchStudents(widget.courseId);

    // 2. Fetch ALL attendance records for this course directly
    // We do this here because we need the raw date structure for the matrix
    final dbRef = FirebaseDatabase.instance.ref().child('attendance').child(widget.courseId);
    final snapshot = await dbRef.get();

    if (snapshot.exists) {
      Map<dynamic, dynamic> data = snapshot.value as Map<dynamic, dynamic>;

      Set<String> uniqueDates = {};
      Map<String, Map<String, String>> matrix = {};

      // Parse Firebase Data
      data.forEach((dateKey, dateValue) {
        uniqueDates.add(dateKey.toString());

        if (dateValue['status'] != null) {
          Map<dynamic, dynamic> statusMap = dateValue['status'];
          statusMap.forEach((studentId, status) {
            if (!matrix.containsKey(studentId)) {
              matrix[studentId] = {};
            }
            matrix[studentId]![dateKey] = status.toString();
          });
        }
      });

      // Sort dates chronologically (Oldest -> Newest)
      List<String> sortedDates = uniqueDates.toList()..sort();

      if (mounted) {
        setState(() {
          _classDates = sortedDates;
          _attendanceMatrix = matrix;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to format date "2025-12-05" -> "05-Dec"
  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd-MMM').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Calculate Total Absents for a specific student
  int _calculateAbsents(String studentId) {
    if (!_attendanceMatrix.containsKey(studentId)) return 0;
    int count = 0;
    _attendanceMatrix[studentId]!.forEach((key, value) {
      if (value == 'Absent') count++;
    });
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final students = Provider.of<StudentProvider>(context).students;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Sheet'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
          ? const Center(child: Text("No students found."))
          : _classDates.isEmpty
          ? const Center(child: Text("No attendance records found yet."))
          : SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey[200]),
            columnSpacing: 20,
            border: TableBorder.all(color: Colors.grey.shade300),
            columns: [
              // Fixed Columns
              const DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Abs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),

              // Dynamic Columns (C1, C2, C3...)
              ..._classDates.asMap().entries.map((entry) {
                int index = entry.key + 1;
                return DataColumn(
                  label: Text(
                    'C$index',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  tooltip: entry.value, // Hover shows full date (Fixed: Moved outside Text)
                );
              }).toList(),
            ],
            rows: students.map((student) {
              int absentCount = _calculateAbsents(student.id);

              return DataRow(
                cells: [
                  // Name Cell
                  DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(
                          student.name,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                  ),
                  // Absents Count Cell
                  DataCell(
                      Text(
                        absentCount.toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      )
                  ),

                  // Date Status Cells
                  ..._classDates.map((date) {
                    String status = _attendanceMatrix[student.id]?[date] ?? '-';
                    String displayDate = _formatDate(date);

                    Color cellColor = Colors.black;
                    if (status == 'Present') cellColor = Colors.green;
                    if (status == 'Absent') cellColor = Colors.red;
                    if (status == 'Late') cellColor = Colors.orange;

                    return DataCell(
                      status == '-'
                          ? const Text("-", style: TextStyle(color: Colors.grey))
                          : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              displayDate,
                              style: TextStyle(
                                  color: cellColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold
                              )
                          ),
                          // Optional: Show P/A text below date if needed
                          // Text(status[0], style: TextStyle(fontSize: 10, color: cellColor)),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}