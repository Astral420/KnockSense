import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:knocksense/models/notification_preferences.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message received: ${message.notification?.title}');
}

class NotificationService {
  bool get _isPlatformSupported => Platform.isAndroid;
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  static const String _channelId = 'appointments_v2';
  static const String _channelName = 'Appointment Notifications';
  static const String _channelDescription = 'Notifications for appointment updates';
  static const String _channelSoundResource = 'notification_sound';

  NotificationPreferenceState _currentPreferences =
      NotificationPreferenceState.defaults;
  NotificationPreferenceState _lastAppliedChannelPreferences =
      NotificationPreferenceState.defaults;
  bool _hasCreatedChannel = false;

  // Store subscribed teacher UIDs locally (for this session)
  final Set<String> _subscribedTeachers = {};

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      debugPrint('Notification service is only available on Android');
      return;
    }

    await _requestPermission();
    await _initializeLocalNotifications();
    await _ensureNotificationChannel(_currentPreferences);
    
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> applyPreferences(NotificationPreferenceState preferences) async {
    _currentPreferences = preferences;
    if (!_isPlatformSupported) {
      return;
    }
    await _ensureNotificationChannel(preferences);
  }

  Future<void> _ensureNotificationChannel(
    NotificationPreferenceState preferences,
  ) async {
    if (!_isPlatformSupported) {
      return;
    }

    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation == null) {
      debugPrint('Android notifications implementation not available');
      return;
    }

    final bool needsUpdate = !_hasCreatedChannel ||
        _lastAppliedChannelPreferences.vibrateEnabled !=
            preferences.vibrateEnabled ||
        _lastAppliedChannelPreferences.soundEnabled !=
            preferences.soundEnabled;

    if (!needsUpdate) {
      return;
    }

    try {
      await androidImplementation.deleteNotificationChannel(_channelId);
    } catch (e) {
      debugPrint('Failed to delete existing channel $_channelId: $e');
    }

    if (!_hasCreatedChannel) {
      try {
        await androidImplementation.deleteNotificationChannel('appointments');
        debugPrint('Removed legacy appointments channel');
      } catch (_) {}
    }

    RawResourceAndroidNotificationSound? sound;
    if (preferences.soundEnabled) {
      sound = const RawResourceAndroidNotificationSound(
        _channelSoundResource,
      );
    }

    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: preferences.soundEnabled,
      enableVibration: preferences.vibrateEnabled,
      sound: sound,
    );

    await androidImplementation.createNotificationChannel(channel);
    _lastAppliedChannelPreferences = preferences;
    _hasCreatedChannel = true;
  }

  Future<void> saveRemotePreferences(
    String uid,
    NotificationPreferenceState preferences,
  ) async {
    try {
      await _database.ref('notifications/preferences/$uid').set({
        'sound': preferences.soundEnabled,
        'vibrate': preferences.vibrateEnabled,
        'updatedAt': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('❌ Failed to persist notification preferences for $uid: $e');
    }
  }


  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  // Subscribe to teacher status updates
  Future<void> subscribeToTeacher(String teacherUid, String studentUid) async {
    if (!_isPlatformSupported) return;
    try {
      // Subscribe the FCM token to this teacher's topic
      await _messaging.subscribeToTopic('teacher_$teacherUid');
      _subscribedTeachers.add(teacherUid);
      
      // Store subscription preference in database (per user, not per token)
      // This is just a record of what the user wants to subscribe to
      await _database
          .ref('notifications/subscriptions/$studentUid/$teacherUid')
          .set({
        'subscribed': true,
        'subscribedAt': ServerValue.timestamp,
      });
      
      debugPrint('✅ Subscribed to teacher notifications: $teacherUid');
    } catch (e) {
      debugPrint('❌ Error subscribing to teacher: $e');
    }
  }

  // Unsubscribe from teacher status updates
  Future<void> unsubscribeFromTeacher(String teacherUid, String studentUid) async {
    if (!_isPlatformSupported) return;
    try {
      await _messaging.unsubscribeFromTopic('teacher_$teacherUid');
      _subscribedTeachers.remove(teacherUid);
      
      await _database
          .ref('notifications/subscriptions/$studentUid/$teacherUid')
          .remove();
      
      debugPrint('✅ Unsubscribed from teacher notifications: $teacherUid');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from teacher: $e');
    }
  }

  bool isSubscribedToTeacher(String teacherUid) {
    return _subscribedTeachers.contains(teacherUid);
  }

  // Load user's subscription preferences and apply them to current FCM token
  Future<void> loadSubscriptions(String studentUid) async {
    if (!_isPlatformSupported) return;
    try {
      debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
      debugPrint('📥 LOADING subscriptions for student: $studentUid');
      
      final snapshot = await _database
          .ref('notifications/subscriptions/$studentUid')
          .get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        
        // Subscribe the current FCM token to all of this user's preferred topics
        for (String teacherUid in data.keys) {
          _subscribedTeachers.add(teacherUid);
          await _messaging.subscribeToTopic('teacher_$teacherUid');
          debugPrint('   ✅ Subscribed to teacher_$teacherUid');
        }
        
        debugPrint('   📊 Total: ${_subscribedTeachers.length} subscription(s)');
      } else {
        debugPrint('   ℹ️ No subscriptions found');
      }
      
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    } catch (e) {
      debugPrint('❌ Error loading subscriptions: $e');
    }
  }

  Future<void> showAppointmentNotification({
    required String title,
    required String body,
    String? bigText,
    Map<String, dynamic>? payload,
  }) async {
    if (!_isPlatformSupported) return;
    
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('🔔 SHOWING LOCAL NOTIFICATION');
    debugPrint('   Title: $title');
    debugPrint('   Body: $body');
    if (bigText != null) {
      debugPrint('   BigText: $bigText');
    }
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    
    final BigTextStyleInformation? bigTextStyleInformation = bigText != null
        ? BigTextStyleInformation(
            bigText,
            htmlFormatBigText: true,
            contentTitle: title,
            htmlFormatContentTitle: true,
            summaryText: body,
            htmlFormatSummaryText: true,
          )
        : null;

    final androidPreferences = _currentPreferences;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: androidPreferences.soundEnabled,
      enableVibration: androidPreferences.vibrateEnabled,
      sound: androidPreferences.soundEnabled
          ? const RawResourceAndroidNotificationSound(_channelSoundResource)
          : null,
      icon: '@mipmap/launcher_icon',
      styleInformation: bigTextStyleInformation,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload != null ? payload.toString() : null,
    );
  }

  // Save FCM token for this user (for sending direct notifications)
  Future<void> saveUserToken(String uid, String role) async {
    if (!_isPlatformSupported) return; 
    try {
      final token = await _messaging.getToken();
      
      debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
      debugPrint('💾 SAVING FCM TOKEN');
      debugPrint('   UID: $uid');
      debugPrint('   Role: $role');
      debugPrint('   Token: ${token?.substring(0, 30)}...');
      
      if (token != null) {
        final deviceId = DateTime.now().millisecondsSinceEpoch.toString();
        await _database.ref('fcm_tokens/$uid/$deviceId').set({
          'token': token,
          'role': role,
          'updatedAt': ServerValue.timestamp,
          'platform': 'android',
        });
        
        debugPrint('   ✅ Token saved successfully');
      }
      
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  // ✅ SIMPLIFIED FIX: Just unsubscribe the FCM token from all topics
  // Keep subscription records in database - they're per-user preferences
  Future<void> clearUserToken(String uid) async {
    if (!_isPlatformSupported) return;
    try {
      debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
      debugPrint('🧹 CLEARING FCM TOKEN SUBSCRIPTIONS');
      debugPrint('   User UID: $uid');
      
      final currentToken = await _messaging.getToken();
      if (currentToken == null) {
        debugPrint('   ⚠️ No current token found');
        debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
        return;
      }
      
      debugPrint('   Token: ${currentToken.substring(0, 20)}...');
      
      // ✅ KEY FIX: Unsubscribe FCM token from ALL topics this user was subscribed to
      // Get subscription list from database
      final subscriptionsSnapshot = await _database
          .ref('notifications/subscriptions/$uid')
          .get();
      
      if (subscriptionsSnapshot.exists) {
        final subscriptions = Map<String, dynamic>.from(subscriptionsSnapshot.value as Map);
        
        debugPrint('   📋 Found ${subscriptions.length} subscription(s)');
        
        // Unsubscribe token from each topic
        for (var teacherUid in subscriptions.keys) {
          await _messaging.unsubscribeFromTopic('teacher_$teacherUid');
          debugPrint('   🔕 Unsubscribed from teacher_$teacherUid');
        }
        
        debugPrint('   ✅ Token unsubscribed from all topics');
      } else {
        debugPrint('   ℹ️ No subscriptions found');
      }
      
      // Clear in-memory set
      _subscribedTeachers.clear();
      debugPrint('   🧹 Cleared in-memory subscription list');
      
      // Remove token from database (so old user won't get direct notifications)
      final tokensRef = _database.ref('fcm_tokens/$uid');
      final snapshot = await tokensRef.get();
      
      if (snapshot.exists && snapshot.value is Map) {
        final devices = Map<String, dynamic>.from(snapshot.value as Map);
        
        for (final entry in devices.entries) {
          final value = entry.value;
          if (value is Map && value['token'] == currentToken) {
            await tokensRef.child(entry.key).remove();
            debugPrint('   🗑️ Removed token from database');
            break;
          }
        }
      }
      
      // ✅ NOTE: We DON'T delete subscription preferences from database
      // Those stay with the user account - they're just preferences
      // Next time this user logs in, they'll resubscribe the token to their topics
      
      debugPrint('   ✅ Cleanup complete');
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    } catch (e, stackTrace) {
      debugPrint('❌ Error clearing FCM token: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!_isPlatformSupported) return;
    
    debugPrint('┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓');
    debugPrint('📨 FOREGROUND MESSAGE RECEIVED');
    debugPrint('   Message ID: ${message.messageId}');
    debugPrint('   Title: ${message.notification?.title ?? "none"}');
    debugPrint('   Body: ${message.notification?.body ?? "none"}');
    debugPrint('   Data: ${message.data}');
    debugPrint('┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛');
  
    if (message.notification != null) {
      // Extract bigText from the data payload
      final String? bigText = message.data['bigText'] as String?;

      showAppointmentNotification(
        title: message.notification!.title ?? 'KnockSense',
        body: message.notification!.body ?? '',
        bigText: bigText,
        payload: message.data,
      );
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (!_isPlatformSupported) return;
    debugPrint('Notification tapped: ${response.payload}');
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (!_isPlatformSupported) return;
    debugPrint('Message opened app: ${message.data}');
  }
}