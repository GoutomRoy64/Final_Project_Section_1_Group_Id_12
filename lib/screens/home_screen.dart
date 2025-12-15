import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _teacherName = "Teacher";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    Future.delayed(Duration.zero, () {
      Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });

    _fetchTeacherName();
  }

  Future<void> _fetchTeacherName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data() != null) {
          setState(() {
            _teacherName = doc.data()!['name'] ?? "Teacher";
          });
        }
      }
    } catch (e) {
      print("Error fetching name: $e");
    }
  }

  int _getClassStatus(String timeRange) {
    try {
      final now = DateTime.now();
      DateTime start, end;

      if (timeRange.contains(" - ")) {
        final parts = timeRange.split(" - ");
        start = _parseDateTime(parts[0], now);
        end = _parseDateTime(parts[1], now);
      } else {
        start = _parseDateTime(timeRange, now);
        end = start.add(const Duration(hours: 1));
      }

      if (end.isBefore(start)) {
        end = end.add(const Duration(days: 1));
      }

      if (now.isAfter(end)) return 0; // Past
      if (now.isAfter(start) && now.isBefore(end)) return 1; // Running
      return 2; // Upcoming

    } catch (e) {
      return 2;
    }
  }

  DateTime _parseDateTime(String timeStr, DateTime now) {
    String cleanStr = timeStr.replaceAll(RegExp('[  ]'), ' ').trim();
    try {
      final time = DateFormat("h:mm a").parse(cleanStr);
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } catch (_) {
      try {
        final time = DateFormat.jm().parse(cleanStr);
        return DateTime(now.year, now.month, now.day, time.hour, time.minute);
      } catch (e) {
        return now.add(const Duration(days: 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String todayName = DateFormat('EEEE').format(DateTime.now());
    String formattedDate = DateFormat('MMM d, y').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // 1. Scrollable Top Section (App Bar + Today's Classes)
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 180.0,
                  backgroundColor: Colors.indigo,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 60),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.indigo, Colors.blueAccent],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "Welcome, $_teacherName!",
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            formattedDate,
                            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      tooltip: 'Logout',
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Today's Classes ($todayName)",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.indigo),
                          onPressed: _loadData,
                        )
                      ],
                    ),
                  ),
                ),

                Consumer2<RoutineProvider, CourseProvider>(
                  builder: (context, routineProvider, courseProvider, child) {
                    if (routineProvider.isLoading) {
                      return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())));
                    }

                    List<Routine> todaysRoutines = routineProvider.getRoutinesByDay(todayName);

                    if (todaysRoutines.isEmpty) {
                      return SliverToBoxAdapter(child: _buildEmptyState(todayName));
                    }

                    todaysRoutines.sort((a, b) => a.time.compareTo(b.time));

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final routine = todaysRoutines[index];
                          final course = courseProvider.courses.firstWhere(
                                (c) => c.id == routine.courseId,
                            orElse: () => Course(id: '', name: 'Course not found', code: '...'),
                          );

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

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
                            child: Card(
                              color: cardColor,
                              elevation: status == 1 ? 4 : 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: status == 1 ? const BorderSide(color: Colors.green, width: 1.5) : BorderSide.none,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Icon(Icons.access_time, size: 14, color: textColor.withOpacity(0.7)),
                                        const SizedBox(width: 4),
                                        Text(routine.time, style: TextStyle(fontWeight: FontWeight.w500, color: textColor.withOpacity(0.8), fontSize: 13)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
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
                            ),
                          );
                        },
                        childCount: todaysRoutines.length,
                      ),
                    );
                  },
                ),

                // Add some padding at the bottom of the list so items aren't hidden behind the fixed panel if expanded
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          ),

          // 2. Fixed Management Section (Anchored at Bottom)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30)
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Takes minimal height needed
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Management",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 15),
                GridView.count(
                  shrinkWrap: true, // Important for nesting in Column
                  physics: const NeverScrollableScrollPhysics(), // Disable internal scrolling
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.5, // Wider cards to save vertical space
                  children: [
                    _buildDashboardCard(context, icon: Icons.library_books, label: "Courses", color: Colors.blueAccent, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CourseListScreen()))),
                    _buildDashboardCard(context, icon: Icons.people, label: "Students", color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectCourseScreen()))),
                    _buildDashboardCard(context, icon: Icons.checklist, label: "Attendance", color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectCourseAttendanceScreen()))),
                    _buildDashboardCard(context, icon: Icons.calendar_month, label: "Routine", color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutineListScreen()))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String todayName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(30),
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
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}