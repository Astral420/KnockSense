/* eslint-disable */
'use strict';

const admin = require('firebase-admin');
const {onValueCreated, onValueWritten} = require('firebase-functions/v2/database');
const {onSchedule} = require('firebase-functions/v2/scheduler');

try {
	admin.initializeApp();
} catch (e) {}

const db = admin.database();

function buildFcmMessageFromQueueItem(item) {
	const hasExplicitNotification = !!item.notification;
	const notification = hasExplicitNotification
		? item.notification
		: ((item.title || item.body)
			? {title: item.title || 'KnockSense', body: item.body || ''}
			: undefined);

	const data = item.data ? Object.entries(item.data).reduce((acc, [k, v]) => {
		acc[String(k)] = String(v);
		return acc;
	}, {}) : undefined;

	const android = {
		priority: 'high',
		notification: {
			channelId: 'appointments'
			
		},
	};

	return {notification, data, android};
}

async function sendToToken(token, baseMessage) {
	const message = {token, ...baseMessage};
	return admin.messaging().send(message);
}

async function sendToTopic(topic, baseMessage) {
	const message = {topic, ...baseMessage};
	return admin.messaging().send(message);
}

async function getUserTokens(uid) {
	const snap = await db.ref(`fcm_tokens/${uid}`).get();
	if (!snap.exists()) return [];
	const value = snap.val();
	const tokens = [];
	Object.values(value).forEach((entry) => {
		if (entry && entry.token) tokens.push(String(entry.token));
	});
	return tokens;
}

exports.processNotificationQueue = onValueCreated({
	ref: '/notification_queue/{pushId}',
	region: 'asia-southeast1',
	instance: 'knocksense-21180-default-rtdb',
}, async (event) => {
	const ref = event.data.ref;
	const item = event.data.val();
	if (!item) return;

	try {
		const messageBase = buildFcmMessageFromQueueItem(item);

		const sends = [];
		if (item.to) sends.push(sendToToken(String(item.to), messageBase));
		if (item.topic) sends.push(sendToTopic(String(item.topic), messageBase));
		if (item.studentUid) {
			const tokens = await getUserTokens(String(item.studentUid));
			if (tokens.length > 0) {
				sends.push(admin.messaging().sendEachForMulticast({tokens, ...messageBase}));
			}
		}
		if (item.teacherUid) {
			const tokens = await getUserTokens(String(item.teacherUid));
			if (tokens.length > 0) {
				sends.push(admin.messaging().sendEachForMulticast({tokens, ...messageBase}));
			}
		}

		const responses = await Promise.allSettled(sends);
		for (const res of responses) {
			if (res.status === 'fulfilled' && res.value && res.value.responses) {
				// prune invalid tokens for multicast responses if present
				const tokens = []; // we don't have the token list here; skipping prune in queue
			}
		}
	} catch (e) {
		console.error('Error processing queue item:', e);
	} finally {
		await ref.remove();
	}
});

