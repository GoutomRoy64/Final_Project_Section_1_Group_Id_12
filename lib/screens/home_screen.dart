import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/routine_provider.dart';
import '../providers/course_provider.dart'; // Import CourseProvider
import '../models/routine_model.dart';
import '../models/course_model.dart';

// Import Screens
import 'courses/course_list_screen.dart';
import 'students/select_course_screen.dart';
import 'routine/routine_list_screen.dart';
import 'attendance/select_course_attendance_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // 1. Fetch BOTH Routines and Courses when app starts
    // We need courses to look up the names for the routines
    Future.delayed(Duration.zero, () {
      Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    String todayName = DateFormat('EEEE').format(DateTime.now());
    String formattedDate = DateFormat('MMM d, y').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('ClassTrack Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.indigo,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.indigo,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Welcome, Teacher!",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 5),
                Text(
                  formattedDate,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section 1: Today's Classes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Classes ($todayName)",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          // Manual Refresh Button
                          Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
                          Provider.of<CourseProvider>(context, listen: false).fetchCourses();
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    flex: 4,
                    // Use Consumer2 to listen to BOTH RoutineProvider and CourseProvider
                    child: Consumer2<RoutineProvider, CourseProvider>(
                      builder: (context, routineProvider, courseProvider, child) {

                        // Show loading only if routines are loading.
                        // (Course loading usually happens fast in background)
                        if (routineProvider.isLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        List<Routine> todaysRoutines = routineProvider.getRoutinesByDay(todayName);

                        if (todaysRoutines.isEmpty) {
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_busy, size: 50, color: Colors.grey[400]),
                                const SizedBox(height: 10),
                                Text("No classes scheduled for $todayName", style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: todaysRoutines.length,
                          itemBuilder: (context, index) {
                            final routine = todaysRoutines[index];

                            // LOOKUP LOGIC: Find the course object that matches the ID in the routine
                            final course = courseProvider.courses.firstWhere(
                                  (c) => c.id == routine.courseId,
                              orElse: () => Course(id: '', name: 'Loading...', code: ''),
                            );

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.class_outlined, color: Colors.indigo),
                                ),
                                // 1. Title is now the COURSE NAME
                                title: Text(
                                  course.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                // 2. Subtitle shows Time and Code
                                subtitle: Row(
                                  children: [
                                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                                    const SizedBox(width: 4),
                                    Text(routine.time, style: const TextStyle(fontWeight: FontWeight.w500)),
                                    const SizedBox(width: 10),
                                    if (course.code.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4)
                                        ),
                                        child: Text(course.code, style: const TextStyle(fontSize: 12)),
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Section 2: Quick Actions Grid
                  const Text(
                    "Management",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    flex: 5,
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.3,
                      children: [
                        _buildDashboardCard(
                          context,
                          icon: Icons.library_books,
                          label: "Courses",
                          color: Colors.blueAccent,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseListScreen()));
                          },
                        ),
                        _buildDashboardCard(
                          context,
                          icon: Icons.people,
                          label: "Students",
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectCourseScreen()));
                          },
                        ),
                        _buildDashboardCard(
                          context,
                          icon: Icons.checklist,
                          label: "Attendance",
                          color: Colors.orange,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectCourseAttendanceScreen()));
                          },
                        ),
                        _buildDashboardCard(
                          context,
                          icon: Icons.calendar_month,
                          label: "Routine",
                          color: Colors.purple,
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineListScreen()));
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}