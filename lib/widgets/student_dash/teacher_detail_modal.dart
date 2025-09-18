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
  Set<String> _notifiedTeachers = {}; // Track which teachers student is notified for

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
          
          // Content with better spacing
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Teacher profile section
                _buildTeacherProfileSection(teacher),
                
                const SizedBox(height: 24),
                
                // Status notifications
                ..._buildStatusNotifications(teacher, hasPendingAppointment),
                
                // Teacher message if available
                if (teacher.teacherMsg != null && teacher.teacherMsg!.isNotEmpty) ...[
                  _buildTeacherMessage(teacher.teacherMsg!),
                  const SizedBox(height: 20),
                ],
                
                // Note input field
                _buildNoteInputField(),
                
                const SizedBox(height: 24),
                
                // Action buttons
                _buildActionButtons(teacher, currentUser, hasPendingAppointment),
                
                // Add some bottom padding for better visual balance
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherProfileSection(TeacherModel teacher) {
    return Row(
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
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teacher.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                teacher.teacherID,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Status: ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getStatusColor(teacher.activeStatus).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatStatus(teacher.activeStatus),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getStatusColor(teacher.activeStatus),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStatusNotifications(TeacherModel teacher, bool hasPendingAppointment) {
    List<Widget> notifications = [];

    // Show pending appointment notice if exists
    if (hasPendingAppointment) {
      notifications.add(
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.schedule,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pending Appointment',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You already have a pending appointment with this teacher. Please wait for a response.',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return notifications;
  }

  Widget _buildTeacherMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.blue.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Teacher\'s Message',
                  style: TextStyle(
                    color: Colors.blue[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add a note (optional)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText: 'Briefly describe your reason for the appointment...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
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
              borderSide: const BorderSide(color: Colors.blue, width: 2),
            ),
            contentPadding: const EdgeInsets.all(16),
            counterText: '', // Hide character counter
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(TeacherModel teacher, UserModel? currentUser, bool hasPendingAppointment) {
    final bool isTeacherAvailable = teacher.activeStatus.toLowerCase() == 'online';
    final bool canKnock = !_isKnocking && 
                         !hasPendingAppointment && 
                         isTeacherAvailable &&
                         currentUser != null;

    return Row(
      children: [
        // Knock button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canKnock
                ? () => _handleKnock(teacher, currentUser!)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[500],
              elevation: canKnock ? 2 : 0,
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
              _isKnocking ? 'Sending...' : 'Knock',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 12),
        
        // Notify Me button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _handleNotifyMe(teacher),
            style: OutlinedButton.styleFrom(
              foregroundColor: _notifiedTeachers.contains(teacher.uid) 
                  ? Colors.orange 
                  : Colors.blue,
              side: BorderSide(
                color: _notifiedTeachers.contains(teacher.uid) 
                    ? Colors.orange 
                    : Colors.blue,
                width: 1.5,
              ),
              backgroundColor: _notifiedTeachers.contains(teacher.uid)
                  ? Colors.orange.withOpacity(0.1)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: Icon(
              _notifiedTeachers.contains(teacher.uid)
                  ? Icons.notifications_active
                  : Icons.notifications_outlined,
              size: 20,
            ),
            label: Text(
              _notifiedTeachers.contains(teacher.uid) 
                  ? 'Notifying' 
                  : 'Notify Me',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
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
      final appointmentService = ref.read(appointmentServiceProvider);
      final note = _noteController.text.trim();
      
      final result = await appointmentService.createAppointment(
        student: currentUser,
        teacher: teacher,
        studentNote: note.isNotEmpty ? note : null,
      );
      
      if (result['success'] == true) {
        Navigator.pop(context);
        _showSuccessMessage('Appointment request sent to ${teacher.displayName}');
      } else {
        _showErrorMessage(result['error'] ?? 'Failed to send appointment request. Please try again.');
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
    setState(() {
      if (_notifiedTeachers.contains(teacher.uid)) {
        _notifiedTeachers.remove(teacher.uid);
        print('🔔 Student unsubscribed from notifications for ${teacher.displayName}');
        _showInfoMessage('Notifications disabled for ${teacher.displayName}');
      } else {
        _notifiedTeachers.add(teacher.uid);
        print('🔔 Student subscribed to notifications for ${teacher.displayName}');
        _showSuccessMessage('You\'ll be notified when ${teacher.displayName} becomes available');
      }
    });
    
    // TODO: Implement FCM notification setup
    // This would typically involve:
    // - Setting up a listener for teacher status changes
    // - Storing user preference for notifications in Firebase/local storage
    // - Scheduling FCM notification when status changes to online
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
          margin: const EdgeInsets.all(16),
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
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showInfoMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
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