// nfc_service.dart
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:knocksense/models/rfid_model.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

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
            onError('Could not find a UID in the tag data.');
            return;
          }

         
          final String uid = bytesToUidString(identifier);
          debugPrint('Discovered tag with UID: $uid');
          onTagDiscovered(uid);
        } catch (e) {
          onError('Error processing NFC tag: $e');
        } finally {
          await NfcManager.instance.stopSession();
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
}