// ✅ CORRECT: Create user notification ONCE, then send to all tokens
exports.processScheduledNotifications = onValueCreated({
	ref: '/scheduled_notifications/{notificationId}',
	region: 'asia-southeast1',
	instance: 'knocksense-21180-default-rtdb',
}, async (event) => {
    const data = event.data.val();
    
    // ✅ STEP 1: Create ONE user notification (outside token loop)
    if (data.teacherUid && data.appointmentId && data.studentNumber) {
      try {
        // Determine notification type
        let notificationType = 'appointmentDue';
        let title = data.title || '⏰ Appointment Ready';
        let body = data.body || 'Appointment notification';
        
        if (data.type === 'scheduled_appointment_reminder') {
          notificationType = 'scheduledAppointmentReminder';
          title = data.title || '📅 Upcoming Appointment';
        } else if (data.type === 'scheduled_appointment_due') {
          notificationType = 'appointmentDue';
          title = data.title || '⏰ Appointment Ready';
        }
        
        // Create ONE user notification
        const notificationRef = db.ref(`user_notifications/${data.teacherUid}`).push();
        await notificationRef.set({
          userId: data.teacherUid,
          title: title,
          body: body,
          type: notificationType,
          createdAt: admin.database.ServerValue.TIMESTAMP,
          isRead: false,
          data: {
            appointmentId: data.appointmentId,
            studentNumber: data.studentNumber,
            studentName: data.data?.studentName || 'Student',
            urgency: data.type === 'scheduled_appointment_due' ? 'high' : 'medium',
          },
        });
        console.log(`✅ Created ONE user notification (${notificationType}): ${data.appointmentId}`);
      } catch (e) {
        console.error('❌ Error creating user notification:', e);
      }
    }
    
    // ✅ STEP 2: Send FCM to ALL tokens (separate from user notification)
    const tokensSnapshot = await db.ref(`fcm_tokens/${data.teacherUid}`).get();
    
    if (tokensSnapshot.exists()) {
      const tokens = tokensSnapshot.val();
      
      // Send FCM notification to each device
      for (const tokenEntry of Object.values(tokens)) {
        try {
          // Your existing FCM sending code
          await sendToToken(tokenEntry.token, {
            notification: {
              title: data.title,
              body: data.body,
            },
            data: data.data || {},
          });
          console.log(`✅ Sent FCM to token`);
        } catch (e) {
          console.error('❌ Error sending FCM:', e);
        }
      }
    }
});

// Notify subscribers when teacher active_status changes
exports.onTeacherStatusChange = onValueWritten({
	ref: '/roles/teacher/{teacherUid}/active_status',
	region: 'asia-southeast1',
	instance: 'knocksense-21180-default-rtdb',
}, async (event) => {
	const before = event.data.before.val();
	const after = event.data.after.val();
	if (after == null || before === after) return;
	const teacherUid = event.params.teacherUid;
	const topic = `teacher_${teacherUid}`;
	let displayName = 'Your professor';
	try {
		const nameSnap = await db.ref(`roles/teacher/${teacherUid}/displayName`).get();
		if (nameSnap.exists()) displayName = String(nameSnap.val());
	} catch (e) {}
	const title = `${displayName} is ${String(after)}`;
	const base = buildFcmMessageFromQueueItem({
		notification: {title, body: 'Tap to view details'},
		data: {type: 'teacher_status', teacherUid: teacherUid, status: String(after), displayName},
	});
	try {
		await sendToTopic(topic, base);
	} catch (e) {
		console.error('Failed to send teacher status notification:', e);
	}
	try {
		// Get all students subscribed to this teacher (topic: teacher_{teacherUid})
		const subscriptionsSnapshot = await db.ref('notifications/subscriptions').get();
  
		if (subscriptionsSnapshot.exists()) {
		  const allSubscriptions = subscriptionsSnapshot.val();
		  const statusEmoji = after === 'online' ? '✅' : after === 'busy' ? '🟡' : '⚫';
		  const statusText = after === 'online' ? 'now online' : after === 'busy' ? 'now busy' : 'now offline';
		  
		  // Find all students subscribed to this teacher
		  const notificationPromises = [];
		  for (const [studentUid, studentSubscriptions] of Object.entries(allSubscriptions)) {
			// Check if this student is subscribed to the teacher
			if (studentSubscriptions[teacherUid] && studentSubscriptions[teacherUid].subscribed === true) {
			  const notificationRef = db.ref(`user_notifications/${studentUid}`).push();
			  
			  const notification = {
				userId: studentUid,
				title: `${statusEmoji} ${displayName} is ${statusText}`,
				body: 'Tap to view details',
				type: 'teacherStatusChange',
				createdAt: admin.database.ServerValue.TIMESTAMP,
				isRead: false,
				data: {
				  teacherUid: teacherUid,
				  teacherName: displayName,
				  status: String(after),
				},
			  };
			  
			  notificationPromises.push(notificationRef.set(notification));
			}
		  }
		  
		  await Promise.all(notificationPromises);
		  console.log(`✅ Created ${notificationPromises.length} user notifications for teacher status change`);
		} else {
		  console.log('ℹ️ No subscriptions found');
		}
	  } catch (e) {
		console.error('❌ Error creating user notifications for teacher status:', e);
	  }
});

