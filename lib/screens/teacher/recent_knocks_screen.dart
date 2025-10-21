// screens/teacher/recent_knocks_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:intl/intl.dart';
import 'package:knocksense/widgets/common/useravatar_widget.dart';
import 'package:knocksense/widgets/teacher_dash/reject_all_modal.dart';
import 'package:knocksense/widgets/teacher_dash/teacher_response_widget.dart';
import 'package:knocksense/screens/teacher/future_appointments_screen.dart';

class RecentKnocksScreen extends ConsumerWidget {
  const RecentKnocksScreen({Key? key}) : super(key: key);

  void _showRejectAllModal(BuildContext context, UserModel user, List<AppointmentModel> appointments) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RejectAllModal(
        teacherUid: user.uid,
        appointmentsToReject: appointments,
      ),
    );
  }

  void _navigateToFutureAppointments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FutureAppointmentsScreen(),
      ),
    );
  }

@override
Widget build(BuildContext context, WidgetRef ref) {
  final currentUserAsync = ref.watch(currentUserProvider);
  // 1. Watch the original ASYNC provider to handle loading/error states
  final allAppointmentsAsync = ref.watch(teacherAllAppointmentsProvider);
  // Watch today's appointments (AsyncValue<List<AppointmentModel>>)
  final todayAppointmentsAsync = ref.watch(teacherTodayAppointmentsProvider);
  // Safe synchronous value for lightweight checks (e.g., menu enablement)
  final todayAppointments = todayAppointmentsAsync.asData?.value ?? <AppointmentModel>[];

  return Scaffold(
    resizeToAvoidBottomInset: false,
    backgroundColor: const Color(0xFFFDF6E3),
    body: SafeArea(
      child: currentUserAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          // 2. Use .when() on the async provider at the top level
          return allAppointmentsAsync.when(
            data: (allAppointments) {
              // 3. Build the rest of the UI with the final, filtered list
              return Column(
                children: [
                  // Header
                  Container(
                    color: const Color(0xFFFDF6E3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.chevron_left,
                            size: 32,
                            color: Color(0xFF6B4423), // Brown color
                          ),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Today\'s Appointments',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6B4423), // Brown color
                              ),
                            ),
                          ),
                        ),
                        // CORRECTED: The PopupMenuButton no longer needs .when()
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'reject_all' &&
                                todayAppointments.isNotEmpty) {
                              _showRejectAllModal(
                                  context, user, todayAppointments);
                            } else if (value == 'future_appointments') {
                              _navigateToFutureAppointments(context);
                            }
                          },
                          icon: const Icon(
                            Icons.more_horiz,
                            size: 28,
                            color: Color(0xFF6B4423),
                          ),
                          itemBuilder: (BuildContext context) =>
                              <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'future_appointments',
                              child: Row(
                                children: [
                                  Icon(Icons.schedule, size: 20),
                                  SizedBox(width: 12),
                                  Text('Future Appointments'),
                                ],
                              ),
                            ),
                            if (todayAppointments.isNotEmpty) ...[
                              const PopupMenuDivider(),
                              const PopupMenuItem<String>(
                                value: 'reject_all',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel,
                                        size: 20, color: Colors.red),
                                    SizedBox(width: 12),
                                    Text('Reject All Today\'s Appointments'),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Appointments List
                  Expanded(
                    child: todayAppointmentsAsync.when(
                      data: (appointments) {
                        if (appointments.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.today_outlined,
                                  size: 64,
                                  color: Colors.brown[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No appointments today',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.brown[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Today\'s appointments will appear here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.brown[400],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: appointments.length,
                          itemBuilder: (context, index) {
                            final appointment = appointments[index];
                            return _buildAppointmentCard(
                              context: context,
                              appointment: appointment,
                              user: user,
                            );
                          },
                        );
                      },
                      loading: () => const LoadingWidget(),
                      error: (err, stack) =>
                          Center(child: Text('Error loading today\'s appointments: $err')),
                    ),
                  ),
                ],
              );
            },
            loading: () => const LoadingWidget(),
            error: (err, stack) =>
                Center(child: Text('Error loading appointments: $err')),
          );
        },
        loading: () => const LoadingWidget(),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    ),
  );
}

  Widget _buildAppointmentCard({
    required BuildContext context,
    required AppointmentModel appointment,
    required dynamic user,
  }) {
    return GestureDetector(
      onTap: () {
        // Show the teacher response widget as a modal
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => TeacherResponseWidget(
            appointment: appointment,
            currentUser: user,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getCardColor(appointment),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Student Avatar with photo support
            UserAvatar.custom(
              photoUrl: appointment.studentPhotoUrl,
              displayName: appointment.cleanedStudentName,
              radius: 28, // Slightly larger for better visibility
              showBorder: false,
              backgroundColor: const Color(0xFFFFC107), // Amber color fallback
              textColor: Colors.black87,
            ),
            const SizedBox(width: 16),
            
            // Student info - FIXED: Better responsive layout
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Show scheduled time if it's a scheduled appointment - FIXED: Smart wrapping
                  if (appointment.isScheduled && appointment.scheduledTime != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Scheduled: ${DateFormat('h:mm a').format(appointment.scheduledTime!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.brown[700],
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2, // Allow wrapping to next line
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8), // Small gap before status badge
                        // Status badge on the same line, but will wrap if needed
                        if (_getStatusBadge(appointment) != null) 
                          _getStatusBadge(appointment)!,
                      ],
                    ),
                  ],
                  
                  if (appointment.studentNote != null && appointment.studentNote!.isNotEmpty) ...[
                    Text(
                      appointment.studentNote!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            
            // Time info - FIXED: Only show time when no scheduled appointment
            if (!(appointment.isScheduled && appointment.scheduledTime != null))
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _getTimeAgo(appointment.createdAt),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.brown[500],
                    ),
                  ),
                  // Status badge if needed (only for non-scheduled appointments)
                  if (_getStatusBadge(appointment) != null) ...[
                    const SizedBox(height: 4),
                    _getStatusBadge(appointment)!,
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Color _getCardColor(AppointmentModel appointment) {
    // Check if appointment is in waiting or meeting state
    final isWaiting = appointment.status == AppointmentStatus.accepted && 
                     appointment.teacherAction == TeacherAction.wait5Minutes;
    final isMeetNow = appointment.status == AppointmentStatus.accepted && 
                      appointment.teacherAction == TeacherAction.meetNow;
    
    if (isWaiting) {
      return const Color(0xFFFFE0B2); // Light orange for waiting
    } else if (isMeetNow) {
      return const Color(0xFFE8F5E8); // Light green for meeting
    } else if (appointment.isScheduled) {
      return const Color(0xFFE3F2FD); // Light blue for scheduled
    } else {
      return const Color(0xFFFFE69C); // Default light yellow/amber
    }
  }

  Widget? _getStatusBadge(AppointmentModel appointment) {
  final isWaiting = appointment.status == AppointmentStatus.accepted && 
                   appointment.teacherAction == TeacherAction.wait5Minutes;
  final isMeetLater = appointment.status == AppointmentStatus.accepted && 
                      appointment.teacherAction == TeacherAction.meetLater;
  
  if (isWaiting) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Waiting',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  } else if (isMeetLater) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Later',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  } else if (appointment.isScheduled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'Scheduled',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  return null;
}

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'min' : 'mins'} ago';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }
}

// Provider for today's appointments specifically
