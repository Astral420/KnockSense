// screens/teacher/future_appointments_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:intl/intl.dart';
import 'package:knocksense/widgets/common/useravatar_widget.dart';

class FutureAppointmentsScreen extends ConsumerWidget {
  const FutureAppointmentsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    final futureAppointmentsAsync = ref.watch(teacherFutureAppointmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6E3),
      body: SafeArea(
        child: currentUser.when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('User not found'));
            }

            return Column(
              children: [
                // Header
                Container(
                  color: const Color(0xFFFDF6E3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.chevron_left,
                          size: 32,
                          color: Color(0xFF6B4423),
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Future Appointments',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B4423),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 32), // Balance the header
                    ],
                  ),
                ),

                // Appointments List
                Expanded(
                  child: futureAppointmentsAsync.when(
                    data: (appointments) {
                      if (appointments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_month_outlined,
                                size: 64,
                                color: Colors.brown[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No future appointments',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.brown[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Scheduled appointments will appear here',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.brown[400],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // Group appointments by date
                      final Map<String, List<AppointmentModel>> groupedAppointments = {};
                      for (var appointment in appointments) {
                        final dateKey = DateFormat('yyyy-MM-dd').format(
                          appointment.scheduledTime ?? appointment.createdAt
                        );
                        groupedAppointments[dateKey] ??= [];
                        groupedAppointments[dateKey]!.add(appointment);
                      }

                      // Sort dates
                      final sortedDates = groupedAppointments.keys.toList()..sort();

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: sortedDates.length,
                        itemBuilder: (context, index) {
                          final date = sortedDates[index];
                          final dateAppointments = groupedAppointments[date]!;
                          final dateTime = DateTime.parse(date);
                          
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date Header
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  _formatDateHeader(dateTime),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown[700],
                                  ),
                                ),
                              ),
                              // Appointments for this date
                              ...dateAppointments.map((appointment) =>
                                _buildAppointmentCard(
                                  context: context,
                                  appointment: appointment,
                                  user: user,
                                )
                              ),
                              if (index < sortedDates.length - 1)
                                const Divider(height: 24),
                            ],
                          );
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
            );
          },
          loading: () => const LoadingWidget(),
          error: (err, stack) => Center(
            child: Text('Error: $err'),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard({
    required BuildContext context,
    required AppointmentModel appointment,
    required dynamic user,
  }) {
    final isNear = appointment.isNear;
    
    return GestureDetector(
      onTap: isNear ? () => _showNearAppointmentActions(context, appointment, user) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isNear ? const Color(0xFFFFE0B2) : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(16),
          border: isNear ? Border.all(color: Colors.orange, width: 2) : null,
        ),
        child: Row(
          children: [
            // Student Avatar
            UserAvatar.custom(
              photoUrl: appointment.studentPhotoUrl,
              displayName: appointment.cleanedStudentName,
              radius: 24,
              showBorder: false,
              backgroundColor: const Color(0xFFFFC107),
              textColor: Colors.black87,
            ),
            const SizedBox(width: 16),
            
            // Student info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.studentName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  
                  // Scheduled time
                  Row(
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 14,
                        color: Colors.brown[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('h:mm a').format(appointment.scheduledTime!),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.brown[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  
                  if (appointment.studentNote != null && appointment.studentNote!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      appointment.studentNote!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Status/Action indicator
            if (isNear) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Action Needed',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    
    if (date.year == tomorrow.year && 
        date.month == tomorrow.month && 
        date.day == tomorrow.day) {
      return 'Tomorrow';
    }
    
    return DateFormat('EEEE, MMMM d').format(date);
  }

  void _showNearAppointmentActions(BuildContext context, AppointmentModel appointment, dynamic user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Appointment Starting Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            Text(
              'Student: ${appointment.studentName}',
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              'Time: ${DateFormat('h:mm a').format(appointment.scheduledTime!)}',
              style: const TextStyle(fontSize: 16),
            ),
            
            if (appointment.studentNote != null && appointment.studentNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  appointment.studentNote!,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Accept button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleScheduledAppointmentResponse(context, appointment, user, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Accept Appointment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Reject button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleScheduledAppointmentResponse(context, appointment, user, false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reject Appointment',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleScheduledAppointmentResponse(
    BuildContext context,
    AppointmentModel appointment,
    dynamic user,
    bool accept,
  ) async {
    // Implementation would call the appointment service
    // This is a placeholder for the actual implementation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accept 
            ? 'Appointment accepted. Student will be notified.'
            : 'Appointment rejected. Student will be notified.',
        ),
        backgroundColor: accept ? Colors.green : Colors.red,
      ),
    );
  }
}

