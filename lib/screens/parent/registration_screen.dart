import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../config/theme.dart';
import '../../models/student_model.dart';
import '../../services/database_helper.dart';
import '../../services/encryption_service.dart';
import '../../services/smtp_email_service.dart';
import '../../widgets/al_ijadah_header.dart';
import '../../widgets/student_photo_widget.dart';

class RegistrationScreen extends StatefulWidget {
  final StudentModel? existingStudent;

  const RegistrationScreen({super.key, this.existingStudent});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _dbHelper = DatabaseHelper();
  final _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _gradeController;
  late TextEditingController _supervisorController;
  late TextEditingController _guardianController;
  late TextEditingController _emailController;
  late TextEditingController _mobileController;

  String? _selectedPhotoPath;
  Uint8List? _selectedPhotoBytes;
  bool _isSubmitting = false;

  final List<String> _sampleGrades = [
    'KG 1 - Blossom',
    'KG 2 - Sunshine',
    'KG 3 - Tulip Class',
    'Grade 1 - Section A',
    'Grade 2 - Section B',
    'Grade 3 - Section A',
    'Grade 4 - Section B',
    'Grade 5 - Section A',
    'Grade 6 - Section C',
    'Grade 7 - Section A',
    'Grade 8 - Section B',
    'Grade 9 - Section A',
    'Grade 10 - Science Section',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.existingStudent;
    _nameController = TextEditingController(text: s?.name ?? '');
    _gradeController = TextEditingController(text: s?.grade ?? 'Grade 4 - Section B');
    _supervisorController = TextEditingController(text: s?.supervisor ?? 'Ustadh Tariq Al-Ghamdi');
    _guardianController = TextEditingController(text: s?.guardianName ?? 'Dr. Faisal Al-Mansoor (Father)');
    _emailController = TextEditingController(text: s?.parentEmail ?? 'parent@example.com');
    _mobileController = TextEditingController(text: s?.parentMobile ?? '+966 50 123 4567');
    _selectedPhotoPath = s?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _gradeController.dispose();
    _supervisorController.dispose();
    _guardianController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 600,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
        setState(() {
          _selectedPhotoBytes = bytes;
          _selectedPhotoPath = base64String;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick photo: $e')),
      );
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final studentId = widget.existingStudent?.id ??
          'AIS-2026-${(1000 + (DateTime.now().millisecondsSinceEpoch % 8999))}';
      // Existing students keep their status; all newly registered students start as PENDING_APPROVAL
      final status = widget.existingStudent != null
          ? widget.existingStudent!.status
          : 'PENDING_APPROVAL';

      final student = StudentModel(
        id: studentId,
        name: _nameController.text.trim(),
        grade: _gradeController.text.trim(),
        supervisor: _supervisorController.text.trim(),
        parentEmail: _emailController.text.trim(),
        parentMobile: _mobileController.text.trim(),
        guardianName: _guardianController.text.trim(),
        photoPath: _selectedPhotoPath,
        status: status,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      if (widget.existingStudent != null) {
        await _dbHelper.updateStudent(student);
      } else {
        await _dbHelper.insertStudent(student);

        // Generate approval code & send email alert to admin
        final approvalCode = EncryptionService().generateApprovalUnlockCode(studentId);
        SmtpEmailService().sendAdminRegistrationNotification(
          studentId: studentId,
          studentName: student.name,
          grade: student.grade,
          supervisor: student.supervisor,
          guardianName: student.guardianName,
          parentMobile: student.parentMobile,
          parentEmail: student.parentEmail,
          approvalCode: approvalCode,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.verifiedGreenDark,
          content: Text(
            widget.existingStudent != null
                ? 'Student record updated successfully!'
                : 'Registration submitted! An approval request with activation code has been emailed to the administration.',
          ),
        ),
      );

      Navigator.of(context).pop(student);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Error saving student: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingStudent != null ? 'Edit Student Pass' : 'Student Registration'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AlIjadahHeader(compact: true),
              const SizedBox(height: 16),

              // Photo Picker Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 110,
                          height: 125,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppTheme.accentGold, width: 3),
                            color: const Color(0xFFEDF2F7),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryRoyalBlue.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: (_selectedPhotoBytes != null ||
                                    (_selectedPhotoPath != null && _selectedPhotoPath!.isNotEmpty))
                                ? StudentPhotoWidget(
                                    photoPath: _selectedPhotoPath,
                                    memoryBytes: _selectedPhotoBytes,
                                    fit: BoxFit.cover,
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_rounded,
                                        size: 36,
                                        color: AppTheme.primaryRoyalBlue.withOpacity(0.6),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Student Photo',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => _showPhotoOptionsDialog(),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryRoyalBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _showPhotoOptionsDialog,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: Text(
                        _selectedPhotoPath != null ? 'Change Portrait Photo' : 'Upload Student Photo',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Student Info Card
              _buildSectionTitle('Student Information', Icons.school_rounded),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Student Full Name *',
                  hintText: 'e.g. Zaid Al-Mansoor',
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Student name is required' : null,
              ),

              const SizedBox(height: 14),

              DropdownButtonFormField<String>(
                value: _sampleGrades.contains(_gradeController.text) ? _gradeController.text : _sampleGrades.first,
                decoration: const InputDecoration(
                  labelText: 'Grade & Section *',
                  prefixIcon: Icon(Icons.class_rounded),
                ),
                items: _sampleGrades.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) {
                  if (val != null) _gradeController.text = val;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _supervisorController,
                decoration: const InputDecoration(
                  labelText: 'Supervisor / Teacher Name *',
                  hintText: 'e.g. Ustadh Tariq Al-Ghamdi',
                  prefixIcon: Icon(Icons.assignment_ind_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Supervisor name is required' : null,
              ),

              const SizedBox(height: 24),

              // Guardian & Parent Contacts
              _buildSectionTitle('Authorized Parent & Guardian Contact', Icons.family_restroom_rounded),
              const SizedBox(height: 12),

              TextFormField(
                controller: _guardianController,
                decoration: const InputDecoration(
                  labelText: 'Authorized Parent/Guardian Name(s) *',
                  hintText: 'e.g. Dr. Faisal Al-Mansoor (Father)',
                  prefixIcon: Icon(Icons.badge_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Authorized guardian name is required' : null,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Parent Mobile Number *',
                  hintText: 'e.g. +966 50 123 4567',
                  prefixIcon: Icon(Icons.phone_android_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Mobile number is required' : null,
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Registered Parent Email Address *',
                  hintText: 'e.g. parent@example.com',
                  prefixIcon: Icon(Icons.email_rounded),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Email is required for pickup alerts';
                  if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email address';
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Security Notice for New Pass Registrations
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined, color: AppTheme.primaryRoyalBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Administrative Security Verification',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppTheme.primaryDarkBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'New student registrations remain pending until the school administration reviews and approves the request. The administrator will reply to your email with a 6-digit activation code to unlock this pickup pass.',
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: AppTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _handleSave,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(
                    widget.existingStudent != null ? 'Update Record' : 'Save & Register Student',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRoyalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryRoyalBlue),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryRoyalBlue,
          ),
        ),
      ],
    );
  }

  void _showPhotoOptionsDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select Student Portrait',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded, color: AppTheme.primaryRoyalBlue),
                  title: const Text('Capture from Camera'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded, color: AppTheme.primaryRoyalBlue),
                  title: const Text('Choose from Photo Gallery'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
