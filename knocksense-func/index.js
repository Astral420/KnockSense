/* eslint-disable */
'use strict';

const admin = require('firebase-admin');
const {onValueCreated, onValueWritten} = require('firebase-functions/v2/database');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onRequest} = require('firebase-functions/v2/https');
const {CloudTasksClient} = require('@google-cloud/tasks');

try {
	admin.initializeApp();
} catch (e) {}

// Transform manual door unlock requests -> commands with validation
exports.onManualDoorUnlockRequest = onValueWritten({
  ref: '/door_unlock_requests/{teacherID}',
  region: 'asia-southeast1',
  instance: 'knocksense-21180-default-rtdb',
}, async (event) => {
  const teacherID = event.params.teacherID;
  const db2 = admin.database();
  const after = event.data.after.val();
  if (!after) return; // deleted

  // Only act on pending requests
  const status = String(after.status || '');
  if (status !== 'pending') return;

  const teacherUid = String(after.teacherUid || '');
  const teacherName = String(after.teacherName || '');
  const unlockDuration = Number(after.unlockDuration || 4000);

  if (!teacherUid) {
    // Mark invalid request
    await event.data.after.ref.child('status').set('rejected');
    await event.data.after.ref.child('reason').set('missing_teacher_uid');
    await event.data.after.ref.child('processedAt').set(admin.database.ServerValue.TIMESTAMP);
    return;
  }

  try {
    // Validate teacher is not offline
    const statusSnap = await db2.ref(`roles/teacher/${teacherUid}/active_status`).get();
    const activeStatus = statusSnap.exists() ? String(statusSnap.val()) : 'offline';

    if (activeStatus === 'offline') {
      await event.data.after.ref.child('status').set('rejected');
      await event.data.after.ref.child('reason').set('teacher_offline');
      await event.data.after.ref.child('processedAt').set(admin.database.ServerValue.TIMESTAMP);
      return;
    }

    // Write command for device to consume
    const commandRef = db2.ref(`door_unlock_commands/${teacherID}`);
    await commandRef.set({
      status: 'pending',
      teacherUid,
      teacherName,
      unlockDuration,
      createdAt: admin.database.ServerValue.TIMESTAMP,
      source: 'function',
    });

    // Mark request as queued/processed
    await event.data.after.ref.update({
      status: 'queued',
      processedAt: admin.database.ServerValue.TIMESTAMP,
    });
  } catch (e) {
    console.error('❌ Error handling manual unlock request:', e);
    await event.data.after.ref.child('status').set('error');
    await event.data.after.ref.child('reason').set('internal_error');
    await event.data.after.ref.child('processedAt').set(admin.database.ServerValue.TIMESTAMP);
  }
});

const db = admin.database();

const PROJECT_ID = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
const REGION = 'asia-southeast1';
const QUEUE_ID = process.env.SCHEDULED_NOTIFICATIONS_QUEUE || 'scheduled-notifications-queue';
const tasksClient = new CloudTasksClient();
const QUEUE_PATH = PROJECT_ID ? tasksClient.queuePath(PROJECT_ID, REGION, QUEUE_ID) : null;
const SCHEDULED_HANDLER_URL = process.env.SCHEDULED_NOTIFICATION_HANDLER_URL || (PROJECT_ID
  ? `https://${REGION}-${PROJECT_ID}.cloudfunctions.net/dispatchScheduledNotification`
  : null);

const defaultNotificationPreferences = {
  soundEnabled: true,
  vibrateEnabled: true,
};

function normalizePreferences(prefs) {
  if (!prefs) {
    return {...defaultNotificationPreferences};
  }
  return {
    soundEnabled: prefs.soundEnabled ?? prefs.sound ?? true,
    vibrateEnabled: prefs.vibrateEnabled ?? prefs.vibrate ?? true,
  };
}

async function getNotificationPreferences(uid) {
  if (!uid) {
    return {...defaultNotificationPreferences};
  }
  try {
    const snapshot = await db.ref(`notifications/preferences/${uid}`).get();
    if (!snapshot.exists()) {
      return {...defaultNotificationPreferences};
    }
    return normalizePreferences(snapshot.val());
  } catch (err) {
    console.error(`⚠️ Failed to load notification preferences for ${uid}:`, err);
    return {...defaultNotificationPreferences};
  }
}

