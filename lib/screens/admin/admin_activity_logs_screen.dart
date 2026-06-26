// admin_activity_logs_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:knocksense/provider/activity_logs_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';

class AdminActivityLogsScreen extends ConsumerWidget {
  const AdminActivityLogsScreen({Key? key}) : super(key: key);

  // Design system colors
  static const Color kBg = Color(0xFFF7F8FB);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kText = Color(0xFF111827);
  static const Color kMuted = Color(0xFF888888);
  static const Color kYellow = Color(0xFFFACC15);
  static const Color kGreen = Color(0xFF16A34A);
  static const Color kRed = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDate = ref.watch(startDateProvider);
    final endDate = ref.watch(endDateProvider);
    final filteredLogs = ref.watch(filteredActivityLogsProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: Text(
          "Activity Logs",
          style: GoogleFonts.roboto(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Force refresh by invalidating the provider
              ref.invalidate(activityLogsStreamProvider);
            },
            tooltip: 'Refresh logs',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Date Range Filter Card
              _buildDateRangeFilter(context, ref, startDate, endDate),
              const SizedBox(height: 12),

              // Activity Logs
              filteredLogs.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return _buildEmptyState();
                  }
                  
                  // Group logs by date for better organization
                  final groupedLogs = _groupLogsByDate(logs);
                  
                  return Column(
                    children: groupedLogs.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              _formatDateHeader(entry.key),
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: kMuted,
                              ),
                            ),
                          ),
                          // Logs for this date
                          ...entry.value.map((log) => _buildLogItem(log)),
                          const SizedBox(height: 12),
                        ],
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: LoadingWidget(message: 'Loading activity logs...'),
                  ),
                ),
                error: (err, stack) => Center(
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading activity logs',
                            style: GoogleFonts.roboto(
                              color: Colors.red.shade600,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            err.toString(),
                            style: GoogleFonts.roboto(
                              color: kMuted,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => ref.invalidate(activityLogsStreamProvider),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeFilter(BuildContext context, WidgetRef ref, 
      DateTime? startDate, DateTime? endDate) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Filter by Date Range:",
              style: GoogleFonts.roboto(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    context: context,
                    label: startDate == null ? "Start Date" : _formatDate(startDate),
                    onTap: () => _selectStartDate(context, ref),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    context: context,
                    label: endDate == null ? "End Date" : _formatDate(endDate),
                    onTap: () => _selectEndDate(context, ref),
                  ),
                ),
              ],
            ),
            if (startDate != null || endDate != null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  ref.read(startDateProvider.notifier).state = null;
                  ref.read(endDateProvider.notifier).state = null;
                },
                icon: const Icon(Icons.clear),
                label: const Text("Clear Filters"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFECEDF2),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SvgPicture.asset(
              'assets/icons/calendar.svg',
              width: 18,
              height: 18,
              fit: BoxFit.contain,
              colorFilter: const ColorFilter.mode(Colors.black54, BlendMode.srcIn),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No activity logs found',
              style: GoogleFonts.roboto(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activity logs will appear here when teachers enter or exit',
              style: GoogleFonts.roboto(
                color: kMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(ActivityLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 2),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Entry/Exit icon or Avatar
            _buildLogAvatar(log),
            const SizedBox(width: 10),

            // Name + RFID + Teacher ID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          log.teacherName,
                          style: GoogleFonts.roboto(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: log.isEntry ? kGreen.withOpacity(0.1) : kRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.isEntry ? 'IN' : 'OUT',
                          style: GoogleFonts.roboto(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: log.isEntry ? kGreen : kRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "RFID: ${log.rfidUid ?? 'Not assigned'}",
                    style: GoogleFonts.roboto(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    "ID: ${log.teacherID}",
                    style: GoogleFonts.roboto(
                      color: Colors.grey,
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Time + Date
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  log.formattedTime,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.formattedDate,
                  style: GoogleFonts.roboto(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogAvatar(ActivityLog log) {
    // If there's a photo URL, use it; otherwise use the entry/exit icon
    if (log.photoUrl != null && log.photoUrl!.isNotEmpty) {
      return Stack(
        children: [
          CachedNetworkImage(
            imageUrl: log.photoUrl!,
            imageBuilder: (context, imageProvider) => CircleAvatar(
              radius: 18,
              backgroundImage: imageProvider,
              backgroundColor: kYellow,
            ),
            placeholder: (context, url) => CircleAvatar(
              radius: 18,
              backgroundColor: kYellow.withOpacity(0.5),
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  color: kText,
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildIconAvatar(log),
          ),
          // Small indicator for entry/exit
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: log.isEntry ? kGreen : kRed,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      );
    }
    
    return _buildIconAvatar(log);
  }

  Widget _buildIconAvatar(ActivityLog log) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.transparent,
      child: SvgPicture.asset(
        log.isEntry ? 'assets/icons/entry.svg' : 'assets/icons/exit.svg',
        width: 35,
        height: 35,
        fit: BoxFit.contain,
      ),
    );
  }

  Map<DateTime, List<ActivityLog>> _groupLogsByDate(List<ActivityLog> logs) {
    final Map<DateTime, List<ActivityLog>> grouped = {};
    
    for (final log in logs) {
      final date = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
      grouped[date]!.add(log);
    }
    
    return grouped;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    
    if (date == today) {
      return 'Today';
    } else if (date == yesterday) {
      return 'Yesterday';
    } else {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  Future<void> _selectStartDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final endDate = ref.read(endDateProvider);
    
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: endDate ?? DateTime(now.year + 3),
      initialDate: ref.read(startDateProvider) ?? now,
    );
    
    if (picked != null) {
      ref.read(startDateProvider.notifier).state = picked;
      
      // If end date is now before start date, clear it
      if (endDate != null && picked.isAfter(endDate)) {
        ref.read(endDateProvider.notifier).state = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('End date cleared as it was before the new start date'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _selectEndDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final startDate = ref.read(startDateProvider);
    
    final picked = await showDatePicker(
      context: context,
      firstDate: startDate ?? DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDate: ref.read(endDateProvider) ?? startDate ?? now,
    );
    
    if (picked != null) {
      ref.read(endDateProvider.notifier).state = picked;
    }
  }

  String _formatDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/"
           "${date.day.toString().padLeft(2, '0')}/"
           "${date.year}";
  }
}