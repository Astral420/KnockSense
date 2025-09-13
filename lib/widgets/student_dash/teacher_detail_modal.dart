import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/teacher_model.dart';
import 'package:knocksense/provider/teacher_provider.dart';

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

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the specific teacher to get real-time updates
    final teacherAsync = ref.watch(teacherByUidProvider(widget.teacher.uid));
    
    return teacherAsync.when(
      data: (currentTeacher) {
        // Use the current teacher data if available, fallback to initial teacher
        final teacher = currentTeacher ?? widget.teacher;
        
        return _buildModalContent(teacher);
      },
      loading: () => _buildModalContent(widget.teacher),
      error: (_, __) => _buildModalContent(widget.teacher),
    );
  }

  Widget _buildModalContent(TeacherModel teacher) {
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
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.amber,
                          backgroundImage: teacher.photoUrl != null
                              ? NetworkImage(teacher.photoUrl!)
                              : null,
                          child: teacher.photoUrl == null
                              ? Text(
                                  teacher.initials,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                )
                              : null,
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
                
                // Note input field
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add a student note...',
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
                    // Knock button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: teacher.activeStatus.toLowerCase() == 'online'
                            ? () => _handleKnock(teacher)
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
                        ),
                        icon: const Icon(
                          Icons.notifications,
                          size: 20,
                        ),
                        label: const Text(
                          'Knock',
                          style: TextStyle(
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
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.alarm,
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

  void _handleKnock(TeacherModel teacher) {
    final note = _noteController.text.trim();
    Navigator.pop(context);
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Knock sent to ${teacher.displayName}'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
    
    // TODO: Implement actual knock functionality
    // This would typically involve:
    // - Sending notification to teacher
    // - Storing the note if provided
    // - Creating an appointment request record
    print('Knock sent to ${teacher.displayName}');
    if (note.isNotEmpty) {
      print('Student note: $note');
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