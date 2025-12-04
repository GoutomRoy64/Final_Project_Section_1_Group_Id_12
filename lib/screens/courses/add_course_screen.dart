import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import '../../models/course_model.dart';

class AddCourseScreen extends StatefulWidget {
  final Course? courseToEdit; // If null, we are adding. If not null, we are editing.

  const AddCourseScreen({super.key, this.courseToEdit});

  @override
  State<AddCourseScreen> createState() => _AddCourseScreenState();
}

class _AddCourseScreenState extends State<AddCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill fields if we are editing
    _nameController = TextEditingController(text: widget.courseToEdit?.name ?? '');
    _codeController = TextEditingController(text: widget.courseToEdit?.code ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<CourseProvider>(context, listen: false);

      if (widget.courseToEdit == null) {
        // Add new course
        await provider.addCourse(_nameController.text, _codeController.text);
      } else {
        // Edit existing course
        await provider.updateCourse(widget.courseToEdit!.id, _nameController.text, _codeController.text);
      }

      if (mounted) {
        Navigator.of(context).pop(); // Go back to list
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $error")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseToEdit == null ? 'Add Course' : 'Edit Course'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Course Name',
                  hintText: 'e.g. Mobile Application Development',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Course Code',
                  hintText: 'e.g. CSE-401',
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Please enter a code' : null,
              ),
              const SizedBox(height: 25),
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
                  child: const Text('Save Course', style: TextStyle(fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}