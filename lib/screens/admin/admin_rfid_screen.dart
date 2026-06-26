import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:knocksense/models/rfid_model.dart';
import 'package:knocksense/provider/nfc_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminRfidScreen extends ConsumerWidget {
  const AdminRfidScreen({Key? key}) : super(key: key);

  // Design system colors
  static const Color kBg = Color(0xFFF7F8FB);
  static const Color kSurface = Color(0xFFFFFFFF);
  static const Color kText = Color(0xFF111827);
  static const Color kMuted = Color(0xFF888888);
  static const Color kYellow = Color(0xFFFACC15);
  static const Color kGreen = Color(0xFF16A34A);
  static const Color kRed = Color(0xFFDC2626);
  static const Color kBorder = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nfcAvailability = ref.watch(nfcAvailabilityProvider);
    final rfidTags = ref.watch(rfidTagsStreamProvider);
    final scanningState = ref.watch(nfcScanningProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // NFC Scanner Card
              _buildNFCScannerCard(context, ref, nfcAvailability, scanningState),
              const SizedBox(height: 12),

              // RFID Tags List
              _buildRfidTagsList(context, ref, rfidTags),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: kSurface,
      elevation: 0.5,
      title: Text(
        'RFID Management',
        style: GoogleFonts.roboto(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: kText,
        ),
      ),
    );
  }

  Widget _buildNFCScannerCard(BuildContext context, WidgetRef ref, 
      AsyncValue<bool> nfcAvailability, NFCScanningState scanningState) {
    return Card(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Add New RFID Tag",
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: kText,
              ),
            ),
            const SizedBox(height: 12),

            // Scanning Area
            nfcAvailability.when(
              data: (isAvailable) {
                if (!isAvailable) {
                  return _buildNFCNotAvailable();
                }
                return _buildNFCScanner(context, ref, scanningState);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => _buildErrorContainer('Error checking NFC: $err'),
            ),

            // Error Message Display
            if (scanningState.errorMessage != null) ...[
              const SizedBox(height: 12),
              _buildErrorContainer(scanningState.errorMessage!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNFCNotAvailable() {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200, width: 1),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.nfc_outlined, color: Colors.orange.shade700, size: 40),
            const SizedBox(height: 8),
            Text(
              "NFC Not Available",
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "NFC is not available on this device",
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: Colors.orange.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNFCScanner(BuildContext context, WidgetRef ref, NFCScanningState scanningState) {
    return Column(
      children: [
        // Tappable scan area
        GestureDetector(
          onTap: scanningState.isScanning ? null : () async {
            await ref.read(nfcScanningProvider.notifier).startScanning();
          },
          child: Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(
              color: scanningState.isScanning
                  ? const Color(0xFFE3F2FD)
                  : const Color(0xFFFFF3CD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: scanningState.isScanning
                    ? Colors.blue.shade200
                    : const Color(0xFFFFE082),
                width: 1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scanningState.isScanning) ...[
                    const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Hold NFC tag near device...",
                      style: GoogleFonts.roboto(color: kText),
                    ),
                  ] else if (scanningState.lastScannedUid != null) ...[
                    Icon(Icons.check_circle, color: kGreen, size: 40),
                    const SizedBox(height: 8),
                    Text(
                      "Scanned: ${scanningState.lastScannedUid}",
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.bold,
                        color: kText,
                      ),
                    ),
                  ] else ...[
                    SvgPicture.asset(
                      'assets/icons/scan.svg',
                      width: 40,
                      height: 40,
                      semanticsLabel: 'Scan',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Tap to start scanning",
                      style: GoogleFonts.roboto(color: kText),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Control Buttons
        if (scanningState.isScanning) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: kRed,
                side: BorderSide(color: kRed),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () async {
                await ref.read(nfcScanningProvider.notifier).stopScanning();
              },
              icon: SvgPicture.asset(
                'assets/icons/stop.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(kRed, BlendMode.srcIn),
              ),
              label: Text(
                "Stop Scan",
                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ] else if (scanningState.lastScannedUid != null) ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: kGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: scanningState.isProcessing ? null : () async {
                      final bool success = await ref
                      .read(nfcScanningProvider.notifier)
                      .addScannedTag();

                  // ✅ Only show snackbar if the operation was successful
                  if (success && context.mounted) {
                    _showSnackBar(context, 'RFID tag added successfully!');
                  }
                    },
                    icon: scanningState.isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add),
                    label: Text(
                      scanningState.isProcessing ? 'Adding...' : 'Add Tag',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: kBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    onPressed: () async {
                      await ref.read(nfcScanningProvider.notifier).startScanning();
                    },
                    icon: SvgPicture.asset(
                      'assets/icons/scan.svg',
                      width: 20,
                      height: 20,
                    ),
                    label: Text(
                      "Scan Again",
                      style: GoogleFonts.roboto(
                        fontWeight: FontWeight.w600,
                        color: kText,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: kYellow,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: () async {
                await ref.read(nfcScanningProvider.notifier).startScanning();
              },
              icon: SvgPicture.asset(
                'assets/icons/start_scan.svg',
                width: 20,
                height: 20,
                semanticsLabel: 'Start Scan',
              ),
              label: Text(
                "Start Scan",
                style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildErrorContainer(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.roboto(
                color: Colors.red.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRfidTagsList(BuildContext context, WidgetRef ref, AsyncValue<List<RFIDModel>> rfidTags) {
    return rfidTags.when(
      data: (tags) {
        if (tags.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          children: tags.map((tag) => _buildRfidCard(context, ref, tag)).toList(),
        );
      },
      loading: () => const LoadingWidget(message: 'Loading RFID tags...'),
      error: (err, stack) => _buildErrorContainer('Error loading tags: $err'),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      color: kSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.credit_card_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No RFID tags registered',
              style: GoogleFonts.roboto(
                color: Colors.grey.shade600,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRfidCard(BuildContext context, WidgetRef ref, RFIDModel tag) {
    final statusColor = tag.status == Status.active ? kGreen : kRed;
    final statusText = tag.status == Status.active ? "Active" : "Inactive";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: RFID + status
            Row(
              children: [
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.roboto(color: kText, fontSize: 16),
                      children: [
                        const TextSpan(
                          text: "RFID: ",
                          style: TextStyle(fontWeight: FontWeight.w400),
                        ),
                        TextSpan(
                          text: tag.rfid_uid,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  statusText,
                  style: GoogleFonts.roboto(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tag.assignedTo == null ? "Unassigned" : "Assigned to ${tag.assignedTo!}",
              style: GoogleFonts.roboto(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),

            // Bottom row: buttons + switch
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildActionButton(
                        label: "Assign RFID",
                        icon: 'assets/icons/id_card.svg',
                        onPressed: () => _showAssignDialog(context, ref, tag),
                      ),
                      _buildActionButton(
                        label: "Delete",
                        icon: 'assets/icons/trash.svg',
                        onPressed: () => _showDeleteDialog(context, ref, tag),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: tag.status == Status.active,
                  onChanged: (value) => _toggleTagStatus(ref, tag, value),
                  thumbColor: MaterialStateProperty.all(Colors.black),
                  trackColor: MaterialStateProperty.resolveWith((states) {
                    if (states.contains(MaterialState.selected)) return kYellow;
                    return Colors.grey.shade300;
                  }),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required String icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black87,
        side: const BorderSide(color: kBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      onPressed: onPressed,
      icon: SvgPicture.asset(icon, width: 18, height: 18),
      label: Text(
        label,
        style: GoogleFonts.roboto(fontWeight: FontWeight.w700),
      ),
    );
  }

  Future<void> _toggleTagStatus(WidgetRef ref, RFIDModel tag, bool isActive) async {
    try {
      final newStatus = isActive ? Status.active : Status.inactive;
      final nfcService = ref.read(nfcServiceProvider);
      await nfcService.updateRfidStatus(tag.rfid_uid, newStatus);
    } catch (e) {
      // Handle error - could add snackbar here if needed
    }
  }

  // Fixed method signature with proper parameters
  Future<void> _showAssignDialog(BuildContext context, WidgetRef ref, RFIDModel tag) async {
    List<Map<String, dynamic>> teachers = [];
    String? selectedTeacherID;
    bool isLoading = true;
    
    try {
      final nfcService = ref.read(nfcServiceProvider);
      teachers = await nfcService.getAllTeachers();
      isLoading = false;
      
      // Pre-select current assignment if exists
      if (tag.assignedTo != null) {
        final currentTeacher = teachers.firstWhere(
          (teacher) => teacher['teacherID'] == tag.assignedTo,
          orElse: () => {},
        );
        if (currentTeacher.isNotEmpty) {
          selectedTeacherID = tag.assignedTo;
        }
      }
    } catch (e) {
      _showSnackBar(context, 'Failed to load teachers: $e', isError: true);
      return;
    }

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Assign RFID to Teacher'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RFID UID: ${tag.rfid_uid}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (teachers.isEmpty)
                      const Text('No teachers found in the system.')
                    else ...[
                      const Text('Select Teacher:'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String?>(
                        value: selectedTeacherID,
                        isExpanded: true,
                        hint: const Text('Choose a teacher'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Unassign',
                              style: TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                          ...teachers.map((teacher) {
                            return DropdownMenuItem<String?>(
                              value: teacher['teacherID'] as String?,
                              child: Text(
                                teacher['displayName'] ?? 'Unknown Name',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (String? value) {
                          setState(() {
                            selectedTeacherID = value;
                          });
                        },
                      ),
                      if (tag.assignedTo != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Currently assigned to: ${tag.assignedTo}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  child: const Text('Assign'),
                  onPressed: teachers.isEmpty ? null : () async {
                    try {
                      final nfcService = ref.read(nfcServiceProvider);
                      
                      if (selectedTeacherID == null) {
                        // Unassign the RFID
                        await nfcService.unassignRfidTag(tag.rfid_uid);
                        _showSnackBar(context, 'RFID tag unassigned successfully!');
                      } else {
                        // Assign to selected teacher
                        await nfcService.assignRfidTag(tag.rfid_uid, selectedTeacherID!);
                        _showSnackBar(context, 'RFID tag assigned successfully!');
                      }
                      
                      Navigator.of(context).pop();
                    } catch (e) {
                      _showSnackBar(
                        context,
                        e.toString().replaceAll('Exception: ', ''), 
                        isError: true,
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Implemented the missing delete dialog method
  Future<void> _showDeleteDialog(BuildContext context, WidgetRef ref, RFIDModel tag) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete RFID Tag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to delete this RFID tag?'),
              const SizedBox(height: 8),
              Text(
                'UID: ${tag.rfid_uid}',
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This action cannot be undone.',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () async {
                try {
                  final nfcService = ref.read(nfcServiceProvider);
                  await nfcService.deleteRfidTag(tag.rfid_uid);
                  _showSnackBar(context, 'RFID tag deleted successfully!');
                  Navigator.of(context).pop();
                } catch (e) {
                  _showSnackBar(context, e.toString().replaceAll('Exception: ', ''), isError: true);
                }
              },
            ),
          ],
        );
      },
    );
  }

  // Added the missing _showSnackBar method
  void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        duration: Duration(seconds: isError ? 4 : 2),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
}