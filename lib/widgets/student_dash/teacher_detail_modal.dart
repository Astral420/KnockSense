// widgets/student_dash/teacher_detail_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:knocksense/models/teacher_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/teacher_provider.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/appointment_provider.dart';

class TeacherDetailModal extends ConsumerStatefulWidget {
  final TeacherModel teacher;

  const TeacherDetailModal({
    Key? key,
    required this.teacher,
  }) : super(key: key);

  @override
  ConsumerState<TeacherDetailModal> createState() => _TeacherDetailModalState();
}

class _TeacherDetailModalState extends ConsumerState<TeacherDetailModal> {
  final TextEditingController _noteController = TextEditingController();
  bool _isKnocking = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the specific teacher to get real-time updates
    final teacherAsync = ref.watch(teacherByUidProvider(widget.teacher.uid));
    final currentUser = ref.watch(currentUserProvider);
    final hasPendingAppointment = ref.watch(
      hasPendingAppointmentProvider(widget.teacher.uid)
    );
    
    return teacherAsync.when(
      data: (currentTeacher) {
        // Use the current teacher data if available, fallback to initial teacher
        final teacher = currentTeacher ?? widget.teacher;
        
        return currentUser.when(
          data: (user) => _buildModalContent(
            teacher, 
            user, 
            hasPendingAppointment.value ?? false
          ),
          loading: () => _buildModalContent(teacher, null, false),
          error: (_, __) => _buildModalContent(teacher, null, false),
        );
      },
      loading: () => _buildModalContent(widget.teacher, null, false),
      error: (_, __) => _buildModalContent(widget.teacher, null, false),
    );
  }

  Widget _buildModalContent(
    TeacherModel teacher, 
    UserModel? currentUser,
    bool hasPendingAppointment,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teacher profile section
                Row(
                  children: [
                    Stack(
                      children: [
                        // Teacher avatar with CachedNetworkImage
                        teacher.photoUrl != null
                            ? CachedNetworkImage(
                                imageUrl: teacher.photoUrl!,
                                imageBuilder: (context, imageProvider) => CircleAvatar(
                                  radius: 40,
                                  backgroundImage: imageProvider,
                                ),
                                placeholder: (context, url) => CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.amber,
                                  child: const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (context, url, error) => CircleAvatar(
                                  radius: 40,
                                  backgroundColor: Colors.amber,
                                  child: Text(
                                    teacher.initials,
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              )
                            : CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.amber,
                                child: Text(
                                  teacher.initials,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                        // Status indicator
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _getStatusColor(teacher.activeStatus),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teacher.displayName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            _formatStatus(teacher.activeStatus),
                            style: TextStyle(
                              fontSize: 16,
                              color: _getStatusColor(teacher.activeStatus),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Show pending appointment notice if exists
                if (hasPendingAppointment)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.schedule,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You already have a pending appointment with this teacher.',
                            style: TextStyle(
                              color: Colors.orange[800],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Teacher message if available
                if (teacher.teacherMsg != null && teacher.teacherMsg!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.blue.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Teacher\'s Message:',
                                style: TextStyle(
                                  color: Colors.blue[800],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                teacher.teacherMsg!,
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Note input field
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a note for your appointment request...',
                    hintStyle: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Action buttons
                Row(
                  children: [
                    // Knock/Request Appointment button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_isKnocking || 
                                   hasPendingAppointment ||
                                   teacher.activeStatus.toLowerCase() == 'offline' ||
                                   currentUser == null)
                            ? null
                            : () => _handleKnock(teacher, currentUser),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                          disabledForegroundColor: Colors.grey[500],
                        ),
                        icon: _isKnocking
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.notifications,
                                size: 20,
                              ),
                        label: Text(
                          _isKnocking ? 'Requesting...' : 'Request Appointment',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Notify Me button (for when teacher is offline)
                    if (teacher.activeStatus.toLowerCase() != 'online')
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleNotifyMe(teacher),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue,
                            side: const BorderSide(color: Colors.blue),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.notifications_outlined,
                            size: 20,
                          ),
                          label: const Text(
                            'Notify Me',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    
                    const SizedBox(width: 12),
                    
                    // Close button
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                
                // Add some bottom padding for better visual balance
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
        return Colors.green;
      case 'busy':
        return Colors.orange;
      case 'offline':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  Future<void> _handleKnock(TeacherModel teacher, UserModel currentUser) async {
    if (currentUser.studentNumber == null) {
      _showErrorMessage('Student information not found. Please contact support.');
      return;
    }

    setState(() {
      _isKnocking = true;
    });

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      final note = _noteController.text.trim();
      
      final appointmentId = await appointmentNotifier.createAppointment(
        student: currentUser,
        teacher: teacher,
        studentNote: note.isNotEmpty ? note : null,
      );
      
      if (appointmentId != null) {
        Navigator.pop(context);
        _showSuccessMessage('Appointment request sent to ${teacher.displayName}');
      } else {
        _showErrorMessage('Failed to send appointment request. Please try again.');
      }
    } catch (e) {
      _showErrorMessage('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isKnocking = false;
        });
      }
    }
  }

  void _handleNotifyMe(TeacherModel teacher) {
    Navigator.pop(context);
    
    // Show notification setup message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('You\'ll be notified when ${teacher.displayName} becomes available'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    
    // TODO: Implement notification setup
    // This would typically involve:
    // - Setting up a listener for teacher status changes
    // - Storing user preference for notifications
    // - Scheduling local notification when status changes to online
    print('Notification set up for ${teacher.displayName}');
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }
}

// Extension to show the modal easily from anywhere
extension TeacherDetailModalExtension on BuildContext {
  Future<void> showTeacherDetail(TeacherModel teacher) {
    return showModalBottomSheet<void>(
      context: this,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TeacherDetailModal(teacher: teacher),
    );
  }
}