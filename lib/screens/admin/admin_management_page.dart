// Complete admin_rfid_management_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knocksense/models/rfid_model.dart';
import 'package:knocksense/provider/nfc_provider.dart';
import 'package:knocksense/widgets/common/loading_widget.dart';

class AdminRFIDManagementPage extends ConsumerStatefulWidget {
  const AdminRFIDManagementPage({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminRFIDManagementPage> createState() => _AdminRFIDManagementPageState();
}

class _AdminRFIDManagementPageState extends ConsumerState<AdminRFIDManagementPage> {
  final TextEditingController _manualUidController = TextEditingController();
  bool _showManualInput = false;

  @override
  void dispose() {
    _manualUidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nfcAvailability = ref.watch(nfcAvailabilityProvider);
    final rfidTags = ref.watch(rfidTagsStreamProvider);
    final scanningState = ref.watch(nfcScanningProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('RFID Management'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          // NFC Scanner Section
          _buildNFCScannerSection(context, nfcAvailability, scanningState),
          
          // RFID Tags List
          Expanded(
            child: rfidTags.when(
              data: (tags) => _buildRfidTagsList(tags),
              loading: () => const LoadingWidget(message: 'Loading RFID tags...'),
              error: (err, stack) => Center(
                child: Text('Error loading tags: $err'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNFCScannerSection(
    BuildContext context,
    AsyncValue<bool> nfcAvailability,
    NFCScanningState scanningState,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add New RFID Tag',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              // Toggle Manual Input Button
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showManualInput = !_showManualInput;
                    if (!_showManualInput) {
                      _manualUidController.clear();
                    }
                  });
                },
                icon: Icon(_showManualInput ? Icons.nfc : Icons.keyboard),
                label: Text(_showManualInput ? 'Use NFC' : 'Manual'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Show either NFC scanner or manual input
          if (_showManualInput) ...[
            _buildManualInputSection(),
          ] else ...[
            nfcAvailability.when(
              data: (isAvailable) {
                if (!isAvailable) {
                  return _buildNFCNotAvailable();
                }
                return _buildNFCScanner(scanningState);
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (err, stack) => Text(
                'Error checking NFC: $err',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],

          // Error Message Display
          if (scanningState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
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
                      scanningState.errorMessage!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(nfcScanningProvider.notifier).clearError();
                    },
                    color: Colors.red.shade700,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualInputSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _manualUidController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Enter RFID UID',
            hintText: 'e.g., A2:7A:B5:AB or 22:0C:10:01:02:03:04',
            prefixIcon: const Icon(Icons.credit_card),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f:]')),
            TextInputFormatter.withFunction((oldValue, newValue) {
              // Auto-format with colons
              String text = newValue.text.toUpperCase().replaceAll(':', '');
              if (text.length <= 2) return newValue.copyWith(text: text);
              
              List<String> pairs = [];
              for (int i = 0; i < text.length; i += 2) {
                if (i + 2 <= text.length) {
                  pairs.add(text.substring(i, i + 2));
                } else {
                  pairs.add(text.substring(i));
                }
              }
              
              return newValue.copyWith(
                text: pairs.join(':'),
                selection: TextSelection.collapsed(offset: pairs.join(':').length),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _addManualUid,
          icon: const Icon(Icons.add),
          label: const Text('Add RFID Tag'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Future<void> _addManualUid() async {
    final uid = _manualUidController.text.trim();
    
    // Validate UID format
    if (uid.isEmpty) {
      _showSnackBar('Please enter a UID', isError: true);
      return;
    }

    final uidParts = uid.split(':');
    if (uidParts.length != 4 && uidParts.length != 7) {
      _showSnackBar('Invalid UID length. Must be 4 or 7 bytes.', isError: true);
      return;
    }

    // Validate hex format
    for (final part in uidParts) {
      if (part.length != 2 || !RegExp(r'^[0-9A-F]{2}$').hasMatch(part)) {
        _showSnackBar('Invalid UID format. Each byte must be 2 hex characters.', isError: true);
        return;
      }
    }

    try {
      final nfcService = ref.read(nfcServiceProvider);
      await nfcService.addRfidTag(uid);
      _manualUidController.clear();
      _showSnackBar('RFID tag added successfully!');
      setState(() {
        _showManualInput = false;
      });
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Widget _buildNFCNotAvailable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.nfc_outlined, color: Colors.orange.shade700, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NFC Not Available',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'NFC is not available on this device. Use manual input instead.',
                  style: TextStyle(color: Colors.orange.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNFCScanner(NFCScanningState scanningState) {
    return Column(
      children: [
        // Scanning Animation and Status
        Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: scanningState.isScanning
                  ? [Colors.blue.shade50, Colors.blue.shade100]
                  : [Colors.grey.shade50, Colors.grey.shade100],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (scanningState.isScanning) ...[
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 12),
                  const Text('Hold NFC tag near device...'),
                ] else if (scanningState.lastScannedUid != null) ...[
                  Icon(Icons.check_circle, color: Colors.green, size: 48),
                  const SizedBox(height: 8),
                  Text(
                    'Scanned: ${scanningState.lastScannedUid}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ] else ...[
                  Icon(Icons.nfc, color: Colors.grey.shade400, size: 48),
                  const SizedBox(height: 8),
                  const Text('Tap to start scanning'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Control Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: scanningState.isScanning || scanningState.isProcessing
                    ? null
                    : () async {
                        await ref.read(nfcScanningProvider.notifier).startScanning();
                      },
                icon: const Icon(Icons.nfc),
                label: Text(scanningState.isScanning ? 'Scanning...' : 'Start Scan'),
              ),
            ),
            if (scanningState.isScanning) ...[
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(nfcScanningProvider.notifier).stopScanning();
                  },
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
            if (scanningState.lastScannedUid != null && !scanningState.isScanning) ...[
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: scanningState.isProcessing
                      ? null
                      : () async {
                          await ref.read(nfcScanningProvider.notifier).addScannedTag();
                          _showSnackBar('RFID tag added successfully!');
                        },
                  icon: scanningState.isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: Text(scanningState.isProcessing ? 'Adding...' : 'Add Tag'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRfidTagsList(List<RFIDModel> tags) {
    if (tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No RFID tags registered',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: tag.status == Status.active
                  ? Colors.green.shade100
                  : Colors.grey.shade200,
              child: Icon(
                Icons.credit_card,
                color: tag.status == Status.active
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
            title: Text(
              tag.rfid_uid,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: tag.status == Status.active
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag.status.name.toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: tag.status == Status.active
                              ? Colors.green.shade700
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tag.assignedTo ?? 'Unassigned',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Created: ${_formatTimestamp(tag.createdAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) => _handleTagAction(value, tag),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle_status',
                  child: ListTile(
                    leading: Icon(
                      tag.status == Status.active ? Icons.pause : Icons.play_arrow,
                      size: 20,
                    ),
                    title: Text(
                      tag.status == Status.active ? 'Deactivate' : 'Activate',
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'assign',
                  child: ListTile(
                    leading: Icon(Icons.person_add, size: 20),
                    title: Text('Assign to User'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: 'copy',
                  child: ListTile(
                    leading: Icon(Icons.copy, size: 20),
                    title: Text('Copy UID'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete, size: 20, color: Colors.red.shade700),
                    title: Text(
                      'Delete',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTagAction(String action, RFIDModel tag) async {
    switch (action) {
      case 'toggle_status':
        await _toggleTagStatus(tag);
        break;
      case 'assign':
        await _showAssignDialog(tag);
        break;
      case 'copy':
        await _copyUidToClipboard(tag.rfid_uid);
        break;
      case 'delete':
        await _showDeleteConfirmation(tag);
        break;
    }
  }

  Future<void> _toggleTagStatus(RFIDModel tag) async {
    try {
      final newStatus = tag.status == Status.active ? Status.inactive : Status.active;
      final nfcService = ref.read(nfcServiceProvider);
      await nfcService.updateRfidStatus(tag.rfid_uid, newStatus);
      _showSnackBar('Tag status updated successfully!');
    } catch (e) {
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _showAssignDialog(RFIDModel tag) async {
    final TextEditingController assignController = TextEditingController(
      text: tag.assignedTo ?? '',
    );

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Assign Tag to User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('UID: ${tag.rfid_uid}'),
              const SizedBox(height: 16),
              TextField(
                controller: assignController,
                decoration: const InputDecoration(
                  labelText: 'User Name/ID',
                  hintText: 'Enter user name or ID',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Assign'),
              onPressed: () async {
                final assignedTo = assignController.text.trim();
                if (assignedTo.isNotEmpty) {
                  try {
                    // You'll need to implement this method in your NFC service
                    // await nfcService.assignRfidTag(tag.rfid_uid, assignedTo);
                    _showSnackBar('Tag assigned successfully!');
                    Navigator.of(context).pop();
                  } catch (e) {
                    _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
                  }
                } else {
                  _showSnackBar('Please enter a user name or ID', isError: true);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _copyUidToClipboard(String uid) async {
    await Clipboard.setData(ClipboardData(text: uid));
    _showSnackBar('UID copied to clipboard');
  }

  Future<void> _showDeleteConfirmation(RFIDModel tag) async {
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
                  _showSnackBar('RFID tag deleted successfully!');
                  Navigator.of(context).pop();
                } catch (e) {
                  _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
                }
              },
            ),
          ],
        );
      },
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    
    try {
      // Handle ServerValue.timestamp or actual timestamp
      if (timestamp is Map && timestamp.containsKey('.sv')) {
        return 'Just now';
      }
      
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return '${date.day}/${date.month}/${date.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
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