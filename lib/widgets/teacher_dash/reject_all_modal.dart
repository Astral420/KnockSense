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
        // Optionally, pop the recent knocks screen as well
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const Text(
            'Reject All Appointments',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please provide a reason for rejecting all pending appointments. This reason will be sent to all students.',
            style: TextStyle(fontSize: 15, color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _reasonController,
            onChanged: (_) {
              if (_hasError) setState(() => _hasError = false);
            },
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., "Emergency meeting", "Unavailable for today"',
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _hasError ? Colors.red : Colors.deepPurple,
                  width: 2,
                ),
              ),
              enabledBorder: _hasError
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.red, width: 1.5),
                    )
                  : null,
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_hasError) ...[
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text(
                'A reason is required.',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isRejecting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _isRejecting ? null : _handleRejectAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  label: Text(_isRejecting ? 'Rejecting...' : 'Reject All', style: const TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}