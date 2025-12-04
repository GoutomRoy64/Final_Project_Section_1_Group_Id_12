import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import 'add_student_screen.dart';

class StudentListScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const StudentListScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch students specific to this course ID
    Future.delayed(Duration.zero, () {
      Provider.of<StudentProvider>(context, listen: false).fetchStudents(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName), // Show course name in title
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.person_add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddStudentScreen(courseId: widget.courseId),
          ),
        ),
      ),
      body: Consumer<StudentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off_outlined, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No students enrolled yet.", style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: provider.students.length,
            itemBuilder: (context, index) {
              final student = provider.students[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Text(
                      student.rollNumber.length > 2 ? student.rollNumber.substring(student.rollNumber.length - 2) : student.rollNumber,
                      style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("ID: ${student.rollNumber}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddStudentScreen(
                              courseId: widget.courseId,
                              studentToEdit: student,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, provider, student.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, StudentProvider provider, String studentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student?'),
        content: const Text('Are you sure you want to remove this student from the course?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
            onPressed: () {
              provider.deleteStudent(widget.courseId, studentId);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}