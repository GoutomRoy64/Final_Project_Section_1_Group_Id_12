import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  List<String> _classDates = [];
  Map<String, Map<String, String>> _attendanceMatrix = {};

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    final stuProvider = Provider.of<StudentProvider>(context, listen: false);
    await stuProvider.fetchStudents(widget.courseId);

    final snapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('courseId', isEqualTo: widget.courseId)
        .get();

    if (snapshot.docs.isNotEmpty) {
      Set<String> uniqueDates = {};
      Map<String, Map<String, String>> matrix = {};

      for (var doc in snapshot.docs) {
        Map<String, dynamic> data = doc.data();
        String dateKey = data['date'];
        uniqueDates.add(dateKey);

        if (data['status'] != null) {
          Map<String, dynamic> statusMap = data['status'];
          statusMap.forEach((studentId, status) {
            if (!matrix.containsKey(studentId)) {
              matrix[studentId] = {};
            }
            matrix[studentId]![dateKey] = status.toString();
          });
        }
      }

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

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd-MMM').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // Calculate Stats: [Absents, Lates]
  List<int> _calculateStats(String studentId) {
    if (!_attendanceMatrix.containsKey(studentId)) return [0, 0];
    int absent = 0;
    int late = 0;
    _attendanceMatrix[studentId]!.forEach((key, value) {
      if (value == 'Absent') absent++;
      if (value == 'Late') late++;
    });
    return [absent, late];
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
              const DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
              const DataColumn(label: Text('Abs', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
              const DataColumn(label: Text('Late', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))), // New Column
              ..._classDates.asMap().entries.map((entry) {
                int index = entry.key + 1;
                return DataColumn(
                  label: Text('C$index', style: const TextStyle(fontWeight: FontWeight.bold)),
                  tooltip: entry.value,
                );
              }).toList(),
            ],
            rows: students.map((student) {
              List<int> stats = _calculateStats(student.id);
              int absents = stats[0];
              int lates = stats[1];

              return DataRow(
                cells: [
                  DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                      )
                  ),
                  DataCell(Text(absents.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                  DataCell(Text(lates.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))),
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
                          Text(displayDate, style: TextStyle(color: cellColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(status[0], style: TextStyle(fontSize: 10, color: cellColor)), // Shows P, A, L
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