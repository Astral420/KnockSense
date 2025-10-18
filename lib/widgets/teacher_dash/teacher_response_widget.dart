// widgets/teacher/teacher_response_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/widgets/common/useravatar_widget.dart';

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
  bool _hasNoteError = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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

  void _clearNoteError() {
    if (_hasNoteError) {
      setState(() {
        _hasNoteError = false;
      });
    }
  }

  // Add this method to check if appointment needs scheduled response
  bool _isScheduledAppointmentRequiringResponse() {
    // Check if this is a scheduled appointment that's pending
    if (widget.appointment.isScheduled && 
        widget.appointment.scheduledTime != null &&
        widget.appointment.status == AppointmentStatus.pending) {
      
      final now = DateTime.now();
      final scheduledTime = widget.appointment.scheduledTime!;
      
      // Calculate today's appointment day boundaries (6:30 AM to 6:30 AM next day)
      final todayReset = DateTime(now.year, now.month, now.day, 6, 30);
      
      final DateTime appointmentDayStart;
      if (now.isBefore(todayReset)) {
        // Before 6:30 AM - appointment day started yesterday at 6:30 AM
        appointmentDayStart = todayReset.subtract(const Duration(days: 1));
      } else {
        // After 6:30 AM - appointment day started today at 6:30 AM
        appointmentDayStart = todayReset;
      }
      
      final appointmentDayEnd = appointmentDayStart.add(const Duration(days: 1));
      
      // Show scheduled UI if the appointment is scheduled for today's appointment window
      // (between 6:30 AM today and 6:30 AM tomorrow)
      if ((scheduledTime.isAtSameMomentAs(appointmentDayStart) ||
           scheduledTime.isAfter(appointmentDayStart)) &&
          scheduledTime.isBefore(appointmentDayEnd)) {
        return true;
      }
    }
    return false;
  }


  @override
  Widget build(BuildContext context) {
    // Check appointment type and status
    final isScheduledDue = _isScheduledAppointmentRequiringResponse();
    final isWaiting = widget.appointment.status == AppointmentStatus.accepted && 
                      widget.appointment.teacherAction == TeacherAction.wait5Minutes;
    final isMeetNow = widget.appointment.status == AppointmentStatus.accepted && 
                      widget.appointment.teacherAction == TeacherAction.meetNow;
    final isMeetLater = widget.appointment.status == AppointmentStatus.accepted && 
                        widget.appointment.teacherAction == TeacherAction.meetLater;
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with student info
            Row(
              children: [
                // Use UserAvatar.custom instead of hardcoded CircleAvatar
                UserAvatar.custom(
                  photoUrl: widget.appointment.studentPhotoUrl,
                  displayName: widget.appointment.studentName,
                  radius: 24,
                  showBorder: false,
                  backgroundColor: Colors.amber,
                  textColor: Colors.black87,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.appointment.studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTimeAgo(widget.appointment.createdAt),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isWaiting || isMeetNow || isMeetLater)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(isWaiting, isMeetNow, isMeetLater),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _getStatusText(isWaiting, isMeetNow, isMeetLater),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Student's request message
            if (widget.appointment.studentNote != null &&
                widget.appointment.studentNote!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  widget.appointment.studentNote!,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: const Text(
                  'No note provided by student.',
                  style: TextStyle(
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Decision logic for which UI to show
            if (isScheduledDue && widget.appointment.status == AppointmentStatus.pending) ...[
              // For scheduled appointments when professor was offline/busy
              _buildScheduledAppointmentResponseUI(),
            ] else if (isWaiting) ...[
              _buildWaitingManagementUI(),
            ] else if (isMeetLater) ...[
              _buildMeetLaterManagementUI(),
            ] else ...[
              // Regular pending appointment (immediate request when online)
              _buildPendingAppointmentUI(),
            ],
          ],
        ),
      ),
    );
  }

  

  Color _getStatusColor(bool isWaiting, bool isMeetNow, bool isMeetLater) {
    if (isWaiting) return Colors.orange;
    if (isMeetLater) return Colors.blue;
    return Colors.grey;
  }

  String _getStatusText(bool isWaiting, bool isMeetNow, bool isMeetLater) {
    if (isWaiting) return 'Waiting';
    if (isMeetLater) return 'Scheduled';
    return 'Unknown';
  }

  Widget _buildWaitingManagementUI() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Student is waiting (5 minutes requested)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can now meet the student or cancel the appointment.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Teacher note input for cancellation
        TextField(
          controller: _noteController,
          onChanged: (_) => _clearNoteError(),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add an optional note...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.blue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        
        if (_hasNoteError) ...[
          const SizedBox(height: 8),
          Text(
            'Please provide a reason for cancellation',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Action buttons for waiting status
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleMeetNowFromWaiting(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isResponding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Meet Student Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleCancelFromWaiting(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Cancel Meeting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isResponding ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Widget _buildMeetNowManagementUI() {
  //   return Column(
  //     children: [
  //       Container(
  //         width: double.infinity,
  //         padding: const EdgeInsets.all(16),
  //         decoration: BoxDecoration(
  //           color: Colors.green.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(color: Colors.green.withOpacity(0.3)),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             const Text(
  //               'Meeting in Progress',
  //               style: TextStyle(
  //                 fontSize: 16,
  //                 fontWeight: FontWeight.w600,
  //                 color: Colors.green,
  //               ),
  //             ),
  //             const SizedBox(height: 8),
  //             Text(
  //               'The student should be with you now.',
  //               style: TextStyle(
  //                 fontSize: 14,
  //                 color: Colors.grey[600],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
        
  //       const SizedBox(height: 20),
        
  //       // Action button to complete meeting
  //       SizedBox(
  //         width: double.infinity,
  //         child: ElevatedButton(
  //           onPressed: _isResponding 
  //               ? null 
  //               : () => _handleCompleteMeeting(),
  //           style: ElevatedButton.styleFrom(
  //             backgroundColor: const Color(0xFF3B82F6),
  //             foregroundColor: Colors.white,
  //             padding: const EdgeInsets.symmetric(vertical: 16),
  //             shape: RoundedRectangleBorder(
  //               borderRadius: BorderRadius.circular(12),
  //             ),
  //             disabledBackgroundColor: Colors.grey[300],
  //           ),
  //           child: _isResponding
  //               ? const SizedBox(
  //                   width: 20,
  //                   height: 20,
  //                   child: CircularProgressIndicator(
  //                     strokeWidth: 2,
  //                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
  //                   ),
  //                 )
  //               : const Text(
  //                   'Finish Meeting',
  //                   style: TextStyle(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                 ),
  //         ),
  //       ),
        
  //       const SizedBox(height: 16),
        
  //       SizedBox(
  //         width: double.infinity,
  //         child: TextButton(
  //           onPressed: _isResponding ? null : () => Navigator.pop(context),
  //           style: TextButton.styleFrom(
  //             foregroundColor: Colors.grey[600],
  //             padding: const EdgeInsets.symmetric(vertical: 16),
  //           ),
  //           child: const Text(
  //             'Close',
  //             style: TextStyle(
  //               fontSize: 16,
  //               fontWeight: FontWeight.w500,
  //             ),
  //           ),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildMeetLaterManagementUI() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Meeting Scheduled for Later',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can now meet the student or cancel the appointment.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Teacher note input
        TextField(
          controller: _noteController,
          onChanged: (_) => _clearNoteError(),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add a note or reason for cancellation...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.blue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        
        if (_hasNoteError) ...[
          const SizedBox(height: 8),
          Text(
            'Please provide a note for this action',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Action buttons
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleMeetNowFromLater(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isResponding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Meet Student Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleCancelFromLater(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Cancel Meeting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isResponding ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPendingAppointmentUI() {
    return Column(
      children: [
        // Teacher note input
        TextField(
          controller: _noteController,
          onChanged: (_) => _clearNoteError(),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Add a teacher note...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.blue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        
        if (_hasNoteError) ...[
          const SizedBox(height: 8),
          Text(
            'Please provide a note for this action',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Action question
        const Text(
          'How would you like to proceed with this request?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        
        const SizedBox(height: 16),
        
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
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isResponding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Meet Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Wait 5 Minutes button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleResponse(TeacherAction.wait5Minutes),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Wait 5 Minutes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Meet Later button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleResponse(TeacherAction.meetLater),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Meet Later',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Not Now button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleResponse(TeacherAction.reject),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Not Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isResponding ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // New method for scheduled appointment response
  Widget _buildScheduledAppointmentResponseUI() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Scheduled Appointment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scheduled for: ${DateFormat('h:mm a').format(widget.appointment.scheduledTime!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please provide your location if accepting, or reason if rejecting.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Required note input
        TextField(
          controller: _noteController,
          onChanged: (_) => _clearNoteError(),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Enter your location (if accepting) or reason (if rejecting)...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.grey[200]!,
                width: _hasNoteError ? 2 : 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: _hasNoteError ? Colors.red : Colors.blue,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        
        if (_hasNoteError) ...[
          const SizedBox(height: 8),
          Text(
            'Please provide your location or rejection reason',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Only Accept/Reject buttons for scheduled appointments
        Column(
          children: [
            // Accept Meeting button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleScheduledAccept(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isResponding
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Accept Meeting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Reject Meeting button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isResponding 
                    ? null 
                    : () => _handleScheduledReject(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: const Text(
                  'Reject Meeting',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isResponding ? null : () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // String _getInitials(String name) {
  //   if (name.isEmpty) return '??';
    
  //   final parts = name.trim().split(' ');
  //   if (parts.length >= 2) {
  //     return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  //   } else {
  //     return parts[0][0].toUpperCase();
  //   }
  // }

  Future<void> _handleResponse(TeacherAction action) async {
  // Validate that Meet Later requires a note
  if (action == TeacherAction.meetLater && _noteController.text.trim().isEmpty) {
    setState(() {
      _hasNoteError = true;
    });
    return;
  }
  
  // Validate that rejection (Not Now) requires a note
  if (action == TeacherAction.reject && _noteController.text.trim().isEmpty) {
    setState(() {
      _hasNoteError = true;
    });
    return;
  }
  
  setState(() {
    _isResponding = true;
  });

  try {
    final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
    final note = _noteController.text.trim();
    
    // If action is meetNow, handle completion differently
    if (action == TeacherAction.meetNow) {
      // First pop the modal to prevent UI issues
      if (mounted) {
        Navigator.pop(context);
      }
      
      // Then complete the appointment after a small delay
      await Future.delayed(const Duration(milliseconds: 100));
      
      final success = await appointmentNotifier.completeAppointment(
        studentNumber: widget.appointment.studentNumber,
        appointmentId: widget.appointment.appointmentId,
        teacherUid: widget.currentUser.uid,
      );
      
      if (success && mounted) {
        // Show success message in the parent context
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Meeting completed successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to complete meeting. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
      return; // Exit early
    }
    
    // Handle other actions normally
    DateTime? scheduledTime;
    if (action == TeacherAction.meetLater) {
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

  Future<void> _handleMeetNowFromWaiting() async {
  setState(() {
    _isResponding = true;
  });

  try {
    final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
    
    // Directly complete the appointment instead of just updating status
    final success = await appointmentNotifier.completeAppointment(
      studentNumber: widget.appointment.studentNumber,
      appointmentId: widget.appointment.appointmentId,
      teacherUid: widget.currentUser.uid,
    );
    
    if (success && mounted) {
      Navigator.pop(context); // Close modal
      _showSuccessMessage('Meeting completed successfully!');
    } else if (mounted) {
      _showErrorMessage('Failed to complete meeting. Please try again.');
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

  Future<void> _handleMeetNowFromLater() async {
    setState(() {
      _isResponding = true;
    });

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      final note = _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : 'Meeting now instead of later.';

      final success = await appointmentNotifier.meetAndCompleteAppointment(
        studentNumber: widget.appointment.studentNumber,
        appointmentId: widget.appointment.appointmentId,
        teacherUid: widget.currentUser.uid,
        teacherNote: note,
      );

      if (success && mounted) {
        Navigator.pop(context); // Close modal
        _showSuccessMessage('Meeting has been completed.');
      } else if (mounted) {
        _showErrorMessage('Failed to complete meeting. Please try again.');
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

  Future<void> _handleCancelFromWaiting() async {
    final reason = _noteController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _hasNoteError = true;
      });
      return;
    }

    setState(() {
      _isResponding = true;
    });

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      
      final success = await appointmentNotifier.cancelAppointment(
        studentNumber: widget.appointment.studentNumber,
        appointmentId: widget.appointment.appointmentId,
        teacherUid: widget.currentUser.uid,
        reason: reason,
      );
      
      if (success && mounted) {
        Navigator.pop(context); // Close modal
        _showSuccessMessage('Meeting has been cancelled.');
      } else if (mounted) {
        _showErrorMessage('Failed to cancel meeting. Please try again.');
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

  Future<void> _handleCancelFromLater() async {
    final reason = _noteController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _hasNoteError = true;
      });
      return;
    }

    setState(() {
      _isResponding = true;
    });

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      
      final success = await appointmentNotifier.cancelAppointment(
        studentNumber: widget.appointment.studentNumber,
        appointmentId: widget.appointment.appointmentId,
        teacherUid: widget.currentUser.uid,
        reason: reason,
      );
      
      if (success && mounted) {
        Navigator.pop(context); // Close modal
        _showSuccessMessage('Meeting has been cancelled.');
      } else if (mounted) {
        _showErrorMessage('Failed to cancel meeting. Please try again.');
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

  // Future<void> _handleCompleteMeeting() async {
  //   setState(() {
  //     _isResponding = true;
  //   });

  //   try {
  //     final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      
  //     final success = await appointmentNotifier.completeAppointment(
  //       studentNumber: widget.appointment.studentNumber,
  //       appointmentId: widget.appointment.appointmentId,
  //       teacherUid: widget.currentUser.uid,
  //     );
      
  //     if (success && mounted) {
  //       Navigator.pop(context); // Close modal
  //       _showSuccessMessage('Meeting has been completed successfully!');
  //     } else if (mounted) {
  //       _showErrorMessage('Failed to complete meeting. Please try again.');
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       _showErrorMessage('An error occurred: ${e.toString()}');
  //     }
  //   } finally {
  //     if (mounted) {
  //       setState(() {
  //         _isResponding = false;
  //       });
  //     }
  //   }
  // }

  // Handler for scheduled appointment accept
  Future<void> _handleScheduledAccept() async {
    final note = _noteController.text.trim();
    
    // Validate that note (location) is provided
    if (note.isEmpty) {
      setState(() {
        _hasNoteError = true;
      });
      return;
    }

     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
     print('🎯 TEACHER: Accepting scheduled appointment');
     print('   Student Number: ${widget.appointment.studentNumber}');
     print('   Appointment ID: ${widget.appointment.appointmentId}');
     print('   Teacher UID: ${widget.currentUser.uid}');
     print('   Teacher Note: $note');
     print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    setState(() {
      _isResponding = true;
    });

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      
      // Use the scheduled appointment response method
      final success = await appointmentNotifier.respondToScheduledAppointment(
        studentNumber: widget.appointment.studentNumber,
        appointmentId: widget.appointment.appointmentId,
        teacherUid: widget.currentUser.uid,
        accept: true,
        teacherResponse: note, // This will be the location
      );

      print('🎯 TEACHER: Response sent - Success: $success');
      
      if (success && mounted) {
        Navigator.pop(context);
        _showSuccessMessage('Meeting accepted! Student has been notified of your location.');
      } else if (mounted) {
        _showErrorMessage('Failed to accept appointment. Please try again.');
      }
    } catch (e) {

      print('❌ TEACHER: Error accepting appointment: $e');

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

  // Handler for scheduled appointment reject
  Future<void> _handleScheduledReject() async {
    final reason = _noteController.text.trim();
    
    // Validate that reason is provided
    if (reason.isEmpty) {
      setState(() {
        _hasNoteError = true;
      });
      return;
    }
    
    setState(() {
      _isResponding = true;
    });

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      
      // Use the scheduled appointment response method
      final success = await appointmentNotifier.respondToScheduledAppointment(
        studentNumber: widget.appointment.studentNumber,
        appointmentId: widget.appointment.appointmentId,
        teacherUid: widget.currentUser.uid,
        accept: false,
        teacherResponse: reason, // This will be the rejection reason
      );
      
      if (success && mounted) {
        Navigator.pop(context);
        _showSuccessMessage('Appointment rejected. Student has been notified.');
      } else if (mounted) {
        _showErrorMessage('Failed to reject appointment. Please try again.');
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