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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);
    // Use teacherActiveAppointmentsProvider instead of teacherPendingAppointmentsProvider
    final appointmentsAsync = ref.watch(teacherActiveAppointmentsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFDF6E3), // Cream background matching design
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
                          color: Color(0xFF6B4423), // Brown color
                        ),
                      ),
                      const Expanded(
                        child: Center(
                          child: Text(
                            'Recent Knocks',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6B4423), // Brown color
                            ),
                          ),
                        ),
                      ),
                        appointmentsAsync.when(
                          data: (appointments) {
                            if (appointments.isNotEmpty) {
                              return PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'reject_all') {
                                    _showRejectAllModal(context, user, appointments);
                                  }
                                },
                                icon: const Icon(
                                  Icons.more_horiz,
                                  size: 28,
                                  color: Color(0xFF6B4423),
                                ),
                                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'reject_all',
                                    child: Text('Reject All Appointments'),
                                  ),
                                ],
                              );
                            } else {
                              return const SizedBox(width: 48);
                            }
                          },
                          loading: () => const SizedBox(width: 48),
                          error: (_, __) => const SizedBox(width: 48),
                        ),
                      ],
                      ),
                      ),

                // Appointments List
                Expanded(
                  child: appointmentsAsync.when(
                    data: (appointments) {
                      if (appointments.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 64,
                                color: Colors.brown[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No recent knocks',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.brown[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Students will appear here when they knock',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: appointments.length,
                        itemBuilder: (context, index) {
                          final appointment = appointments[index];
                          return _buildKnockCard(
                            context: context,
                            appointment: appointment,
                            user: user,
                          );
                        },
                      );
                    },
                    loading: () => const LoadingWidget(),
                    error: (err, stack) => Center(
                      child: Text('Error loading knocks: $err'),
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

  Widget _buildKnockCard({
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
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: TeacherResponseWidget(
            appointment: appointment,
            currentUser: user,
          ),
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
               
                if (appointment.studentNote != null && appointment.studentNote!.isNotEmpty) ...[
                  const SizedBox(height: 4),
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
          
          // Time ago
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
              // Optional: Add status badge if needed
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
    } else {
      return const Color(0xFFFFE69C); // Default light yellow/amber
    }
  }

  Widget? _getStatusBadge(AppointmentModel appointment) {
    final isWaiting = appointment.status == AppointmentStatus.accepted && 
                     appointment.teacherAction == TeacherAction.wait5Minutes;
    final isMeetNow = appointment.status == AppointmentStatus.accepted && 
                      appointment.teacherAction == TeacherAction.meetNow;
    
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
    } else if (isMeetNow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'In Progress',
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

  // String _getInitials(String name) {
  //   if (name.isEmpty) return '??';
    
  //   // Remove any role indicators in parentheses
  //   final cleanName = name.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
    
  //   final parts = cleanName.split(' ');
  //   if (parts.length >= 2) {
  //     // Take first letter of first name and last name
  //     final firstName = parts.first;
  //     final lastName = parts.last;
      
  //     if (firstName.isNotEmpty && lastName.isNotEmpty) {
  //       return '${firstName[0]}${lastName[0]}'.toUpperCase();
  //     }
  //   }
    
  //   // If only one name or parsing fails, return first two letters
  //   if (cleanName.length >= 2) {
  //     return cleanName.substring(0, 2).toUpperCase();
  //   }
    
  //   return cleanName.isNotEmpty ? cleanName[0].toUpperCase() : '??';
  // }

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
