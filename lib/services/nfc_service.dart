// nfc_service.dart
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:knocksense/models/rfid_model.dart';

class NFCService {
  final FirebaseDatabase _database;
  
  NFCService({required FirebaseDatabase database}) : _database = database;

  // Check if NFC is available
  Future<bool> isNFCAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (e) {
      debugPrint('Error checking NFC availability: $e');
      return false;
    }
  }

  // Convert byte array to formatted UID string (matches ESP32 format)
  String bytesToUidString(List<int> bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  // Check if RFID UID already exists in database
  Future<bool> checkUidExists(String uid) async {
    try {
      final snapshot = await _database.ref('rfid_tags/$uid').get();
      return snapshot.exists;
    } catch (e) {
      debugPrint('Error checking UID existence: $e');
      throw Exception('Failed to check UID in database');
    }
  }

  // Add new RFID tag to database
  Future<void> addRfidTag(String uid) async {
    try {
      // Check if already exists
      if (await checkUidExists(uid)) {
        throw Exception('This RFID UID already exists in the database');
      }

      // Create new RFID model
      final rfidModel = RFIDModel(
        rfid_uid: uid,
        status: Status.inactive, // Default to inactive for new tags
        assignedTo: null,
        createdAt: ServerValue.timestamp,
      );

      // Add to database
      await _database.ref('rfid_tags/$uid').set(rfidModel.toJson());
      debugPrint('Successfully added RFID UID: $uid');
    } catch (e) {
      debugPrint('Error adding RFID tag: $e');
      rethrow;
    }
  }

  // Start NFC scanning session
  Future<String?> startNFCScanning({
  required Function(String) onTagDiscovered,
  required Function(String) onError,
}) async {
  try {
    if (!await isNFCAvailable()) {
      onError('NFC is not available on this device.');
      return null;
    }

    String? scannedUid;

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443},
      onDiscovered: (NfcTag tag) async {
        try {
            final dynamic tagData = tag.data;
            final List<int>? identifier = tagData.id as List<int>?;

          if (identifier == null) {
            stopNFCScanning();
            onError('Could not find a UID in the tag data.');
            return;
          }

         
          final String uid = bytesToUidString(identifier);
          debugPrint('Discovered tag with UID: $uid');
          onTagDiscovered(uid);
          stopNFCScanning();


        } catch (e) {
          stopNFCScanning();
          onError('Error processing NFC tag: $e');
          
        }
      },
      onSessionErrorIos: (error) {
        // Handle iOS-specific session errors.
        onError('NFC Session Error (iOS): ${error.message}');
      },
    );

    return scannedUid;
  } catch (e) {
    onError('Failed to start NFC session: $e');
    return null;
  }
}

  // Stop NFC scanning session
  Future<void> stopNFCScanning() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (e) {
      debugPrint('Error stopping NFC session: $e');
    }
  }

  // Get all RFID tags from database
  Stream<List<RFIDModel>> getRfidTagsStream() {
    return _database.ref('rfid_tags').onValue.map((event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final tagsMap = Map<String, dynamic>.from(event.snapshot.value as Map);
        return tagsMap.entries.map((entry) {
          final tagData = Map<String, dynamic>.from(entry.value as Map);
          tagData['rfid_uid'] = entry.key; // Add the UID key to the data
          return RFIDModel.fromJson(tagData);
        }).toList();
      }
      return [];
    });
  }

  // Delete RFID tag from database
  Future<void> deleteRfidTag(String uid) async {
    try {
      await _database.ref('rfid_tags/$uid').remove();
      debugPrint('Successfully deleted RFID UID: $uid');
    } catch (e) {
      debugPrint('Error deleting RFID tag: $e');
      throw Exception('Failed to delete RFID tag');
    }
  }

  // Update RFID tag status
  Future<void> updateRfidStatus(String uid, Status status) async {
    try {
      await _database.ref('rfid_tags/$uid/status').set(status.name);
      debugPrint('Successfully updated RFID UID $uid status to ${status.name}');
    } catch (e) {
      debugPrint('Error updating RFID status: $e');
      throw Exception('Failed to update RFID status');
    }
  }

Future<void> assignRfidTag(String uid, String teacherID) async {
  try {
    // Verify the teacher exists
    final teacherSnapshot = await _database
        .ref('roles/teacher')
        .orderByChild('teacherID')
        .equalTo(teacherID)
        .get();
    
    if (!teacherSnapshot.exists) {
      throw Exception('Teacher with ID $teacherID not found');
    }

    // Check if the RFID tag exists
    final tagSnapshot = await _database.ref('rfid_tags/$uid').get();
    if (!tagSnapshot.exists) {
      throw Exception('RFID tag not found');
    }

    // Update the RFID tag with the teacher assignment
    await _database.ref('rfid_tags/$uid/assignedTo').set(teacherID);
    
    // Also update the teacher's role data with the RFID UID
    final teacherData = Map<String, dynamic>.from(teacherSnapshot.children.first.value as Map);
    final teacherUID = teacherSnapshot.children.first.key!;
    
    await _database.ref('roles/teacher/$teacherUID/rfid_uid').set(uid);
    
    debugPrint('Successfully assigned RFID UID: $uid to teacher: $teacherID');
  } catch (e) {
    debugPrint('Error assigning RFID tag: $e');
    rethrow;
  }
}

// Add this method to get all teachers for the dropdown
Future<List<Map<String, dynamic>>> getAllTeachers() async {
  try {
    final snapshot = await _database.ref('roles/teacher').get();
    
    if (!snapshot.exists) {
      return [];
    }
    
    final teachersMap = Map<String, dynamic>.from(snapshot.value as Map);
    return teachersMap.entries.map((entry) {
      final teacherData = Map<String, dynamic>.from(entry.value as Map);
      teacherData['uid'] = entry.key; // Add the UID for reference
      return teacherData;
    }).toList();
  } catch (e) {
    debugPrint('Error getting teachers: $e');
    throw Exception('Failed to fetch teachers');
  }
}

Future<void> unassignRfidTag(String uid) async {
  try {
    // Get current assignment
    final tagSnapshot = await _database.ref('rfid_tags/$uid').get();
    if (!tagSnapshot.exists) {
      throw Exception('RFID tag not found');
    }
    
    final tagData = Map<String, dynamic>.from(tagSnapshot.value as Map);
    final currentAssignment = tagData['assignedTo'] as String?;
    
    if (currentAssignment != null) {
      // Find and update the teacher's role data
      final teacherSnapshot = await _database
          .ref('roles/teacher')
          .orderByChild('teacherID')
          .equalTo(currentAssignment)
          .get();
      
      if (teacherSnapshot.exists) {
        final teacherUID = teacherSnapshot.children.first.key!;
        await _database.ref('roles/teacher/$teacherUID/rfid_uid').remove();
      }
    }
    
    // Remove assignment from RFID tag
    await _database.ref('rfid_tags/$uid/assignedTo').remove();
    
    debugPrint('Successfully unassigned RFID UID: $uid');
  } catch (e) {
    debugPrint('Error unassigning RFID tag: $e');
    rethrow;
  }
}

}

