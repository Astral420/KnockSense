// widgets/teacher/teacher_response_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/appointment_provider.dart';

class TeacherResponseWidget extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final UserModel currentUser;

  const TeacherResponseWidget({
    Key? key,
    required this.appointment,
    required this.currentUser,
  }) : super(key: key);

  @override
  ConsumerState<TeacherResponseWidget> createState() => _TeacherResponseWidgetState();
}

class _TeacherResponseWidgetState extends ConsumerState<TeacherResponseWidget> {
  final TextEditingController _noteController = TextEditingController();
  bool _isResponding = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3), // Light cream background matching Figma
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with student info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.amber,
                  child: Text(
                    _getInitials(widget.appointment.studentName),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.appointment.studentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '2 mins ago', // You can calculate this from appointment.createdAt
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
            
            const SizedBox(height: 12),
            
            // Student's request message
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Text(
                widget.appointment.studentNote ?? 'Need consultation for Capstone',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Teacher note input
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a teacher note...',
                hintStyle: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action question
            const Text(
              'How would you like to proceed with this request?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Action buttons
            Column(
              children: [
                // Meet Now button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isResponding 
                        ? null 
                        : () => _handleResponse(TeacherAction.meetNow),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981), // Green
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: _isResponding
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Meet Now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Wait 5 Minutes button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isResponding 
                        ? null 
                        : () => _handleResponse(TeacherAction.wait5Minutes),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B), // Dark blue/navy
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text(
                      'Wait 5 Minutes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Meet Later button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isResponding 
                        ? null 
                        : () => _handleResponse(TeacherAction.meetLater),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B), // Amber/yellow
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text(
                      'Meet Later',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // Not Now button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isResponding 
                        ? null 
                        : () => _handleResponse(TeacherAction.reject),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444), // Red
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const Text(
                      'Not Now',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Close button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _isResponding ? null : () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '??';
    
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else {
      return parts[0][0].toUpperCase();
    }
  }

  Future<void> _handleResponse(TeacherAction action) async {
    setState(() {
      _isResponding = true;
    });

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      final note = _noteController.text.trim();
      
      DateTime? scheduledTime;
      if (action == TeacherAction.meetLater) {
        // For "Meet Later", you might want to show a date/time picker
        // For now, we'll set it to 1 hour from now as default
        scheduledTime = DateTime.now().add(const Duration(hours: 1));
      }
      
      final success = await appointmentNotifier.respondToAppointment(
        studentNumber: widget.appointment.studentNumber,
        appointmentId: widget.appointment.appointmentId,
        teacherUid: widget.currentUser.uid,
        action: action,
        teacherResponse: note.isNotEmpty ? note : null,
        scheduledTime: scheduledTime,
      );
      
      if (success && mounted) {
        Navigator.pop(context);
        _showSuccessMessage(_getSuccessMessage(action));
      } else if (mounted) {
        _showErrorMessage('Failed to respond to appointment. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorMessage('An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResponding = false;
        });
      }
    }
  }

  String _getSuccessMessage(TeacherAction action) {
    switch (action) {
      case TeacherAction.meetNow:
        return 'Student notified to meet you now!';
      case TeacherAction.wait5Minutes:
        return 'Student asked to wait 5 minutes.';
      case TeacherAction.meetLater:
        return 'Appointment scheduled for later.';
      case TeacherAction.reject:
        return 'Appointment request declined.';
      default:
        return 'Response sent successfully.';
    }
  }

  void _showSuccessMessage(String message) {
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

  void _showErrorMessage(String message) {
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

// Extension to show the widget as a modal
extension TeacherResponseWidgetExtension on BuildContext {
  Future<void> showTeacherResponse(AppointmentModel appointment, UserModel currentUser) {
    return showModalBottomSheet<void>(
      context: this,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TeacherResponseWidget(
          appointment: appointment,
          currentUser: currentUser,
        ),
      ),
    );
  }
}