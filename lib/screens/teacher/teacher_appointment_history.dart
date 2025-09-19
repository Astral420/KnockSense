// screens/teacher/teacher_appointment_history.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:intl/intl.dart';

class TeacherAppointmentHistory extends ConsumerStatefulWidget {
  const TeacherAppointmentHistory({Key? key}) : super(key: key);

  @override
  ConsumerState<TeacherAppointmentHistory> createState() => _TeacherAppointmentHistoryState();
}

class _TeacherAppointmentHistoryState extends ConsumerState<TeacherAppointmentHistory> {
  DateTime? startDate;
  DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    final appointmentsAsync = ref.watch(teacherAllAppointmentsProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                  // Date Range Filter
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter by Date Range:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: 'Start Date',
                              date: startDate,
                              onTap: () => _selectStartDate(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDateField(
                              label: 'End Date',
                              date: endDate,
                              onTap: () => _selectEndDate(context),
                            ),
                          ),
                        ],
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
                  // Filter appointments by date range if selected
                  final filteredAppointments = _filterAppointmentsByDate(appointments);
                  
                  if (filteredAppointments.isEmpty) {
                    return const Center(
                      child: Text(
                        'No appointments found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
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

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8ED),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today,
              size: 18,
              color: Color(0xFF9E9E9E),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                date != null 
                    ? DateFormat('MM/dd/yyyy').format(date)
                    : label,
                style: TextStyle(
                  fontSize: 14,
                  color: date != null ? Colors.black87 : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            // Student Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  'S',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Student Info
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
            
            // Status Badge
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
        return const Color(0xFFE0E0E0); // Grey
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

  List<AppointmentModel> _filterAppointmentsByDate(List<AppointmentModel> appointments) {
    if (startDate == null && endDate == null) {
      return appointments;
    }
    
    return appointments.where((appointment) {
      if (startDate != null && appointment.createdAt.isBefore(startDate!)) {
        return false;
      }
      if (endDate != null) {
        // Include the entire end date by comparing to the end of that day
        final endOfDay = DateTime(endDate!.year, endDate!.month, endDate!.day, 23, 59, 59);
        if (appointment.createdAt.isAfter(endOfDay)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        startDate = picked;
        // Ensure end date is not before start date
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? DateTime.now(),
      firstDate: startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        endDate = picked;
      });
    }
  }
}