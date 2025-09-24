import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

// Providers for date filtering
final startDateProvider = StateProvider<DateTime?>((ref) => null);
final endDateProvider = StateProvider<DateTime?>((ref) => null);

class AdminActivityLogsScreen extends ConsumerWidget {
  const AdminActivityLogsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startDate = ref.watch(startDateProvider);
    final endDate = ref.watch(endDateProvider);

    // Mock activity logs data - replace with real data from Firebase
    final allLogs = [
      ActivityLogItem(
        isEntry: true,
        name: "Prof. Santos",
        rfid: "22:0C:10:01",
        time: const TimeOfDay(hour: 10, minute: 5),
        date: DateTime(2025, 1, 22),
      ),
      ActivityLogItem(
        isEntry: false,
        name: "Prof. Kim",
        rfid: "10:00:03:1D",
        time: const TimeOfDay(hour: 10, minute: 5),
        date: DateTime(2025, 1, 22),
      ),
      ActivityLogItem(
        isEntry: true,
        name: "Prof. Kim",
        rfid: "10:00:03:1D",
        time: const TimeOfDay(hour: 10, minute: 0),
        date: DateTime(2025, 1, 22),
      ),
      ActivityLogItem(
        isEntry: false,
        name: "Prof. Gonzales",
        rfid: "A2:7A:B5:AB",
        time: const TimeOfDay(hour: 9, minute: 58),
        date: DateTime(2025, 1, 22),
      ),
      ActivityLogItem(
        isEntry: true,
        name: "Prof. Gonzales",
        rfid: "A2:7A:B5:AB",
        time: const TimeOfDay(hour: 9, minute: 55),
        date: DateTime(2025, 1, 22),
      ),
    ];

    final filteredLogs = _filterLogsByDateRange(allLogs, startDate, endDate);

    return Scaffold(
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
              if (filteredLogs.isEmpty)
                _buildEmptyState()
              else
                ...filteredLogs.map((log) => _buildLogItem(log)),
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
              TextButton(
                onPressed: () {
                  ref.read(startDateProvider.notifier).state = null;
                  ref.read(endDateProvider.notifier).state = null;
                },
                child: const Text("Clear Filters"),
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
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(ActivityLogItem log) {
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
            // Entry/Exit icon
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.transparent,
              child: SvgPicture.asset(
                log.isEntry ? 'assets/icons/entry.svg' : 'assets/icons/exit.svg',
                width: 35,
                height: 35,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),

            // Name + RFID
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    log.name,
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "RFID: ${log.rfid}",
                    style: GoogleFonts.roboto(
                      color: Colors.grey,
                      fontSize: 12,
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
                  _formatTime(log.time),
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(log.date),
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

  List<ActivityLogItem> _filterLogsByDateRange(List<ActivityLogItem> logs, 
      DateTime? start, DateTime? end) {
    if (start == null && end == null) return logs;

    return logs.where((log) {
      final logDate = DateTime(log.date.year, log.date.month, log.date.day);
      
      if (start != null) {
        final startDate = DateTime(start.year, start.month, start.day);
        if (logDate.isBefore(startDate)) return false;
      }
      
      if (end != null) {
        final endDate = DateTime(end.year, end.month, end.day);
        if (logDate.isAfter(endDate)) return false;
      }
      
      return true;
    }).toList();
  }

  Future<void> _selectStartDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDate: ref.read(startDateProvider) ?? now,
    );
    if (picked != null) {
      ref.read(startDateProvider.notifier).state = picked;
    }
  }

  Future<void> _selectEndDate(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final start = ref.read(startDateProvider);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      initialDate: ref.read(endDateProvider) ?? start ?? now,
    );
    if (picked != null) {
      ref.read(endDateProvider.notifier).state = picked;
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final ampm = time.period == DayPeriod.am ? "AM" : "PM";
    return "$hour:$minute $ampm";
  }

  String _formatDate(DateTime date) {
    return "${date.month.toString().padLeft(2, '0')}/"
           "${date.day.toString().padLeft(2, '0')}/"
           "${date.year.toString().substring(2)}";
  }
}

class ActivityLogItem {
  final bool isEntry;
  final String name;
  final String rfid;
  final TimeOfDay time;
  final DateTime date;

  ActivityLogItem({
    required this.isEntry,
    required this.name,
    required this.rfid,
    required this.time,
    required this.date,
  });
}