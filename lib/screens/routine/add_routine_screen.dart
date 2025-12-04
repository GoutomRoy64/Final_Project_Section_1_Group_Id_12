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
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);

  bool _isLoading = false;

  final List<String> _daysOfWeek = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    // Fetch courses so we can populate the dropdown
    Future.delayed(Duration.zero, () {
      Provider.of<CourseProvider>(context, listen: false).fetchCourses();
    });

    if (widget.routineToEdit != null) {
      _selectedCourseId = widget.routineToEdit!.courseId;
      _selectedDay = widget.routineToEdit!.day;
      // Parse time string "10:30 AM" back to TimeOfDay if possible
      // For simplicity in this example, we might reset time or need a parser helper.
      // We'll leave it as default or user re-picks it to avoid parsing complexity here.
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourseId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a course')));
      return;
    }

    setState(() => _isLoading = true);

    // Format time to string (e.g., "10:30 AM")
    final timeString = _selectedTime.format(context);

    try {
      final provider = Provider.of<RoutineProvider>(context, listen: false);

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
                  // 1. Course Dropdown
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

                  // 2. Day Dropdown
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

                  // 3. Time Picker
                  InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Select Time',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedTime.format(context), style: const TextStyle(fontSize: 16)),
                          const Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // 4. Save Button
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