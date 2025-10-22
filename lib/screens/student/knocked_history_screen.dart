import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/widgets/common/notification_icon_widget.dart';
import 'dart:async';

// Debounce timer for date range updates
Timer? _debounceTimer;

// Filtered history based on date range with debouncing
final filteredAppointmentHistoryProvider = Provider<List<AppointmentModel>>((ref) {
  final appointments = ref.watch(studentAppointmentsProvider);
  final dateRange = ref.watch(dateRangeProvider);
  
  return appointments.when(
    data: (appointmentList) {
      if (dateRange == null) return appointmentList;
      
      // Create start and end of day for proper filtering
      final startOfDay = DateTime(
        dateRange.start.year, 
        dateRange.start.month, 
        dateRange.start.day, 
        0, 0, 0, 0, 0
      );
      
      final endOfDay = DateTime(
        dateRange.end.year, 
        dateRange.end.month, 
        dateRange.end.day, 
        23, 59, 59, 999, 999
      );
      
      print('Filtering appointments:');
      print('Date range: ${startOfDay} to ${endOfDay}');
      print('Total appointments: ${appointmentList.length}');
      
      final filtered = appointmentList.where((appointment) {
        final appointmentDate = appointment.createdAt;
        final isInRange = appointmentDate.isAtSameMomentAs(startOfDay) || 
                         appointmentDate.isAtSameMomentAs(endOfDay) ||
                         (appointmentDate.isAfter(startOfDay) && appointmentDate.isBefore(endOfDay));
        
        print('Appointment ${appointment.appointmentId}: ${appointmentDate} - ${isInRange ? 'INCLUDED' : 'EXCLUDED'}');
        return isInRange;
      }).toList();
      
      print('Filtered appointments: ${filtered.length}');
      return filtered;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

class KnockedHistoryPage extends ConsumerWidget {
  const KnockedHistoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredHistory = ref.watch(filteredAppointmentHistoryProvider);
    final dateRange = ref.watch(dateRangeProvider);
    final appointmentsAsync = ref.watch(studentAppointmentsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Knocked History',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Student',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const NotificationIconWidget(
                        iconColor: Colors.black,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Date Range Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter by Date Range:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Start Date',
                          date: dateRange?.start,
                          onTap: () => _selectDateRange(context, ref),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'End Date',
                          date: dateRange?.end,
                          onTap: () => _selectDateRange(context, ref),
                        ),
                      ),
                    ],
                  ),
                  if (dateRange != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () => _clearFilterWithDebounce(ref),
                            child: const Text(
                              'Clear Filter',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${filteredHistory.length} appointments found',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // History List
            Expanded(
              child: appointmentsAsync.when(
                data: (appointments) {
                  if (filteredHistory.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            dateRange != null 
                                ? 'No appointments found in selected date range'
                                : 'No appointment history found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (dateRange != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${DateFormat('MMM dd, yyyy').format(dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(dateRange.end)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  // Sort appointments by creation date (newest first)
                  final sortedAppointments = List<AppointmentModel>.from(filteredHistory)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = sortedAppointments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AppointmentHistoryCard(appointment: appointment),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading appointment history',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(studentAppointmentsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilterWithDebounce(WidgetRef ref) {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    // Immediately clear the filter for better UX
    ref.read(dateRangeProvider.notifier).state = null;
  }

  Future<void> _selectDateRange(BuildContext context, WidgetRef ref) async {
    final currentDateRange = ref.read(dateRangeProvider);
    
    final initialDateRange = currentDateRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: initialDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.black,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _updateDateRangeWithDebounce(ref, picked);
    }
  }

  void _updateDateRangeWithDebounce(WidgetRef ref, DateTimeRange dateRange) {
    // Cancel existing timer
    _debounceTimer?.cancel();
    
    print('Date range selected: ${dateRange.start} to ${dateRange.end}');
    
    // Set new timer with 300ms delay
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      print('Applying date filter after debounce');
      ref.read(dateRangeProvider.notifier).state = dateRange;
    });
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null
                    ? DateFormat('MMM dd, yyyy').format(date!)
                    : label,
                style: TextStyle(
                  fontSize: 14,
                  color: date != null ? Colors.black : Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentHistoryCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentHistoryCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    // Generate initials from teacher name
    final teacherInitials = _getInitials(appointment.cleanedTeacherName);
    
    // Determine which date to display
    final displayDate = appointment.isScheduled && appointment.scheduledTime != null
        ? appointment.scheduledTime!
        : appointment.createdAt;
    
    final isScheduledAppointment = appointment.isScheduled && appointment.scheduledTime != null;

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Teacher Avatar
            appointment.teacherPhotoUrl != null
              ? CachedNetworkImage(
                  imageUrl: appointment.teacherPhotoUrl!,
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    radius: 28,
                    backgroundImage: imageProvider,
                  ),
                  placeholder: (context, url) => const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.amber,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.amber,
                    child: Text(
                      teacherInitials,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                )
              : CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.amber,
                  child: Text(
                    teacherInitials,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
            const SizedBox(width: 14),
            
            // Teacher Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.cleanedTeacherName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Show scheduled time first if it's a scheduled appointment
                  if (isScheduledAppointment) ...[
                    Row(
                      children: [
                        // Icon(
                        //   Icons.schedule,
                        //   size: 11,
                        //   color: Colors.blue[600],
                        // ),
                        const SizedBox(width: 0),
                        Text(
                          'Scheduled: ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            DateFormat('MM/dd/yy, h:mm a').format(displayDate),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  
                  // Show created date
                  Text(
                    isScheduledAppointment 
                        ? 'Created: ${DateFormat('M/d/yyyy, h:mm a').format(appointment.createdAt)}'
                        : DateFormat('M/d/yyyy, h:mm a').format(appointment.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Status Widget
            _buildStatusWidget(appointment.status, appointment.teacherAction),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final cleanedName = name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();

    if (cleanedName.isEmpty) {
      return '??';
    }

    // Handle "LastName, FirstName" format
    if (cleanedName.contains(',')) {
      final parts = cleanedName.split(',').map((part) => part.trim()).toList();
      if (parts.length > 1 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
    }

    // Handle "FirstName MiddleName LastName" format
    final matches = RegExp(r'\b\w').allMatches(cleanedName);
    final initials = matches.map((m) => m.group(0)!).toList();

    if (initials.isEmpty) {
      return '??';
    } else if (initials.length == 1) {
      return initials.first.toUpperCase();
    } else {
      return '${initials.first}${initials.last}'.toUpperCase();
    }
  }

  Widget _buildStatusWidget(AppointmentStatus status, TeacherAction? teacherAction) {
    switch (status) {
      case AppointmentStatus.pending:
        return const _StatusChip(
          label: 'Pending',
          color: Colors.orange,
          icon: Icons.schedule,
        );
      case AppointmentStatus.accepted:
        return _StatusChip(
          label: _getAcceptedStatusLabel(teacherAction),
          color: Colors.green,
          icon: Icons.check_circle,
        );
      case AppointmentStatus.denied:
        return const _StatusChip(
          label: 'Denied',
          color: Colors.red,
          icon: Icons.close,
        );
      case AppointmentStatus.completed:
        return const _StatusChip(
          label: 'Completed',
          color: Colors.blue,
          icon: Icons.check_circle,
        );
      case AppointmentStatus.cancelled:
        return const _StatusChip(
          label: 'Cancelled',
          color: Colors.grey,
          icon: Icons.cancel,
        );
      default:
        return const SizedBox();
    }
  }

  String _getAcceptedStatusLabel(TeacherAction? action) {
    switch (action) {
      case TeacherAction.meetNow:
        return 'Meet Now';
      case TeacherAction.wait5Minutes:
        return 'Wait 5 Min';
      case TeacherAction.meetLater:
        return 'Meet Later';
      default:
        return 'Accepted';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusChip({
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}