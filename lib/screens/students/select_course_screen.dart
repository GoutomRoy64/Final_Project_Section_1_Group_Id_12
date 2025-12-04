import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'student_list_screen.dart';

class SelectCourseScreen extends StatefulWidget {
  const SelectCourseScreen({super.key});

  @override
  State<SelectCourseScreen> createState() => _SelectCourseScreenState();
}

class _SelectCourseScreenState extends State<SelectCourseScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure we have the latest courses loaded
    Future.delayed(Duration.zero, () {
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Course'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.courses.isEmpty) {
            return Center(
              child: Text("No courses found. Please add a course first.",
                  style: TextStyle(color: Colors.grey[600])
              ),
            );
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
                  title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(course.code),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // Navigate to the Student List for this specific course
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudentListScreen(
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