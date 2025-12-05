import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/course_provider.dart';
import '../../providers/routine_provider.dart';
import '../../models/course_model.dart';
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
      Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get today's day name (e.g., "Friday")
    String todayName = DateFormat('EEEE').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance ($todayName)'), // Show day in title
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Consumer2<CourseProvider, RoutineProvider>(
        builder: (context, courseProvider, routineProvider, child) {
          if (courseProvider.isLoading || routineProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 1. Get routines for TODAY only
          final todaysRoutines = routineProvider.getRoutinesByDay(todayName);

          // 2. Extract unique Course IDs for today
          final todayCourseIds = todaysRoutines.map((r) => r.courseId).toSet();

          // 3. Filter the main course list to show only courses scheduled for today
          final displayCourses = courseProvider.courses.where((course) {
            return todayCourseIds.contains(course.id);
          }).toList();

          if (displayCourses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 10),
                  Text(
                      "No classes scheduled for $todayName.",
                      style: TextStyle(color: Colors.grey[600], fontSize: 16)
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: displayCourses.length,
            itemBuilder: (context, index) {
              final course = displayCourses[index];

              // Find the specific time(s) for this course today to display
              final specificRoutines = todaysRoutines.where((r) => r.courseId == course.id).toList();
              // Join times if there are multiple slots (e.g. "10:00 AM & 2:00 PM")
              final timeString = specificRoutines.map((r) => r.time).join(' & ');

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.class_outlined, color: Colors.indigo),
                  ),
                  title: Text(course.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(timeString, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                      const SizedBox(width: 8),
                      Text("•  ${course.code}", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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