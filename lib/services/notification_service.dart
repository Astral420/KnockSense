import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed
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

  // Store subscribed teacher UIDs locally
  final Set<String> _subscribedTeachers = {};

  Future<void> initialize() async {

    if (!Platform.isAndroid) {
    debugPrint('Notification service is only available on Android');
    return;
  }

    // Request permission
    await _requestPermission();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // CREATE ANDROID NOTIFICATION CHANNEL (ADD THIS!)
    await _createNotificationChannel();
    
    // Get FCM token
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    
    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Channel is created in _createNotificationChannel(); no need to redefine here
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
      // Subscribe to FCM topic
      await _messaging.subscribeToTopic('teacher_$teacherUid');
      _subscribedTeachers.add(teacherUid);
      
      // Store subscription in database
      await _database
          .ref('notifications/subscriptions/$studentUid/$teacherUid')
          .set({
        'subscribed': true,
        'subscribedAt': ServerValue.timestamp,
      });
      
      debugPrint('Subscribed to teacher notifications: $teacherUid');
    } catch (e) {
      debugPrint('Error subscribing to teacher: $e');
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
      
      debugPrint('Unsubscribed from teacher notifications: $teacherUid');
    } catch (e) {
      debugPrint('Error unsubscribing from teacher: $e');
    }
  }

  // Check if subscribed to teacher
  bool isSubscribedToTeacher(String teacherUid) {
    return _subscribedTeachers.contains(teacherUid);
  }

  // Load existing subscriptions
  Future<void> loadSubscriptions(String studentUid) async {
    try {
      final snapshot = await _database
          .ref('notifications/subscriptions/$studentUid')
          .get();
      
      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        for (String teacherUid in data.keys) {
          _subscribedTeachers.add(teacherUid);
          await _messaging.subscribeToTopic('teacher_$teacherUid');
        }
      }
    } catch (e) {
      debugPrint('Error loading subscriptions: $e');
    }
  }

  // Send local notification for appointment updates
  Future<void> showAppointmentNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (!_isPlatformSupported) return;
    const androidDetails = AndroidNotificationDetails(
      'appointments',
      'Appointment Notifications',
      channelDescription: 'Notifications for appointment updates',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
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

  // Store FCM token for user
  Future<void> saveUserToken(String uid, String role) async {
  if (!_isPlatformSupported) return; 
  try {
    final token = await _messaging.getToken();
    if (token != null) {
      // FIXED: Use a simpler structure with token as value, not key
      final deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await _database.ref('fcm_tokens/$uid/$deviceId').set({
        'token': token,
        'role': role,
        'updatedAt': ServerValue.timestamp,
        'platform': 'android',
      });
      debugPrint('FCM token saved for user $uid');
    }
  } catch (e) {
    debugPrint('Error saving FCM token: $e');
  }
}

Future<void> clearUserToken(String uid) async {
  if (!_isPlatformSupported) return;
  try {
    final currentToken = await _messaging.getToken();
    if (currentToken == null) return;

    // Find and remove the device entry whose stored token matches currentToken
    final tokensRef = _database.ref('fcm_tokens/$uid');
    final snapshot = await tokensRef.get();
    if (snapshot.exists && snapshot.value is Map) {
      final Map<String, dynamic> devices = Map<String, dynamic>.from(snapshot.value as Map);
      for (final entry in devices.entries) {
        final value = entry.value;
        if (value is Map && value['token'] == currentToken) {
          await tokensRef.child(entry.key).remove();
        }
      }
    }

    // Unsubscribe from all topics for this runtime
    for (String teacherUid in _subscribedTeachers) {
      await _messaging.unsubscribeFromTopic('teacher_$teacherUid');
    }
    _subscribedTeachers.clear();
  } catch (e) {
    debugPrint('Error clearing FCM token: $e');
  }
}

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    if (!_isPlatformSupported) return;
    debugPrint('Foreground message: ${message.notification?.title}');
    
    // Show local notification
    if (message.notification != null) {
      showAppointmentNotification(
        title: message.notification!.title ?? 'KnockSense',
        body: message.notification!.body ?? '',
        payload: message.data,
      );
    }
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (!_isPlatformSupported) return;
    debugPrint('Notification tapped: ${response.payload}');
    // Navigate to appropriate screen based on payload
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    if (!_isPlatformSupported) return;
    debugPrint('Message opened app: ${message.data}');
    // Navigate to appropriate screen based on message data
  }
}

Future<void> _createNotificationChannel() async {
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'appointments', // id
    'Appointment Notifications', // title
    description: 'Notifications for appointment updates',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  
  debugPrint('Android notification channel created');
}

  

