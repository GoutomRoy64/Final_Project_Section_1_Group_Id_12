import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/routine_provider.dart';
import '../providers/course_provider.dart';
import '../models/routine_model.dart';
import '../models/course_model.dart';

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
    Future.delayed(Duration.zero, () {
      Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });
  }

  // 0: Past, 1: Running, 2: Upcoming
  int _getClassStatus(String timeRange) {
    try {
      final now = DateTime.now();
      DateTime start, end;

      // Handle "Start - End" format
      if (timeRange.contains(" - ")) {
        final parts = timeRange.split(" - ");
        start = _parseDateTime(parts[0], now);
        end = _parseDateTime(parts[1], now);
      } else {
        // Handle old single time format (Assume 1 hour duration)
        start = _parseDateTime(timeRange, now);
        end = start.add(const Duration(hours: 1));
      }

      // Handle overnight classes (e.g., 11 PM to 1 AM)
      // If end time appears to be before start time, assume it ends the next day
      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      if (now.isAfter(end)) return 0; // Past
      if (now.isAfter(start) && now.isBefore(end)) return 1; // Running
      return 2; // Upcoming

    } catch (e) {
      // print("Parsing Error: $e"); // Debugging
      return 2; // Default to upcoming if parsing fails
    }
  }

  DateTime _parseDateTime(String timeStr, DateTime now) {
    // 1. Sanitize the string to remove Non-Breaking Spaces (\u202F)
    // which Flutter adds by default, but DateFormat fails to parse.
    String cleanStr = timeStr.replaceAll(RegExp(r'[\u202F\u00A0]'), ' ').trim();

    // 2. Try parsing with standard format
    try {
      // Explicitly try "h:mm a" (e.g., "9:30 AM")
      final time = DateFormat("h:mm a").parse(cleanStr);
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } catch (_) {
      try {
        // Fallback to default locale parsing
        final time = DateFormat.jm().parse(cleanStr);
        return DateTime(now.year, now.month, now.day, time.hour, time.minute);
      } catch (e) {
        // Last resort: Return current time to avoid crash, but logs will show upcoming
        return now.add(const Duration(days: 1));
      }
    }
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
                          Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
                          Provider.of<CourseProvider>(context, listen: false).fetchCourses();
                        },
                      )
                    ],
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    flex: 4,
                    child: Consumer2<RoutineProvider, CourseProvider>(
                      builder: (context, routineProvider, courseProvider, child) {

                        if (routineProvider.isLoading) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        List<Routine> todaysRoutines = routineProvider.getRoutinesByDay(todayName);

                        if (todaysRoutines.isEmpty) {
                          return _buildEmptyState(todayName);
                        }

                        // Sort routines by time
                        todaysRoutines.sort((a, b) {
                          // Simple string sort isn't perfect for time, but works roughly for AM/PM if format is consistent
                          // Better to parse, but this is quick fix for list order
                          return a.time.compareTo(b.time);
                        });

                        return ListView.builder(
                          itemCount: todaysRoutines.length,
                          itemBuilder: (context, index) {
                            final routine = todaysRoutines[index];
                            final course = courseProvider.courses.firstWhere(
                                  (c) => c.id == routine.courseId,
                              orElse: () => Course(id: '', name: 'Loading...', code: '...'),
                            );

                            // Determine Status & Styling
                            final status = _getClassStatus(routine.time);

                            Color cardColor;
                            Color textColor;
                            Color iconColor;
                            IconData statusIcon;
                            String statusText;

                            if (status == 0) { // Past
                              cardColor = Colors.grey.shade200;
                              textColor = Colors.grey.shade600;
                              iconColor = Colors.grey;
                              statusIcon = Icons.check_circle_outline;
                              statusText = "Completed";
                            } else if (status == 1) { // Running
                              cardColor = Colors.green.shade50;
                              textColor = Colors.green.shade900;
                              iconColor = Colors.green;
                              statusIcon = Icons.play_circle_fill;
                              statusText = "Ongoing Now";
                            } else { // Upcoming
                              cardColor = Colors.white;
                              textColor = Colors.black87;
                              iconColor = Colors.indigo;
                              statusIcon = Icons.schedule;
                              statusText = "Upcoming";
                            }

                            return Card(
                              color: cardColor,
                              elevation: status == 1 ? 4 : 1, // Elevate running class
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: status == 1 ? const BorderSide(color: Colors.green, width: 1.5) : BorderSide.none,
                              ),
                              child: ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: iconColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.class_outlined, color: iconColor),
                                ),
                                title: Text(
                                  course.name,
                                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: textColor.withOpacity(0.7)),
                                        const SizedBox(width: 4),
                                        Text(routine.time, style: TextStyle(fontWeight: FontWeight.w500, color: textColor.withOpacity(0.8), fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(statusIcon, size: 12, color: iconColor),
                                        const SizedBox(width: 4),
                                        Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
                                        const SizedBox(width: 8),
                                        if(course.code.isNotEmpty)
                                          Text("•  ${course.code}", style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.7))),
                                      ],
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
                        _buildDashboardCard(context, icon: Icons.library_books, label: "Courses", color: Colors.blueAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseListScreen()))),
                        _buildDashboardCard(context, icon: Icons.people, label: "Students", color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectCourseScreen()))),
                        _buildDashboardCard(context, icon: Icons.checklist, label: "Attendance", color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectCourseAttendanceScreen()))),
                        _buildDashboardCard(context, icon: Icons.calendar_month, label: "Routine", color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineListScreen()))),
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

  Widget _buildEmptyState(String todayName) {
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