// Notify subscribers when teacher_msg changes
exports.onTeacherMessageChange = onValueWritten({
	ref: '/roles/teacher/{teacherUid}/teacher_msg',
	region: 'asia-southeast1',
	instance: 'knocksense-21180-default-rtdb',
}, async (event) => {
	const before = event.data.before.val();
	const after = event.data.after.val();
	if (before === after) return;
	const teacherUid = event.params.teacherUid;
	const topic = `teacher_${teacherUid}`;
	let displayName = 'Your professor';
	try {
		const nameSnap = await db.ref(`roles/teacher/${teacherUid}/displayName`).get();
		if (nameSnap.exists()) displayName = String(nameSnap.val());
	} catch (e) {}
	const messageText = after == null ? '' : String(after);
	const title = `${displayName} posted an update`;
	const body = messageText || 'Note cleared';
	const base = buildFcmMessageFromQueueItem({
		notification: {title, body},
		data: {type: 'teacher_msg', teacherUid: teacherUid, displayName, message: messageText},
	});
	try {
		await sendToTopic(topic, base);
	} catch (e) {
		console.error('Failed to send teacher message notification:', e);
	}
	try {
		// Get all students subscribed to this teacher
		const subscriptionsSnapshot = await db.ref('notifications/subscriptions').get();
  
		if (subscriptionsSnapshot.exists()) {
		  const allSubscriptions = subscriptionsSnapshot.val();
		  
		  // Find all students subscribed to this teacher
		  const notificationPromises = [];
		  for (const [studentUid, studentSubscriptions] of Object.entries(allSubscriptions)) {
			// Check if this student is subscribed to the teacher
			if (studentSubscriptions[teacherUid] && studentSubscriptions[teacherUid].subscribed === true) {
			  const notificationRef = db.ref(`user_notifications/${studentUid}`).push();
			  
			  const notification = {
				userId: studentUid,
				title: `📝 ${displayName} posted an update`,
				body: body,
				type: 'teacherStatusChange',
				createdAt: admin.database.ServerValue.TIMESTAMP,
				isRead: false,
				data: {
				  teacherUid: teacherUid,
				  teacherName: displayName,
				  message: messageText,
				},
			  };
			  
			  notificationPromises.push(notificationRef.set(notification));
			}
		  }
		  
		  await Promise.all(notificationPromises);
		  console.log(`✅ Created ${notificationPromises.length} user notifications for teacher message`);
		} else {
		  console.log('ℹ️ No subscriptions found');
		}
	  } catch (e) {
		console.error('❌ Error creating user notifications for teacher message:', e);
	  }
});

async function pruneInvalidTokens(uid, tokens, multicastResponse) {
	if (!multicastResponse || !multicastResponse.responses) return;
	const toRemove = [];
	multicastResponse.responses.forEach((r, idx) => {
		if (!r.success && r.error && r.error.code) {
			const code = r.error.code;
			if (code.includes('registration-token-not-registered') || code.includes('invalid-argument')) {
				toRemove.push(tokens[idx]);
			}
		}
	});
	if (toRemove.length === 0) return;
	const userRef = db.ref(`fcm_tokens/${uid}`);
	const snap = await userRef.get();
	if (!snap.exists()) return;
	const value = snap.val();
	for (const [deviceId, entry] of Object.entries(value)) {
		if (entry && toRemove.includes(entry.token)) {
			await userRef.child(deviceId).remove();
		}
	}
}
