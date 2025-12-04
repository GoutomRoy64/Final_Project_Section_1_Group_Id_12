import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/student_provider.dart';
import '../../models/student_model.dart';

class AddStudentScreen extends StatefulWidget {
  final String courseId;
  final Student? studentToEdit;

  const AddStudentScreen({
    super.key,
    required this.courseId,
    this.studentToEdit,
  });

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rollController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.studentToEdit?.name ?? '');
    _rollController = TextEditingController(text: widget.studentToEdit?.rollNumber ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<StudentProvider>(context, listen: false);

      if (widget.studentToEdit == null) {
        // Add new student
        await provider.addStudent(
          widget.courseId,
          _nameController.text,
          _rollController.text,
        );
      } else {
        // Edit existing student
        await provider.updateStudent(
          widget.courseId,
          widget.studentToEdit!.id,
          _nameController.text,
          _rollController.text,
        );
      }

      if (mounted) {
        Navigator.of(context).pop();
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
        title: Text(widget.studentToEdit == null ? 'Enroll Student' : 'Edit Student'),
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
                  labelText: 'Student Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (val) => val!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _rollController,
                decoration: const InputDecoration(
                  labelText: 'Student ID / Roll No',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                validator: (val) => val!.isEmpty ? 'Please enter an ID' : null,
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
                  child: const Text('Save Student', style: TextStyle(fontSize: 18)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}