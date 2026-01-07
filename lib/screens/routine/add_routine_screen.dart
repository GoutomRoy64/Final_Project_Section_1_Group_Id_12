import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/routine_provider.dart';
import '../../providers/course_provider.dart';
import '../../models/routine_model.dart';
import '../../models/course_model.dart';

class AddRoutineScreen extends StatefulWidget {
  final Routine? routineToEdit;

  const AddRoutineScreen({super.key, this.routineToEdit});

  @override
  State<AddRoutineScreen> createState() => _AddRoutineScreenState();
}

class _AddRoutineScreenState extends State<AddRoutineScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCourseId;
  String _selectedDay = 'Monday';

  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);

  bool _isLoading = false;

  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    // Fetch courses AND routines (so we can check for duplicates)
    Future.delayed(Duration.zero, () {
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
      Provider.of<RoutineProvider>(context, listen: false).fetchRoutines();
    });

    if (widget.routineToEdit != null) {
      _selectedCourseId = widget.routineToEdit!.courseId;
      _selectedDay = widget.routineToEdit!.day;
      _parseTimeRange(widget.routineToEdit!.time);
    }
  }

  void _parseTimeRange(String timeString) {
    if (timeString.contains(" - ")) {
      final parts = timeString.split(" - ");
      if (parts.length == 2) {
        _startTime = _stringToTimeOfDay(parts[0]);
        _endTime = _stringToTimeOfDay(parts[1]);
      }
    } else {
      _startTime = _stringToTimeOfDay(timeString);
      _endTime = _startTime.replacing(hour: _startTime.hour + 1);
    }
  }

  TimeOfDay _stringToTimeOfDay(String s) {
    try {
      final format = RegExp(r"(\d+):(\d+)\s?(AM|PM)", caseSensitive: false);
      final match = format.firstMatch(s);
      if (match != null) {
        int hour = int.parse(match.group(1)!);
        int minute = int.parse(match.group(2)!);
        String period = match.group(3)!.toUpperCase();

        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;

        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print("Error parsing time: $e");
    }
    return TimeOfDay.now();
  }

  Future<void> _pickTime(bool isStartTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _startTime = picked;
          if (_toDouble(_endTime) <= _toDouble(_startTime)) {
            _endTime = _startTime.replacing(hour: _startTime.hour + 1);
          }
        } else {
          _endTime = picked;
        }
      });
    }
  }

  double _toDouble(TimeOfDay myTime) => myTime.hour + myTime.minute / 60.0;

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a course')));
      return;
    }

    setState(() => _isLoading = true);

    final provider = Provider.of<RoutineProvider>(context, listen: false);

    // --- DUPLICATE CHECK LOGIC ---
    // Check if this course is already scheduled for the selected day
    bool isDuplicate = provider.routines.any((routine) {
      bool sameCourse = routine.courseId == _selectedCourseId;
      bool sameDay = routine.day == _selectedDay;

      // If we are editing, we shouldn't count the current routine as a duplicate of itself
      bool isNotSelf = widget.routineToEdit == null || routine.id != widget.routineToEdit!.id;

      return sameCourse && sameDay && isNotSelf;
    });

    if (isDuplicate) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: This course is already scheduled on $_selectedDay.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return; // Stop saving
    }
    // -----------------------------

    final timeString = "${_startTime.format(context)} - ${_endTime.format(context)}";

    try {
      if (widget.routineToEdit == null) {
        await provider.addRoutine(_selectedCourseId!, _selectedDay, timeString);
      } else {
        await provider.updateRoutine(widget.routineToEdit!.id, _selectedCourseId!, _selectedDay, timeString);
      }

      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $error")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routineToEdit == null ? 'Add Routine' : 'Edit Routine'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Consumer<CourseProvider>(
            builder: (context, courseProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCourseId,
                    decoration: const InputDecoration(
                      labelText: 'Select Course',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.book),
                    ),
                    items: courseProvider.courses.map((Course course) {
                      return DropdownMenuItem<String>(
                        value: course.id,
                        child: Text("${course.code} - ${course.name}", overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedCourseId = val),
                    validator: (val) => val == null ? 'Please select a course' : null,
                  ),

                  const SizedBox(height: 15),

                  DropdownButtonFormField<String>(
                    value: _selectedDay,
                    decoration: const InputDecoration(
                      labelText: 'Select Day',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    items: _daysOfWeek.map((String day) {
                      return DropdownMenuItem<String>(
                        value: day,
                        child: Text(day),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedDay = val!),
                  ),

                  const SizedBox(height: 15),

                  const Text("Class Duration", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(true),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Start Time',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(_startTime.format(context)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward, color: Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickTime(false),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'End Time',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time_filled),
                            ),
                            child: Text(_endTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _saveForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Save Routine', style: TextStyle(fontSize: 18)),
                    ),
                  )
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}