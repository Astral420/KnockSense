// index.js (Cloud Functions v1)

const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { onSchedule } = require("firebase-functions/v2/scheduler");

// Initialize the Admin SDK
admin.initializeApp();


// ========================================================================================
// REPLACEMENT FOR: processNotificationQueue
// ========================================================================================
/**
 * Processes notifications added to '/notification_queue'.
 * Sends the notification immediately upon creation. This version includes
 * improved error handling over the original.
 */
exports.processnotificationqueue = functions.database.ref("/notification_queue/{pushId}")
  .onCreate(async (snapshot, context) => {
    const notificationData = snapshot.val();
    const notificationRef = snapshot.ref;
    const { pushId } = context.params;

    if (!notificationData) {
      functions.logger.log("Notification data was null, exiting function.");
      return;
    }

    try {
      const message = {
        token: notificationData.to,
        notification: notificationData.notification || {
          title: notificationData.title || 'KnockSense',
          body: notificationData.body || 'You have a new notification',
        },
        data: notificationData.data || {},
        android: { // Including Android-specific config for high priority
          priority: 'high',
          notification: {
            channelId: 'appointments',
          },
        },
      };

      await admin.messaging().send(message);
      functions.logger.log(`Successfully sent message for pushId: ${pushId}`);
      await notificationRef.remove();

    } catch (error) {
      functions.logger.error(`Error sending notification for pushId: ${pushId}`, error);
      await notificationRef.update({
        failed: true,
        error: error.message,
        failedAt: admin.database.ServerValue.TIMESTAMP
      });
    }
  });


// ========================================================================================
// REPLACEMENT FOR: scheduleWaitReminder - NOW MORE RELIABLE
// ========================================================================================
/**
 * When a teacher's action is updated to 'wait5Minutes', this function reliably
 * schedules a reminder notification by adding it to the 'scheduled_notifications' queue.
 */
exports.schedulewaitreminder = functions.database.ref("/appointments/{studentNumber}/{appointmentId}/teacherAction")
  .onUpdate(async (change, context) => {
    // Check if the new value is 'wait5Minutes'
    if (change.after.val() !== 'wait5Minutes') {
      return;
    }

    const appointmentRef = change.after.ref.parent;
    const appointmentSnapshot = await appointmentRef.once('value');
    const appointment = appointmentSnapshot.val();
    const { appointmentId, studentNumber } = context.params;


    // Ensure there's data to work with (e.g., student's FCM token)
    if (!appointment || !appointment.studentFcmToken) {
      functions.logger.error("Appointment data or student FCM token missing.");
      return;
    }

    // Create a notification payload to be placed in the scheduled queue
    const scheduledNotification = {
      to: appointment.studentFcmToken,
      delayMinutes: 5,
      title: "Reminder",
      body: `The teacher is keeping you on wait. Please stand by.`,
      data: {
        appointmentId: appointmentId,
        studentNumber: studentNumber,
      },
    };

    // Push the notification to the queue to be processed by the scheduled job
    await admin.database().ref('/scheduled_notifications').push(scheduledNotification);
    functions.logger.log(`Scheduled a 5-minute wait reminder for appointment: ${appointmentId}`);
  });


// ========================================================================================
// REPLACEMENT FOR: notifyTeacherStatusChange
// ========================================================================================
/**
 * Helper function to query and notify students subscribed to a teacher.
 * @param {string} teacherUid The UID of the teacher.
 */
async function notifySubscribedStudents(teacherUid) {
  const teacherNameRef = admin.database().ref(`/roles/teacher/${teacherUid}/name`);
  const teacherNameSnap = await teacherNameRef.once('value');
  const teacherName = teacherNameSnap.val() || 'Your subscribed teacher';

  const subscriptionsRef = admin.database()
    .ref(`notifications/subscriptions`)
    .orderByChild(teacherUid)
    .equalTo(true);

  const snapshot = await subscriptionsRef.once('value');
  if (!snapshot.exists()) {
    functions.logger.log(`Teacher ${teacherUid} is now online, but no students are subscribed.`);
    return;
  }

  const promises = [];
  snapshot.forEach(sub => {
    const studentUid = sub.key;
    // You would need to get the student's FCM token here
    // For now, let's assume we write to a notification queue
    const notification = {
      // to: studentFcmToken, // You need to fetch this token
      title: "Teacher is Online!",
      body: `${teacherName} is now available.`,
      data: { teacherId: teacherUid },
    };
    // This should write to the 'notification_queue' to be processed
    // promises.push(admin.database().ref('/notification_queue').push(notification));
    functions.logger.log(`Preparing online notification for student ${studentUid} about teacher ${teacherUid}.`);
  });

  await Promise.all(promises);
}

/**
 * Monitors teacher status and notifies subscribed students when a teacher comes online.
 */
exports.notifyteacherstatuschange = functions.database.ref("/roles/teacher/{teacherUid}/active_status")
  .onUpdate(async (change, context) => {
    const newStatus = change.after.val();
    const oldStatus = change.before.val();
    const { teacherUid } = context.params;

    // Trigger only when status changes TO 'online'
    if (newStatus === 'online' && oldStatus !== 'online') {
      functions.logger.log(`Teacher ${teacherUid} status changed to online. Notifying subscribers.`);
      await notifySubscribedStudents(teacherUid);
    }
  });


// ========================================================================================
// REQUIRED FUNCTIONS FOR THE SCHEDULING SYSTEM
// Replaces 'processScheduledNotifications' and adds the processing job.
// ========================================================================================
/**
 * Prepares a scheduled notification by calculating its send time.
 * Triggers when a new entry is added to '/scheduled_notifications'.
 */
exports.processschedulednotifications = functions.database.ref("/scheduled_notifications/{pushId}")
  .onCreate(async (snapshot) => {
    const data = snapshot.val();
    if (!data) return;

    const delayMinutes = data.delayMinutes || 5;
    const scheduledTime = Date.now() + (delayMinutes * 60 * 1000);

    await snapshot.ref.update({
      scheduledFor: scheduledTime,
      status: 'pending'
    });
  });

/**
 * A scheduled function that runs every minute to check for and send due notifications.
 */
exports.sendschedulednotifications = functions.pubsub.schedule("every 1 minutes")
  .onRun(async (context) => {
    const now = Date.now();
    const pendingRef = admin.database()
      .ref('scheduled_notifications')
      .orderByChild('scheduledFor')
      .endAt(now);

    const snapshot = await pendingRef.once('value');
    if (!snapshot.exists()) return;

    const promises = [];
    snapshot.forEach(async (child) => {
      const notification = child.val();
      if (notification.status === 'pending') {
        const message = {
          token: notification.to,
          notification: { title: notification.title, body: notification.body },
          data: notification.data || {}
        };
        const sendPromise = admin.messaging().send(message)
          .then(() => child.ref.update({ status: 'sent', sentAt: admin.database.ServerValue.TIMESTAMP }))
          .catch((err) => child.ref.update({ status: 'failed', error: err.message }));
        promises.push(sendPromise);
      }

    await Promise.all(promises);
  });
});