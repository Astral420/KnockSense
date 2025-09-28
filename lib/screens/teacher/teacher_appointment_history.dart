// screens/teacher/teacher_appointment_history.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:intl/intl.dart';
import 'package:knocksense/widgets/common/useravatar_widget.dart';

// ======== REFACTORED WIDGET ========
class TeacherAppointmentHistory extends ConsumerWidget {
  const TeacherAppointmentHistory({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(teacherAllAppointmentsProvider);
    final filteredAppointments = ref.watch(filteredTeacherHistoryProvider);
    final dateRange = ref.watch(dateRangeProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Appointment History',
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
                              'Teacher',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Stack(
                            children: [
                              const Icon(
                                Icons.notifications,
                                color: Color(0xFFFFD700),
                                size: 24,
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ======== REPLACED DATE RANGE FILTER UI ========
                  Column(
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
                                onPressed: () => _clearFilter(ref),
                                child: const Text(
                                  'Clear Filter',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${filteredAppointments.length} appointments found',
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
                ],
              ),
            ),
            
            // Appointments List
            Expanded(
              child: appointmentsAsync.when(
                data: (appointments) {
                  if (filteredAppointments.isEmpty) {
                    return Center(
                      child: Text(
                        dateRange != null
                            ? 'No appointments found in selected date range'
                            : 'No appointment history found',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredAppointments.length,
                    itemBuilder: (context, index) {
                      final appointment = filteredAppointments[index];
                      return _buildAppointmentCard(appointment);
                    },
                  );
                },
                loading: () => const LoadingWidget(),
                error: (err, stack) => Center(
                  child: Text('Error loading appointments: $err'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearFilter(WidgetRef ref) {
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
      ref.read(dateRangeProvider.notifier).state = picked;
    }
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    final isWaiting = appointment.status == AppointmentStatus.accepted && 
                      appointment.teacherAction == TeacherAction.wait5Minutes;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3B82F6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            UserAvatar.custom(
              photoUrl: appointment.studentPhotoUrl,
              displayName: appointment.cleanedStudentName,
              radius: 24,
              showBorder: false,
              backgroundColor: const Color(0xFFFFD700),
              textColor: Colors.black,
            ),
            const SizedBox(width: 12),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.studentName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('M/d/yyyy, h:mm a').format(appointment.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusColor(appointment.status, isWaiting),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _getStatusText(appointment.status, isWaiting),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status, bool isWaiting) {
    if (isWaiting) {
      return const Color(0xFFE0E0E0); // Grey for waiting
    }
    
    switch (status) {
      case AppointmentStatus.completed:
        return const Color.fromARGB(255, 59, 141, 207); // blue
      case AppointmentStatus.pending:
        return const Color(0xFFFFF3CD); // Light yellow
      case AppointmentStatus.accepted:
        return const Color(0xFFD4EDDA); // Light green
      case AppointmentStatus.denied:
      case AppointmentStatus.cancelled:
        return const Color(0xFFF8D7DA); // Light red
      default:
        return const Color(0xFFE0E0E0);
    }
  }

  String _getStatusText(AppointmentStatus status, bool isWaiting) {
    if (isWaiting) {
      return 'Waiting';
    }
    
    switch (status) {
      case AppointmentStatus.completed:
        return 'Completed';
      case AppointmentStatus.pending:
        return 'Pending';
      case AppointmentStatus.accepted:
        return 'Accepted';
      case AppointmentStatus.denied:
        return 'Denied';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }
}

// ======== COPIED WIDGET FOR CONSISTENT UI ========
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