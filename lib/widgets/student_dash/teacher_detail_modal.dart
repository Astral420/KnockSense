// widgets/student_dash/teacher_detail_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:knocksense/models/teacher_model.dart';
import 'package:knocksense/models/user_models.dart';
import 'package:knocksense/provider/teacher_provider.dart';
import 'package:knocksense/provider/auth_provider.dart';
import 'package:knocksense/provider/appointment_provider.dart';
import 'package:knocksense/provider/teacher_service_provider.dart';
import 'package:knocksense/services/notification_service.dart';

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
  bool _isScheduling = false;
  Set<String> _notifiedTeachers = {};
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _showSchedulingOptions = false;
  String? _lastKnownStatus; // Track status changes
  String? _errorMessage; // NEW: Add error message state
  String? _infoMessage; // NEW: Add info message state

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Reset scheduling UI when teacher status changes
  void _checkStatusChange(String currentStatus) {
    if (_lastKnownStatus != null && _lastKnownStatus != currentStatus) {
      setState(() {
        _showSchedulingOptions = false;
        _selectedDate = null;
        _selectedTime = null;
        _errorMessage = null; // Clear errors when status changes
        _infoMessage = null;
      });
    }
    _lastKnownStatus = currentStatus;
  }

  // NEW: Method to clear messages after a delay
  void _clearMessagesAfterDelay() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _infoMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final teacherAsync = ref.watch(teacherByUidProvider(widget.teacher.uid));
    final currentUser = ref.watch(currentUserProvider);
    final hasPendingAppointment = ref.watch(
      hasPendingAppointmentProvider(widget.teacher.uid)
    );
    
    final statusWithDuration = ref.watch(
      teacherStatusWithDurationProvider(widget.teacher.uid)
    );
    
    return teacherAsync.when(
      data: (currentTeacher) {
        final teacher = currentTeacher ?? widget.teacher;
        
        // Check for status changes and reset UI if needed
        _checkStatusChange(teacher.activeStatus);
        
        return currentUser.when(
          data: (user) => _buildModalContent(
            teacher, 
            user, 
            hasPendingAppointment.value ?? false,
            statusWithDuration,
          ),
          loading: () => _buildModalContent(teacher, null, false, statusWithDuration),
          error: (_, __) => _buildModalContent(teacher, null, false, statusWithDuration),
        );
      },
      loading: () => _buildModalContent(widget.teacher, null, false, statusWithDuration),
      error: (_, __) => _buildModalContent(widget.teacher, null, false, statusWithDuration),
    );
  }

  Widget _buildModalContent(
    TeacherModel teacher, 
    UserModel? currentUser,
    bool hasPendingAppointment,
    AsyncValue statusWithDuration,
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
                // Teacher profile section with duration
                _buildTeacherProfileSection(teacher, statusWithDuration),
                
                const SizedBox(height: 24),
                
                // Status notifications
                ..._buildStatusNotifications(teacher, hasPendingAppointment),
                
                // NEW: Error and Info Messages Display
                if (_errorMessage != null) ...[
                  _buildErrorMessage(_errorMessage!),
                  const SizedBox(height: 16),
                ],
                if (_infoMessage != null) ...[
                  _buildInfoMessage(_infoMessage!),
                  const SizedBox(height: 16),
                ],
                
                // Teacher message if available
                if (teacher.teacherMsg != null && teacher.teacherMsg!.isNotEmpty) ...[
                  _buildTeacherMessage(teacher.teacherMsg!),
                  const SizedBox(height: 20),
                ],
                
                // Note input field
                _buildNoteInputField(),
                
                // Date/Time selection (show when scheduling)
                if (_showSchedulingOptions) ...[
                  const SizedBox(height: 20),
                  _buildDateTimeSelection(),
                ],
                
                const SizedBox(height: 24),
                
                // Action buttons
                _buildActionButtons(teacher, currentUser, hasPendingAppointment),
                
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: Build error message widget
  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error',
                  style: TextStyle(
                    color: Colors.red[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.red[600]),
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // NEW: Build info message widget
  Widget _buildInfoMessage(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Success',
                  style: TextStyle(
                    color: Colors.green[800],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18, color: Colors.green[600]),
            onPressed: () {
              setState(() {
                _infoMessage = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTeacherProfileSection(TeacherModel teacher, AsyncValue statusWithDuration) {
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
              // Enhanced status display with duration
              statusWithDuration.when(
                data: (statusData) {
                  return Row(
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
                          statusData != null 
                              ? '${_formatStatus(teacher.activeStatus)} for ${statusData.duration}'
                              : _formatStatus(teacher.activeStatus),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStatusColor(teacher.activeStatus),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Row(
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
                error: (_, __) => Row(
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
                      'You already have a pending appointment with this teacher.',
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

  Widget _buildDateTimeSelection() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.purple.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: Colors.purple.withOpacity(0.3),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule Appointment',
          style: TextStyle(
            color: Colors.purple[800],
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        
        // Date selection
        Row(
          children: [
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    debugPrint('📅 Date button tapped');
                    _selectDate(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDate != null
                              ? '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}'
                              : 'Select Date',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedDate != null ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Time selection
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    debugPrint('⏰ Time button tapped');
                    _selectTime(context);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          _selectedTime != null
                              ? _selectedTime!.format(context)
                              : 'Select Time',
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedTime != null ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildActionButtons(TeacherModel teacher, UserModel? currentUser, bool hasPendingAppointment) {
    final bool canSchedule = !_isScheduling && 
                           !hasPendingAppointment && 
                           currentUser != null;
    
    final bool isOnline = teacher.activeStatus.toLowerCase() == 'online';

    return Column(
      children: [
        // FIXED: Separate Schedule Appointment button (full width)
        if (!isOnline && !_showSchedulingOptions) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canSchedule
                  ? () {
                      setState(() {
                        _showSchedulingOptions = true;
                        _errorMessage = null; // Clear any existing errors
                        _infoMessage = null;
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9C27B0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
              ),
              icon: const Icon(Icons.schedule),
              label: const Text(
                'Schedule Appointment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12), // Space between schedule and notify buttons
        ],
        
        // Confirm/Cancel buttons when scheduling
        if (_showSchedulingOptions) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: (_selectedDate != null && _selectedTime != null && canSchedule)
                      ? () => _handleScheduleAppointment(teacher, currentUser!)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                  child: _isScheduling
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Confirm Schedule',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _showSchedulingOptions = false;
                      _selectedDate = null;
                      _selectedTime = null;
                      _errorMessage = null; // Clear errors when canceling
                      _infoMessage = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    side: BorderSide(color: Colors.grey[400]!),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        
        // FIXED: Bottom section with Knock Now (if online) and separate Notify Me
        Row(
          children: [
            // Knock Now button (only for online teachers)
            if (isOnline) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: canSchedule
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
                    elevation: canSchedule ? 2 : 0,
                  ),
                  icon: _isScheduling
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
                    _isScheduling ? 'Sending...' : 'Knock Now',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            
            // Notify Me button (always show, full width if no Knock Now)
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
        ),
      ],
    );
  }

bool _validateScheduledTime(DateTime scheduledDateTime, AsyncValue statusWithDuration) {
  final now = DateTime.now();
  
  // Check if in the past
  if (scheduledDateTime.isBefore(now)) {
    debugPrint('❌ Validation failed: Time is in the past');
    return false;
  }
  
  // Check against status change time
  final statusData = statusWithDuration.valueOrNull;
  if (statusData?.changedAt != null) {
    if (scheduledDateTime.isBefore(statusData!.changedAt!)) {
      debugPrint('❌ Validation failed: Before status change time');
      return false;
    }
  }
  
  debugPrint('✅ Validation passed');
  return true;
}

// Updated _selectDate method with status change validation
Future<void> _selectDate(BuildContext context) async {
  final now = DateTime.now();
  final weekFromNow = now.add(const Duration(days: 7));
  
  // Get the status data
  final statusWithDuration = ref.read(
    teacherStatusWithDurationProvider(widget.teacher.uid)
  );
  
  final statusData = statusWithDuration.valueOrNull;
  
  // Determine the first selectable date
  DateTime firstSelectableDate = now;
  
  if (statusData != null && statusData.changedAt != null) {
    if (statusData.changedAt!.isAfter(now)) {
      firstSelectableDate = statusData.changedAt!;
    }
  }
  
  // CRITICAL FIX: Find the next valid date (skip Sundays)
  DateTime getNextSelectableDate(DateTime date) {
    DateTime candidate = date;
    while (candidate.weekday == DateTime.sunday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }
  
  // Ensure initialDate is not a Sunday
  final initialDate = _selectedDate ?? getNextSelectableDate(firstSelectableDate);
  
  debugPrint('📅 Opening date picker - First selectable: $firstSelectableDate');
  debugPrint('📅 Initial date: $initialDate');
  
  try {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstSelectableDate,
      lastDate: weekFromNow,
      selectableDayPredicate: (DateTime day) {
        // Exclude Sundays
        if (day.weekday == DateTime.sunday) {
          return false;
        }
        
        // Create date without time for comparison
        final checkDate = DateTime(day.year, day.month, day.day);
        final todayDate = DateTime(now.year, now.month, now.day);
        
        // Allow today and future dates
        return checkDate.isAtSameMomentAs(todayDate) || checkDate.isAfter(todayDate);
      },
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9C27B0),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      debugPrint('✅ Date selected: $picked');
      setState(() {
        _selectedDate = picked;
        _selectedTime = null;
        _errorMessage = null;
      });
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Error showing date picker: $e');
    if (mounted) {
      setState(() {
        _errorMessage = 'Failed to open date picker. Please try again.';
      });
      _clearMessagesAfterDelay();
    }
  }
}

// FIXED: Simplified _selectTime method
Future<void> _selectTime(BuildContext context) async {
  if (_selectedDate == null) {
    setState(() {
      _errorMessage = 'Please select a date first';
    });
    _clearMessagesAfterDelay();
    return;
  }
  
  debugPrint('⏰ Opening time picker');
  
  try {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF9C27B0),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child!,
          ),
        );
      },
    );

    if (picked != null) {
      debugPrint('⏰ Time selected: ${picked.format(context)}');
      
      // Validate time constraints
      if (picked.hour < 6 || (picked.hour == 6 && picked.minute < 30)) {
        setState(() {
          _errorMessage = 'Appointments cannot be scheduled before 6:30 AM. Please select a later time.';
        });
        _clearMessagesAfterDelay();
        return;
      }
      
      if (picked.hour > 18 || (picked.hour == 18 && picked.minute > 0)) {
        setState(() {
          _errorMessage = 'Appointments can only be scheduled until 6:00 PM. Please select an earlier time.';
        });
        _clearMessagesAfterDelay();
        return;
      }
      
      // Create the full scheduled DateTime
      final scheduledDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        picked.hour,
        picked.minute,
      );
      
      // Validate against current time
      final now = DateTime.now();
      if (scheduledDateTime.isBefore(now)) {
        setState(() {
          _errorMessage = 'Cannot schedule appointments in the past. Please select a future time.';
        });
        _clearMessagesAfterDelay();
        return;
      }
      
      // Get status data for additional validation
      final statusWithDuration = ref.read(
        teacherStatusWithDurationProvider(widget.teacher.uid)
      );
      
      final statusData = statusWithDuration.valueOrNull;
      if (statusData?.changedAt != null && scheduledDateTime.isBefore(statusData!.changedAt!)) {
        setState(() {
          _errorMessage = 'Cannot schedule before teacher\'s last status update at ${_formatTimeForDisplay(statusData.changedAt!)}.';
        });
        _clearMessagesAfterDelay();
        return;
      }
      
      // All validations passed
      setState(() {
        _selectedTime = picked;
        _errorMessage = null;
      });
      debugPrint('✅ Time validated and set: ${picked.format(context)}');
    } else {
      debugPrint('❌ Time picker cancelled');
    }
  } catch (e) {
    debugPrint('❌ Error showing time picker: $e');
    setState(() {
      _errorMessage = 'Failed to open time picker. Please try again.';
    });
    _clearMessagesAfterDelay();
  }
}

// Helper method to format time for display
String _formatTimeForDisplay(DateTime dateTime) {
  final hour = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  return '$displayHour:$minute $period';
}

// Updated _handleScheduleAppointment with additional validation
Future<void> _handleScheduleAppointment(TeacherModel teacher, UserModel currentUser) async {
  if (currentUser.studentNumber == null) {
    setState(() {
      _errorMessage = 'Student information not found. Please contact support.';
    });
    _clearMessagesAfterDelay();
    return;
  }

  if (_selectedDate == null || _selectedTime == null) {
    setState(() {
      _errorMessage = 'Please select both date and time.';
    });
    _clearMessagesAfterDelay();
    return;
  }

  setState(() {
    _isScheduling = true;
    _errorMessage = null;
    _infoMessage = null;
  });

  try {
    // Combine date and time
    final scheduledDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    
    // Final validation before submitting
    final statusWithDuration = ref.read(
      teacherStatusWithDurationProvider(teacher.uid)
    );
    
    if (!_validateScheduledTime(scheduledDateTime, statusWithDuration)) {
      setState(() {
        _errorMessage = 'Invalid appointment time. Please select a valid future time.';
        _isScheduling = false;
      });
      _clearMessagesAfterDelay();
      return;
    }
    
    // Additional validation: Check if appointment is after 6 PM (defensive check)
    if (scheduledDateTime.hour > 18 || 
        (scheduledDateTime.hour == 18 && scheduledDateTime.minute > 0)) {
      setState(() {
        _errorMessage = 'Appointments cannot be scheduled after 6:00 PM.';
        _isScheduling = false;
      });
      _clearMessagesAfterDelay();
      return;
    }
    
    final appointmentService = ref.read(appointmentServiceProvider);
    final note = _noteController.text.trim();
    
    final result = await appointmentService.createAppointment(
      student: currentUser,
      teacher: teacher,
      studentNote: note.isNotEmpty ? note : null,
      scheduledTime: scheduledDateTime,
      isScheduled: true,
    );
    
    if (result['success'] == true) {
      ref.invalidate(hasPendingAppointmentProvider(teacher.uid));
      Navigator.pop(context);
      _showSuccessMessage(
        'Appointment scheduled with ${teacher.displayName} for '
        '${_selectedTime!.format(context)} on ${_selectedDate!.month}/${_selectedDate!.day}'
      );
    } else {
      setState(() {
        _errorMessage = result['error'] ?? 'Failed to schedule appointment. Please try again.';
      });
      _clearMessagesAfterDelay();
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'An error occurred: ${e.toString()}';
    });
    _clearMessagesAfterDelay();
  } finally {
    if (mounted) {
      setState(() {
        _isScheduling = false;
      });
    }
  }
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
      setState(() {
        _errorMessage = 'Student information not found. Please contact support.';
      });
      _clearMessagesAfterDelay();
      return;
    }

    setState(() {
      _isScheduling = true;
      _errorMessage = null;
      _infoMessage = null;
    });

    try {
      final appointmentService = ref.read(appointmentServiceProvider);
      final note = _noteController.text.trim();
      
      final result = await appointmentService.createAppointment(
        student: currentUser,
        teacher: teacher,
        studentNote: note.isNotEmpty ? note : null,
        isScheduled: false, // Immediate appointment
      );
      
      if (result['success'] == true) {
        ref.invalidate(hasPendingAppointmentProvider(teacher.uid));
        Navigator.pop(context);
        _showSuccessMessage('Appointment request sent to ${teacher.displayName}');
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Failed to send appointment request. Please try again.';
        });
        _clearMessagesAfterDelay();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
      _clearMessagesAfterDelay();
    } finally {
      if (mounted) {
        setState(() {
          _isScheduling = false;
        });
      }
    }
  }

  void _handleNotifyMe(TeacherModel teacher) async {
  final currentUser = ref.read(currentUserProvider).value;
  if (currentUser == null) return;
  
  final notificationService = NotificationService();
  
  setState(() {
    if (_notifiedTeachers.contains(teacher.uid)) {
      _notifiedTeachers.remove(teacher.uid);
      notificationService.unsubscribeFromTeacher(teacher.uid, currentUser.uid);
      print('📕 Student unsubscribed from notifications for ${teacher.displayName}');
      _infoMessage = 'Notifications disabled for ${teacher.displayName}';
    } else {
      _notifiedTeachers.add(teacher.uid);
      notificationService.subscribeToTeacher(teacher.uid, currentUser.uid);
      print('🔔 Student subscribed to notifications for ${teacher.displayName}');
      _infoMessage = 'You\'ll be notified when ${teacher.displayName} becomes available';
    }
  });
  _clearMessagesAfterDelay();
}

@override
void initState() {
  super.initState();
  _loadNotificationSubscriptions();
}

void _loadNotificationSubscriptions() async {
  final currentUser = ref.read(currentUserProvider).value;
  if (currentUser != null) {
    final notificationService = NotificationService();
    await notificationService.loadSubscriptions(currentUser.uid);
    
    // Update UI to reflect subscribed teachers
    if (notificationService.isSubscribedToTeacher(widget.teacher.uid)) {
      setState(() {
        _notifiedTeachers.add(widget.teacher.uid);
      });
    }
  }
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