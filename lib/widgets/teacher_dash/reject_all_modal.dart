// lib/widgets/teacher_dash/reject_all_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/appointment_model.dart';
import 'package:knocksense/provider/appointment_provider.dart';

class RejectAllModal extends ConsumerStatefulWidget {
  final String teacherUid;
  final List<AppointmentModel> appointmentsToReject;

  const RejectAllModal({
    Key? key,
    required this.teacherUid,
    required this.appointmentsToReject,
  }) : super(key: key);

  @override
  ConsumerState<RejectAllModal> createState() => _RejectAllModalState();
}

class _RejectAllModalState extends ConsumerState<RejectAllModal> {
  final TextEditingController _reasonController = TextEditingController();
  bool _isRejecting = false;
  bool _hasError = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _clearReasonError() {
    if (_hasError) {
      setState(() {
        _hasError = false;
      });
    }
  }

  Future<void> _handleRejectAll() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _hasError = true);
      return;
    }

    setState(() => _isRejecting = true);

    try {
      final appointmentNotifier = ref.read(appointmentNotifierProvider.notifier);
      
      // Create a list of futures for each cancellation
      final List<Future<bool>> rejectionFutures = widget.appointmentsToReject
          .map((appointment) => appointmentNotifier.cancelAppointment(
                studentNumber: appointment.studentNumber,
                appointmentId: appointment.appointmentId,
                teacherUid: widget.teacherUid,
                reason: reason,
              ))
          .toList();

      // Wait for all rejections to complete
      final results = await Future.wait(rejectionFutures);
      final allSucceeded = results.every((success) => success);

      if (!mounted) return;

      Navigator.pop(context); // Close the modal
      if (allSucceeded) {
        _showStatusMessage(
          '${widget.appointmentsToReject.length} appointment(s) have been rejected.',
          isError: false,
        );
        Navigator.pop(context); 
      } else {
        _showStatusMessage('Failed to reject some appointments. Please check and try again.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        _showStatusMessage('An error occurred: ${e.toString()}', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isRejecting = false);
      }
    }
  }

  void _showStatusMessage(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String _getStudentNames() {
    if (widget.appointmentsToReject.isEmpty) return '';
    
    if (widget.appointmentsToReject.length == 1) {
      return widget.appointmentsToReject.first.studentName;
    } else if (widget.appointmentsToReject.length <= 3) {
      return widget.appointmentsToReject
          .map((appointment) => appointment.studentName.split(' ').first)
          .join(', ');
    } else {
      final firstTwo = widget.appointmentsToReject
          .take(2)
          .map((appointment) => appointment.studentName.split(' ').first)
          .join(', ');
      return '$firstTwo and ${widget.appointmentsToReject.length - 2} others';
    }
  }

  Widget _buildStudentAvatars() {
    final appointments = widget.appointmentsToReject.take(3).toList();
    
    if (appointments.length == 1) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: Colors.amber,
        child: appointments.first.studentPhotoUrl != null && 
               appointments.first.studentPhotoUrl!.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  appointments.first.studentPhotoUrl!,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Text(
                      _getInitials(appointments.first.studentName),
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    );
                  },
                ),
              )
            : Text(
                _getInitials(appointments.first.studentName),
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
      );
    }
    
    // Multiple avatars stacked
    return SizedBox(
      width: appointments.length == 2 ? 56 : 72,
      height: 48,
      child: Stack(
        children: appointments.asMap().entries.map((entry) {
          final index = entry.key;
          final appointment = entry.value;
          
          return Positioned(
            left: index * 16.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.primaries[index % Colors.primaries.length].shade300,
                child: appointment.studentPhotoUrl != null && 
                       appointment.studentPhotoUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          appointment.studentPhotoUrl!,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              _getInitials(appointment.studentName),
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        _getInitials(appointment.studentName),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          );
        }).toList(),
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

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFDF6E3),
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      _buildStudentAvatars(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStudentNames(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.appointmentsToReject.length} pending appointment${widget.appointmentsToReject.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Bulk Reject',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reject All Appointments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please provide a reason for rejecting all pending appointments. This reason will be sent to all students.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _reasonController,
                    onChanged: (_) => _clearReasonError(),
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g., "Emergency meeting", "Unavailable for today"',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _hasError ? Colors.red : Colors.grey[200]!,
                          width: _hasError ? 2 : 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _hasError ? Colors.red : Colors.grey[200]!,
                          width: _hasError ? 2 : 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _hasError ? Colors.red : Colors.deepPurple,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (_hasError) ...[
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'A reason is required.',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isRejecting ? null : _handleRejectAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          icon: _isRejecting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Icon(Icons.block, size: 20),
                          label: Text(
                            _isRejecting ? 'Rejecting...' : 'Reject All Appointments',
                            style: const TextStyle(
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
                          onPressed: _isRejecting ? null : () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey[600],
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Cancel',
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}