function buildFcmMessageFromQueueItem(item, preferences) {
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

  const prefs = normalizePreferences(preferences);

  const androidNotification = {
    channelId: 'appointments_v2',
  };

  if (prefs.soundEnabled) {
    androidNotification.sound = 'notification_sound';
  }

  if (prefs.vibrateEnabled) {
    androidNotification.defaultVibrateTimings = true;
  }

  const android = {
    priority: 'high',
    notification: androidNotification,
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
		const sends = [];
		if (item.to) {
			const targetPrefs = item.uid ? await getNotificationPreferences(String(item.uid)) : defaultNotificationPreferences;
			const message = buildFcmMessageFromQueueItem(item, targetPrefs);
			sends.push(sendToToken(String(item.to), message));
		}
		if (item.topic) {
			const topic = String(item.topic);
			const subscriptionsSnapshot = await db.ref('notifications/subscriptions').get();
			if (subscriptionsSnapshot.exists()) {
				const allSubscriptions = subscriptionsSnapshot.val();
				for (const [studentUid, teacherMap] of Object.entries(allSubscriptions)) {
					if (teacherMap && teacherMap[topic.replace('teacher_', '')]?.subscribed === true) {
						const tokens = await getUserTokens(studentUid);
						if (tokens.length > 0) {
							const prefs = await getNotificationPreferences(studentUid);
							const message = buildFcmMessageFromQueueItem(item, prefs);
							sends.push(admin.messaging().sendEachForMulticast({tokens, ...message}));
						}
					}
				}
			}
		}
		if (item.studentUid) {
			const studentUid = String(item.studentUid);
			const tokens = await getUserTokens(studentUid);
			if (tokens.length > 0) {
				const studentPrefs = await getNotificationPreferences(studentUid);
				const studentMessage = buildFcmMessageFromQueueItem(item, studentPrefs);
				sends.push(admin.messaging().sendEachForMulticast({tokens, ...studentMessage}));
			}
		}
		if (item.teacherUid) {
			const teacherUid = String(item.teacherUid);
			const tokens = await getUserTokens(teacherUid);
			if (tokens.length > 0) {
				const teacherPrefs = await getNotificationPreferences(teacherUid);
				const teacherMessage = buildFcmMessageFromQueueItem(item, teacherPrefs);
				sends.push(admin.messaging().sendEachForMulticast({tokens, ...teacherMessage}));
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

exports.onSpecialAppointmentCreated = onValueCreated({
	ref: '/appointments/{studentNumber}/{appointmentId}',
	region: 'asia-southeast1',
	instance: 'knocksense-21180-default-rtdb',
}, async (event) => {
	const snapshot = event.data;
	const appointment = snapshot.val();
	if (!appointment) return;

	if (appointment.isSpecial !== true) return;
	if (appointment.status && appointment.status !== 'pending') return;

	const teacherUid = appointment.teacherUid;
	const studentNumber = appointment.studentNumber;
	const appointmentId = event.params.appointmentId;
	if (!teacherUid || !studentNumber || !appointmentId) return;

	const rawStudentName = appointment.studentName || 'A student';
	const cleanStudentName = String(rawStudentName).replace(/\s*\(.*?\)/g, '').trim();

	const queuePayload = {
		teacherUid: String(teacherUid),
		notification: {
			title: '🔔 New Appointment Request',
			body: `${cleanStudentName} would like to meet with you now.`,
		},
		data: {
			type: 'immediate_appointment_request',
			studentName: cleanStudentName,
			appointmentId: String(appointmentId),
			studentNumber: String(studentNumber),
			isSpecial: 'true',
			click_action: 'FLUTTER_NOTIFICATION_CLICK',
		},
		priority: 'high',
		createdAt: admin.database.ServerValue.TIMESTAMP,
	};

	try {
		await db.ref('notification_queue').push(queuePayload);
		const teacherNotificationRef = db.ref(`user_notifications/${teacherUid}`).push();
		await teacherNotificationRef.set({
			userId: String(teacherUid),
			title: '🔔 New Appointment Request',
			body: `${cleanStudentName} is requesting an appointment right now.`,
			type: 'immediateAppointment',
			createdAt: admin.database.ServerValue.TIMESTAMP,
			isRead: false,
			data: {
				appointmentId: String(appointmentId),
				studentNumber: String(studentNumber),
				studentName: cleanStudentName,
				isSpecial: true,
			},
		});
	} catch (err) {
		console.error('❌ Error handling special appointment notification:', err);
	}
});

// ✅ CORRECT: Create user notification ONCE, then send to all tokens
exports.queueScheduledNotification = onValueCreated({
  ref: '/scheduled_notifications/{notificationId}',
  region: REGION,
  instance: 'knocksense-21180-default-rtdb',
}, async (event) => {
  const data = event.data.val();
  const notificationId = event.params.notificationId;

  if (!data) return;

  if (!PROJECT_ID || !QUEUE_PATH || !SCHEDULED_HANDLER_URL) {
    console.error('❌ Missing project configuration for Cloud Tasks');
    return;
  }

  try {
    const scheduledFor = Number(data.scheduledFor);
    const nowSeconds = Math.floor(Date.now() / 1000) + 5;
    const targetSeconds = Number.isFinite(scheduledFor) ? Math.floor(scheduledFor / 1000) : nowSeconds;
    const scheduleSeconds = Math.max(nowSeconds, targetSeconds);

    const payload = {
      notificationId,
      teacherUid: data.teacherUid || null,
      studentUid: data.studentUid || null,
    };

    const taskRequest = {
      parent: QUEUE_PATH,
      task: {
        scheduleTime: {seconds: scheduleSeconds},
        httpRequest: {
          httpMethod: 'POST',
          url: SCHEDULED_HANDLER_URL,
          headers: {'Content-Type': 'application/json'},
          body: Buffer.from(JSON.stringify(payload)).toString('base64'),
        },
      },
    };

    if (process.env.SCHEDULED_TASK_SERVICE_ACCOUNT) {
      taskRequest.task.httpRequest.oidcToken = {
        serviceAccountEmail: process.env.SCHEDULED_TASK_SERVICE_ACCOUNT,
      };
    }

    const [response] = await tasksClient.createTask(taskRequest);
    await event.data.ref.child('taskName').set(response.name);
    console.log(`✅ Scheduled notification task for ${notificationId} at ${scheduleSeconds}`);
  } catch (e) {
    console.error('❌ Failed to create scheduled notification task:', e);
  }
});

exports.dispatchScheduledNotification = onRequest({region: REGION}, async (req, res) => {
  if (req.method !== 'POST') {
    res.status(405).send('Method Not Allowed');
    return;
  }

  const queueNameHeader = req.header('x-cloudtasks-queuename');
  if (queueNameHeader && !queueNameHeader.endsWith(QUEUE_ID)) {
    res.status(403).send('Forbidden');
    return;
  }

  const {notificationId} = req.body || {};
  if (!notificationId) {
    res.status(400).json({error: 'notificationId is required'});
    return;
  }

  const snapshot = await db.ref(`scheduled_notifications/${notificationId}`).get();
  if (!snapshot.exists()) {
    res.status(204).send();
    return;
  }

  const data = snapshot.val();
  const teacherUid = data.teacherUid;
  const studentUid = data.studentUid;

  try {
    await Promise.all([
      dispatchTeacherNotification({
        notificationId,
        teacherUid,
        data,
      }),
      dispatchStudentNotification({
        notificationId,
        studentUid,
        data,
      }),
    ]);
  } finally {
    await db.ref(`scheduled_notifications/${notificationId}`).remove();
  }

  res.status(200).json({status: 'processed', notificationId});
});

async function dispatchTeacherNotification({notificationId, teacherUid, data}) {
  if (!teacherUid || !data.appointmentId) return;

  let notificationType = 'appointmentDue';
  let title = data.title || '⏰ Appointment Ready';
  let body = data.body || 'Appointment notification';

  if (data.type === 'scheduled_appointment_reminder') {
    notificationType = 'scheduledAppointmentReminder';
    title = data.title || '📅 Upcoming Appointment';
  } else if (data.type === 'scheduled_appointment_due') {
    notificationType = 'appointmentDue';
    title = data.title || '⏰ Appointment Ready';
  } else if (data.type === 'wait_decision_window') {
    notificationType = 'appointmentDue';
    title = data.title || '⏰ Decision Required';
  } else if (data.type === 'wait_decision_warning') {
    notificationType = 'appointmentDue';
    title = data.title || '⚠️ 1 Minute Remaining';
  }

  try {
    const notificationRef = db.ref(`user_notifications/${teacherUid}`).push();
    const notificationData = {
      userId: teacherUid,
      title,
      body,
      type: notificationType,
      createdAt: admin.database.ServerValue.TIMESTAMP,
      isRead: false,
      data: {
        type: data.type,
      },
    };

    if (data.appointmentId) {
      notificationData.data.appointmentId = data.appointmentId;
    }
    if (data.studentNumber) {
      notificationData.data.studentNumber = data.studentNumber;
    }
    if (data.data?.studentName) {
      notificationData.data.studentName = data.data.studentName;
    }

    await notificationRef.set(notificationData);
    console.log(`✅ [${notificationId}] Teacher notification logged for ${teacherUid}`);
  } catch (err) {
    console.error('❌ Error creating teacher notification during dispatch:', err);
  }

  try {
    const tokens = await getUserTokens(String(teacherUid));
    if (tokens.length > 0) {
      const teacherPrefs = await getNotificationPreferences(String(teacherUid));
      const messageBase = buildFcmMessageFromQueueItem({
        notification: {
          title,
          body,
        },
        data: data.data || {},
      }, teacherPrefs);

      await Promise.allSettled(tokens.map((token) => sendToToken(token, messageBase)));
      console.log(`✅ [${notificationId}] Sent teacher FCM notifications`);
    } else {
      console.log(`ℹ️ [${notificationId}] No FCM tokens found for teacher ${teacherUid}`);
    }
  } catch (err) {
    console.error('❌ Error sending teacher FCM notifications during dispatch:', err);
  }
}

async function dispatchStudentNotification({notificationId, studentUid, data}) {
  if (!studentUid) return;

  let notificationType = 'general';
  let title = data.title || 'Notification';
  let body = data.body || '';

  if (data.type === 'wait_reminder') {
    notificationType = 'scheduledAppointmentReminder';
    title = data.title || '✅ Wait Period Over';
  }

  try {
    const notificationRef = db.ref(`user_notifications/${studentUid}`).push();
    const notificationData = {
      userId: studentUid,
      title,
      body,
      type: notificationType,
      createdAt: admin.database.ServerValue.TIMESTAMP,
      isRead: false,
      data: {
        type: data.type,
      },
    };

    if (data.appointmentId) {
      notificationData.data.appointmentId = data.appointmentId;
    }
    if (data.studentNumber) {
      notificationData.data.studentNumber = data.studentNumber;
    }

    await notificationRef.set(notificationData);
    console.log(`✅ [${notificationId}] Student notification logged for ${studentUid}`);
  } catch (err) {
    console.error('❌ Error creating student notification during dispatch:', err);
  }

  try {
    const tokens = await getUserTokens(String(studentUid));
    if (tokens.length > 0) {
      const studentPrefs = await getNotificationPreferences(String(studentUid));
      const messageBase = buildFcmMessageFromQueueItem({
        notification: {
          title,
          body,
        },
        data: data.data || {},
      }, studentPrefs);

      await Promise.allSettled(tokens.map((token) => sendToToken(token, messageBase)));
      console.log(`✅ [${notificationId}] Sent student FCM notifications`);
    } else {
      console.log(`ℹ️ [${notificationId}] No FCM tokens found for student ${studentUid}`);
    }
  } catch (err) {
    console.error('❌ Error sending student FCM notifications during dispatch:', err);
  }
}

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
	const cleanDisplayName = displayName.replace(/\s*\(.*?\)\s*$/, '').trim();
	const status = String(after);
	const title = `${cleanDisplayName} is ${status}`;
	const body = status === 'online'
		? `${cleanDisplayName} is available for appointments.`
		: `${cleanDisplayName} is unavailable. Schedule an appointment instead.`;
	try {
		// Get all students subscribed to this teacher (topic: teacher_{teacherUid})
		const subscriptionsSnapshot = await db.ref('notifications/subscriptions').get();
  
		if (subscriptionsSnapshot.exists()) {
		  const allSubscriptions = subscriptionsSnapshot.val();
		  const statusEmoji = after === 'online' ? '✅' : after === 'busy' ? '🟡' : '⚫';
		  const statusText = after === 'online' ? 'now online' : after === 'busy' ? 'now busy' : 'now offline';
		  const notificationPromises = [];
		  const sendPromises = [];
		  for (const [studentUid, studentSubscriptions] of Object.entries(allSubscriptions)) {
			// Check if this student is subscribed to the teacher
			if (studentSubscriptions[teacherUid] && studentSubscriptions[teacherUid].subscribed === true) {
			  const notificationRef = db.ref(`user_notifications/${studentUid}`).push();
  
			  const notificationBody = status === 'online'
				? `${cleanDisplayName} is available for appointments.`
				: `${cleanDisplayName} is unavailable. Schedule an appointment instead.`;
			  const notification = {
				userId: studentUid,
				title: `${statusEmoji} ${cleanDisplayName} is ${statusText}`,
				body: notificationBody,
				type: 'teacherStatusChange',
				createdAt: admin.database.ServerValue.TIMESTAMP,
				isRead: false,
				data: {
				  teacherUid: teacherUid,
				  teacherName: cleanDisplayName,
				  status: String(after),
				},
			  };
			  
			  notificationPromises.push(notificationRef.set(notification));
			  const tokens = await getUserTokens(String(studentUid));
			  if (tokens.length > 0) {
				const prefs = await getNotificationPreferences(String(studentUid));
				const message = buildFcmMessageFromQueueItem({
				  notification: {
					title: `${statusEmoji} ${cleanDisplayName} is ${statusText}`,
					body: notificationBody,
				  },
				  data: {
					type: 'teacher_status',
					teacherUid: teacherUid,
					status: String(after),
					displayName: cleanDisplayName,
				  },
				}, prefs);
				sendPromises.push(admin.messaging().sendEachForMulticast({tokens, ...message}));
			  }
			}
		  }
		  
		  await Promise.all(notificationPromises);
		  await Promise.allSettled(sendPromises);
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
	let displayName = 'Your professor';
	try {
		const nameSnap = await db.ref(`roles/teacher/${teacherUid}/displayName`).get();
		if (nameSnap.exists()) displayName = String(nameSnap.val());
	} catch (e) {}
	const messageText = after == null ? '' : String(after);
	const title = `${displayName} posted an update`;
	const body = messageText || 'Note cleared';
	try {
		// Get all students subscribed to this teacher
		const subscriptionsSnapshot = await db.ref('notifications/subscriptions').get();
  
		if (subscriptionsSnapshot.exists()) {
		  const allSubscriptions = subscriptionsSnapshot.val();
		  
		  // Find all students subscribed to this teacher
		  const notificationPromises = [];
		  const sendPromises = [];
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
			  const tokens = await getUserTokens(String(studentUid));
			  if (tokens.length > 0) {
				const prefs = await getNotificationPreferences(String(studentUid));
				const message = buildFcmMessageFromQueueItem({
				  notification: {
					title: `📝 ${displayName} posted an update`,
					body,
				  },
				  data: {
					type: 'teacher_msg',
					teacherUid: teacherUid,
					displayName,
					message: messageText,
				  },
				}, prefs);
				sendPromises.push(admin.messaging().sendEachForMulticast({tokens, ...message}));
			  }
			}
		  }
		  
		  await Promise.all(notificationPromises);
		  await Promise.allSettled(sendPromises);
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
