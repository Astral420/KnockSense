import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
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
    // Request permission
    await _requestPermission();
    
    // Initialize local notifications
    await _initializeLocalNotifications();
    
    // Get FCM token
    final token = await _messaging.getToken();
    debugPrint('FCM Token: $token');
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
    
    // Handle notification taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
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
  try {
    final token = await _messaging.getToken();
    if (token != null) {
      // Store tokens as a map to support multiple devices
      await _database.ref('fcm_tokens/$uid/$token').set({
        'token': token,
        'role': role,
        'deviceId': token.substring(0, 20), // Simple device identifier
        'updatedAt': ServerValue.timestamp,
      });
    }
  } catch (e) {
    debugPrint('Error saving FCM token: $e');
  }
}

Future<void> clearUserToken(String uid) async {
  try {
    final token = await _messaging.getToken();
    if (token != null) {
      // Remove only this device's token
      await _database.ref('fcm_tokens/$uid/$token').remove();
      
      // Unsubscribe from all topics
      for (String teacherUid in _subscribedTeachers) {
        await _messaging.unsubscribeFromTopic('teacher_$teacherUid');
      }
      _subscribedTeachers.clear();
    }
  } catch (e) {
    debugPrint('Error clearing FCM token: $e');
  }
}

  // Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
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
    debugPrint('Notification tapped: ${response.payload}');
    // Navigate to appropriate screen based on payload
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('Message opened app: ${message.data}');
    // Navigate to appropriate screen based on message data
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _handleBackgroundMessage(RemoteMessage message) async {
  debugPrint('Background message: ${message.notification?.title}');
}