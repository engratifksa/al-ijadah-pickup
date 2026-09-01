import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../models/email_queue_item.dart';
import '../../services/database_helper.dart';
import '../../services/smtp_email_service.dart';

class EmailQueueScreen extends StatefulWidget {
  const EmailQueueScreen({super.key});

  @override
  State<EmailQueueScreen> createState() => _EmailQueueScreenState();
}

class _EmailQueueScreenState extends State<EmailQueueScreen> {
  final _dbHelper = DatabaseHelper();
  final _smtpService = SmtpEmailService();
  List<EmailQueueItem> _items = [];
  bool _isLoading = true;
  bool _isFlushing = false;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadQueueItems();
  }

  Future<void> _checkConnectivity() async {
    try {
      final res = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _isOnline = res.any((r) => r != ConnectivityResult.none);
        });
      }
    } catch (_) {}
  }

  Future<void> _loadQueueItems() async {
    setState(() => _isLoading = true);
    final list = await _dbHelper.getAllQueueItems();
    if (mounted) {
      setState(() {
        _items = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFlushQueue() async {
    setState(() => _isFlushing = true);
    try {
      final flushedCount = await _smtpService.flushPendingQueue();
      await _loadQueueItems();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.verifiedGreenDark,
          content: Text('Flushed $flushedCount pending pickup email(s) via Direct SMTP!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: AppTheme.alertRedDark, content: Text('Flush error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFlushing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingList = _items.where((i) => !i.sent).toList();
    final sentList = _items.where((i) => i.sent).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Email Dispatch Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Queue',
            onPressed: () {
              _checkConnectivity();
              _loadQueueItems();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Network & Queue Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isOnline ? AppTheme.verifiedGreenBg : AppTheme.alertRedBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                    color: _isOnline ? AppTheme.verifiedGreenDark : AppTheme.alertRedDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isOnline ? 'Online (Direct SMTP Ready)' : 'Offline Mode (Local Storage)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _isOnline ? AppTheme.verifiedGreenDark : AppTheme.alertRedDark,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${pendingList.length} Pending • ${sentList.length} Delivered',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isFlushing || pendingList.isEmpty ? null : _handleFlushQueue,
                  icon: _isFlushing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Flush Queue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryRoyalBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    textStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Queue Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_email_read_outlined, size: 54, color: AppTheme.primaryRoyalBlue.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Email queue is empty',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pickup notifications will appear here when confirmed.',
                              style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return _buildQueueItemCard(item);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueItemCard(EmailQueueItem item) {
    final isSent = item.sent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSent ? const Color(0xFFE2E8F0) : AppTheme.accentGold,
          width: isSent ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSent ? Colors.black.withOpacity(0.02) : AppTheme.accentGold.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSent ? AppTheme.verifiedGreenBg : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSent ? AppTheme.verifiedGreen.withOpacity(0.4) : const Color(0xFFFDE68A),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSent ? Icons.check_circle_rounded : Icons.schedule_rounded,
                      size: 13,
                      color: isSent ? AppTheme.verifiedGreenDark : const Color(0xFFB45309),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSent ? 'DISPATCHED VIA SMTP' : 'PENDING_DISPATCH (OFFLINE)',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isSent ? AppTheme.verifiedGreenDark : const Color(0xFFB45309),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Task #${item.id ?? '-'}',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.studentName,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryRoyalBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Guardian: ${item.guardianName}',
            style: GoogleFonts.outfit(fontSize: 13, color: AppTheme.textDark, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(item.parentEmail, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(width: 12),
              const Icon(Icons.phone_outlined, size: 13, color: AppTheme.textMuted),
              const SizedBox(width: 4),
              Text(item.parentMobile, style: GoogleFonts.outfit(fontSize: 12, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Timestamp: ${item.pickupTimestamp}',
            style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textLight),
          ),
        ],
      ),
    );
  }
}
