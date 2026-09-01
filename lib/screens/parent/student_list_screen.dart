import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_config.dart';
import '../../config/theme.dart';
import '../../models/student_model.dart';
import '../../services/database_helper.dart';
import '../../widgets/al_ijadah_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/student_photo_widget.dart';
import 'digital_card_screen.dart';
import 'registration_screen.dart';

class StudentListScreen extends StatefulWidget {
  const StudentListScreen({super.key});

  @override
  State<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends State<StudentListScreen> {
  final _dbHelper = DatabaseHelper();
  List<StudentModel> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final list = await _dbHelper.getAllStudents();
      if (mounted) {
        setState(() {
          _students = list;
        });
      }
    } catch (e) {
      debugPrint('[StudentListScreen] Error loading students: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Database error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parent Portal - Student Passes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadStudents,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.push<StudentModel>(
            context,
            MaterialPageRoute(builder: (ctx) => const RegistrationScreen()),
          );
          if (created != null) {
            _loadStudents();
          }
        },
        backgroundColor: AppTheme.primaryRoyalBlue,
        icon: const Icon(Icons.add_rounded, color: AppTheme.accentGold),
        label: Text(
          'Register Child',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudents,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: AlIjadahHeader(),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Registered Children (${_students.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryRoyalBlue,
                      ),
                    ),
                    Text(
                      'Select to view Pass',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_students.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.badge_outlined, size: 64, color: AppTheme.primaryRoyalBlue.withOpacity(0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'No students registered yet',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "Register Child" below to create a new pickup pass.',
                        style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final student = _students[index];
                      return _buildStudentCard(student);
                    },
                    childCount: _students.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: SizedBox(height: 80),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentModel student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryRoyalBlue.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: student.isApproved ? AppTheme.accentGold.withOpacity(0.35) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => DigitalCardScreen(student: student),
            ),
          );
          _loadStudents();
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Photo Thumbnail
              Container(
                width: 54,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: student.isApproved ? AppTheme.accentGold : Colors.grey.shade300,
                    width: 2,
                  ),
                  color: const Color(0xFFF1F5F9),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildThumbPhoto(student.photoPath),
                ),
              ),
              const SizedBox(width: 10),
              // Information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryRoyalBlue,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        StatusBadge(status: student.status, compact: true),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      student.grade,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            student.parentMobile,
                            style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.textMuted),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Guardian: ${student.guardianName}',
                      style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              // Action Buttons: Edit, Delete (Admin) & View
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryRoyalBlue, size: 22),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: 'Edit Student Details',
                    onPressed: () async {
                      final updated = await Navigator.push<StudentModel>(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => RegistrationScreen(existingStudent: student),
                        ),
                      );
                      if (updated != null) {
                        _loadStudents();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.alertRed, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    tooltip: 'Delete Student (Admin Only)',
                    onPressed: () => _confirmDeleteWithAdminPin(student),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textLight, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteWithAdminPin(StudentModel student) async {
    final pinController = TextEditingController();
    final authorized = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: AppTheme.primaryRoyalBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Admin Authorization',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Deleting a student record requires the Setting Admin Passcode.',
              style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              autofocus: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Admin Passcode',
                hintText: '••••',
                prefixIcon: const Icon(Icons.lock_person_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (val) {
                Navigator.pop(ctx, val.trim() == AppConfig.settingsPin);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryRoyalBlue),
            onPressed: () {
              Navigator.pop(ctx, pinController.text.trim() == AppConfig.settingsPin);
            },
            child: const Text('Authorize'),
          ),
        ],
      ),
    );

    if (authorized != true) {
      if (pinController.text.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.alertRedDark,
            content: Text('Access Denied: Incorrect Admin Passcode'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_forever_rounded, color: AppTheme.alertRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Permanently Delete Student?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${student.name} (Grade: ${student.grade})?\n\nThis will remove all passes, guardian details, and pickup records. This cannot be undone.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteStudent(student.id);
      await _loadStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.primaryDarkBlue,
          content: Text('${student.name}\'s record was permanently deleted.'),
        ),
      );
    }
  }

  Widget _buildThumbPhoto(String? path) {
    return StudentPhotoWidget(
      photoPath: path,
      fit: BoxFit.cover,
      iconSize: 28,
    );
  }
}
