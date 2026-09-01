import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/student_model.dart';
import '../../services/database_helper.dart';
import '../../services/backup_restore_service.dart';
import '../../widgets/al_ijadah_header.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/student_photo_widget.dart';
import '../parent/registration_screen.dart';

class AdminStudentManagementScreen extends StatefulWidget {
  const AdminStudentManagementScreen({super.key});

  @override
  State<AdminStudentManagementScreen> createState() => _AdminStudentManagementScreenState();
}

class _AdminStudentManagementScreenState extends State<AdminStudentManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<StudentModel> _allStudents = [];
  List<StudentModel> _filteredStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'ALL'; // 'ALL', 'APPROVED', 'PENDING', 'REVOKED'

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    final list = await _dbHelper.getAllStudents();
    if (!mounted) return;
    setState(() {
      _allStudents = list;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    List<StudentModel> result = List.from(_allStudents);

    // Filter by status tab
    if (_selectedFilter == 'APPROVED') {
      result = result.where((s) => s.isApproved).toList();
    } else if (_selectedFilter == 'PENDING') {
      result = result.where((s) => s.isPending).toList();
    } else if (_selectedFilter == 'REVOKED') {
      result = result.where((s) => s.isRevoked).toList();
    }

    // Filter by search query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      result = result.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q) ||
            s.grade.toLowerCase().contains(q) ||
            s.guardianName.toLowerCase().contains(q) ||
            s.parentMobile.contains(q);
      }).toList();
    }

    _filteredStudents = result;
  }

  Future<void> _confirmRevokePass(StudentModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.block_rounded, color: AppTheme.alertRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Revoke Pickup Pass?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to revoke the pickup pass for ${student.name}?\n\nThe parent\'s live dynamic QR pass will be immediately invalidated and cannot be scanned at security gates.',
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
            child: const Text('Revoke Pass'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.updateStudentStatus(student.id, 'REVOKED');
      await _loadStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.alertRedDark,
          content: Text('Pickup pass for ${student.name} has been revoked.'),
        ),
      );
    }
  }

  Future<void> _confirmApprovePass(StudentModel student) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.verified_rounded, color: AppTheme.verifiedGreenDark),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Approve Pickup Pass?',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Directly approve and activate the pickup pass for ${student.name}?\n\nThe dynamic live QR pass will immediately unlock for the parent.',
          style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.verifiedGreenDark),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve Pass'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.updateStudentStatus(student.id, 'APPROVED');
      await _loadStudents();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.verifiedGreenDark,
          content: Text('Pickup pass for ${student.name} is now approved and active!'),
        ),
      );
    }
  }

  Future<void> _confirmDeleteStudent(StudentModel student) async {
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
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete ${student.name} (Grade: ${student.grade}, ID: ${student.id}) from school records?\n\nThis will remove all associated passes, guardian details, and pickup history. This action CANNOT be undone.',
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
          content: Text('${student.name}\'s record has been permanently removed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _allStudents.length;
    final approvedCount = _allStudents.where((s) => s.isApproved).length;
    final pendingCount = _allStudents.where((s) => s.isPending).length;
    final revokedCount = _allStudents.where((s) => s.isRevoked).length;

    return Scaffold(
      backgroundColor: AppTheme.backgroundOffWhite,
      appBar: AppBar(
        title: const Text('Student Records & Pass Authority'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Student List',
            onPressed: _loadStudents,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'Backup & Database Options',
            onSelected: (val) async {
              final backupService = BackupRestoreService();
              if (val == 'export') {
                await backupService.exportAndShareBackup(context);
              } else if (val == 'restore') {
                await backupService.pickAndRestoreBackup(context, onRestored: _loadStudents);
              } else if (val == 'email') {
                await backupService.emailBackupToAdmin(context);
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.upload_file_rounded, color: AppTheme.primaryRoyalBlue, size: 20),
                    SizedBox(width: 10),
                    Text('Export & Share Backup'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, color: AppTheme.verifiedGreenDark, size: 20),
                    SizedBox(width: 10),
                    Text('Restore Backup File'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'email',
                child: Row(
                  children: [
                    Icon(Icons.email_outlined, color: AppTheme.accentGoldDark, size: 20),
                    SizedBox(width: 10),
                    Text('Email Backup to Admin'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (ctx) => const RegistrationScreen()),
          );
          _loadStudents();
        },
        backgroundColor: AppTheme.primaryRoyalBlue,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Student'),
      ),
      body: Column(
        children: [
          // Header banner
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AlIjadahHeader(compact: true),
                const SizedBox(height: 12),
                // Search bar
                TextField(
                  onChanged: (val) {
                    _searchQuery = val;
                    setState(_applyFilter);
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by student name, ID, or grade...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter chips row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All ($totalCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('APPROVED', 'Approved ($approvedCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('PENDING', 'Pending ($pendingCount)'),
                      const SizedBox(width: 8),
                      _buildFilterChip('REVOKED', 'Revoked ($revokedCount)'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Student list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline_rounded, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No students matching "$_searchQuery"'
                                  : 'No students found in this category',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (ctx, idx) {
                          final student = _filteredStudents[idx];
                          return _buildStudentAdminCard(student);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppTheme.textDark,
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryRoyalBlue,
      backgroundColor: const Color(0xFFF1F5F9),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filterKey;
            _applyFilter();
          });
        }
      },
    );
  }

  Widget _buildStudentAdminCard(StudentModel student) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Photo
                Container(
                  width: 56,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: student.isApproved
                          ? AppTheme.accentGold
                          : student.isRevoked
                              ? AppTheme.alertRed
                              : Colors.grey.shade300,
                      width: 2,
                    ),
                    color: const Color(0xFFF1F5F9),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: StudentPhotoWidget(
                      photoPath: student.photoPath,
                      fit: BoxFit.cover,
                      iconSize: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Student info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              student.name,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryRoyalBlue,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadge(status: student.status, compact: true),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Grade: ${student.grade} • ID: ${student.id}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Guardian: ${student.guardianName} (${student.parentMobile})',
                        style: GoogleFonts.outfit(fontSize: 11.5, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Email: ${student.parentEmail}',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textMuted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // Administration Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Pass Status Toggle Action (Revoke / Approve)
                if (student.isApproved)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.alertRed,
                      side: const BorderSide(color: AppTheme.alertRed),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _confirmRevokePass(student),
                    icon: const Icon(Icons.block_rounded, size: 15),
                    label: const Text('Revoke Pass', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.verifiedGreenDark,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => _confirmApprovePass(student),
                    icon: const Icon(Icons.check_circle_rounded, size: 15),
                    label: const Text('Approve Pass', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit details button
                    IconButton(
                      icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryRoyalBlue),
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
                    // Delete record button
                    IconButton(
                      icon: const Icon(Icons.delete_forever_rounded, color: AppTheme.alertRed),
                      tooltip: 'Permanently Delete Record',
                      onPressed: () => _confirmDeleteStudent(student),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
