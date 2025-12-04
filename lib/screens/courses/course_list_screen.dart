import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'add_course_screen.dart';

class CourseListScreen extends StatefulWidget {
  const CourseListScreen({super.key});

  @override
  State<CourseListScreen> createState() => _CourseListScreenState();
}

class _CourseListScreenState extends State<CourseListScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch courses when screen loads
    Future.delayed(Duration.zero, () {
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Courses'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCourseScreen())
        ),
      ),
      body: Consumer<CourseProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.courses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.library_books_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text("No courses added yet.", style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddCourseScreen())),
                    child: const Text("Add your first course"),
                  )
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: provider.courses.length,
            itemBuilder: (context, index) {
              final course = provider.courses[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade50,
                    child: Text(
                      course.code.substring(0, 2).toUpperCase(), // Show first 2 letters of code
                      style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(course.code),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => AddCourseScreen(courseToEdit: course))
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, provider, course.id),
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

  void _confirmDelete(BuildContext context, CourseProvider provider, String courseId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course?'),
        content: const Text('This will delete the course. Are you sure?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              provider.deleteCourse(courseId);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}