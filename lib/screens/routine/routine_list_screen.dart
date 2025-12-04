import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../providers/course_provider.dart';
import '../../models/course_model.dart';
import 'add_routine_screen.dart';

class RoutineListScreen extends StatefulWidget {
  const RoutineListScreen({super.key});

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () {
      Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
      // Also fetch courses so we can show course names instead of IDs
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Routine'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddRoutineScreen()),
        ),
      ),
      body: Consumer2<RoutineProvider, CourseProvider>(
        builder: (context, routineProvider, courseProvider, child) {
          if (routineProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (routineProvider.routines.isEmpty) {
            return Center(
              child: Text("No routine added yet.", style: TextStyle(color: Colors.grey[600])),
            );
          }

          // Optional: Sort routines by Day (Monday -> Sunday)
          // Simple sort logic could be added here

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: routineProvider.routines.length,
            itemBuilder: (context, index) {
              final routine = routineProvider.routines[index];

              // Find Course Name from ID
              final course = courseProvider.courses.firstWhere(
                    (c) => c.id == routine.courseId,
                orElse: () => Course(id: '', name: 'Unknown Course', code: ''),
              );

              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Extract first 3 letters of Day
                        Text(
                          routine.day.substring(0, 3).toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.indigo),
                        ),
                      ],
                    ),
                  ),
                  title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${routine.time} • ${course.code}"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AddRoutineScreen(routineToEdit: routine)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, routineProvider, routine.id),
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

  void _confirmDelete(BuildContext context, RoutineProvider provider, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
            onPressed: () {
              provider.deleteRoutine(id);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }
}