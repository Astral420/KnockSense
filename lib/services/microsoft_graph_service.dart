import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:microsoft_graph_api/microsoft_graph_api.dart';
import 'package:microsoft_graph_api/models/models.dart';



class GraphService {
  final FirebaseStorage _storage;
  
  // Cache to avoid re-fetching photos during the same session
  static final Map<String, String?> _photoUrlCache = {};

  GraphService({required FirebaseStorage storage}) : _storage = storage;

  /// Fetches a profile photo URL, checking cache and Firebase Storage first.
  Future<String?> getProfilePhotoUrl({
    required String accessToken,
    required String userId,
    bool forceRefresh = false,
  }) async {
    debugPrint('📬 GraphService: Received access token: $accessToken');
    if (!forceRefresh && _photoUrlCache.containsKey(userId)) {
      return _photoUrlCache[userId];
    }

    final photoRef = _storage.ref('profile_pictures/$userId.jpg');
    
    if (!forceRefresh) {
      try {
        final existingUrl = await photoRef.getDownloadURL();
        _photoUrlCache[userId] = existingUrl;
        return existingUrl;
      } catch (_) {
        // Photo doesn't exist in Storage, so we'll fetch it.
      }
    }

    // Fetch using the new package, upload, and get the URL
    final photoUrl = await _fetchAndUploadPhoto(
      accessToken: accessToken,
      photoRef: photoRef,
    );
    
    _photoUrlCache[userId] = photoUrl;
    return photoUrl;
  }
  
  /// Helper method to perform the actual fetch and upload using microsoft_graph_api.
   Future<String?> _fetchAndUploadPhoto({
    required String accessToken,
    required Reference photoRef,
  }) async {
    try {
      debugPrint('🚀 Correctly initializing MSGraphAPI with access token...');
      
      // 1. Initialize MSGraphAPI with the access token from Firebase Auth.
      final graphApi = MSGraphAPI(accessToken);

      // 2. Fetch the photo data directly as Uint8List.
      // We omit the size parameter to get the original, largest available photo.
      final Uint8List? photoBytes = await graphApi.me.fetchUserProfileImage(PhotoSize().getPicSize(PhotoSizeEnum.size96x96));

      // 3. Check if the user has a photo.
      if (photoBytes == null) {
        debugPrint('🤷 User does not have a profile photo on Microsoft Graph.');
        return null;
      }
      
      // 4. Upload the Uint8List data directly. No conversion needed.
      await photoRef.putData(photoBytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await photoRef.getDownloadURL();
      
      debugPrint('🎉 Successfully uploaded photo. URL: $downloadUrl');
      return downloadUrl;

    } catch (e) {
      // This will catch any errors during the API call or upload.
      print('🔥 An error occurred while fetching/uploading the photo: $e');
      return null;  
    }
  }
}