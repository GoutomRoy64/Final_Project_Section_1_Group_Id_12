import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'take_attendance_screen.dart';

class SelectCourseAttendanceScreen extends StatefulWidget {
  const SelectCourseAttendanceScreen({super.key});

  @override
  State<SelectCourseAttendanceScreen> createState() => _SelectCourseAttendanceScreenState();
}

class _SelectCourseAttendanceScreenState extends State<SelectCourseAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance - Select Course'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.courses.isEmpty) {
            return const Center(child: Text("No courses available."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: provider.courses.length,
            itemBuilder: (context, index) {
              final course = provider.courses[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.check_circle, color: Colors.white, size: 20),
                  ),
                  title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(course.code),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TakeAttendanceScreen(
                          courseId: course.id,
                          courseName: course.name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}