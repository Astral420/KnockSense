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
		notification: {channelId: 'appointments'},
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

		if (item.to) {
			await sendToToken(String(item.to), messageBase);
		} else if (item.topic) {
			await sendToTopic(String(item.topic), messageBase);
		} else if (item.studentUid) {
			const tokens = await getUserTokens(String(item.studentUid));
			if (tokens.length > 0) {
				const response = await admin.messaging().sendEachForMulticast({tokens, ...messageBase});
				await pruneInvalidTokens(String(item.studentUid), tokens, response);
			}
		} else if (item.teacherUid) {
			const tokens = await getUserTokens(String(item.teacherUid));
			if (tokens.length > 0) {
				const response = await admin.messaging().sendEachForMulticast({tokens, ...messageBase});
				await pruneInvalidTokens(String(item.teacherUid), tokens, response);
			}
		} else {
			console.warn('Queue item missing target (to/topic/studentUid/teacherUid). Skipping.');
		}
	} catch (e) {
		console.error('Error processing queue item:', e);
	} finally {
		await ref.remove();
	}
});

exports.deliverScheduledNotifications = onSchedule('every 1 minutes', async () => {
	const now = Date.now();
	const snap = await db.ref('scheduled_notifications')
		.orderByChild('scheduledFor')
		.endAt(now)
		.get();

	if (!snap.exists()) return;

	const updates = {};
	const removals = [];
	const entries = snap.val();

	for (const [id, item] of Object.entries(entries)) {
		try {
			const base = buildFcmMessageFromQueueItem(item);
			let sent = false;

			if (item.to) {
				await sendToToken(String(item.to), base);
				sent = true;
			} else if (item.studentUid) {
				const tokens = await getUserTokens(String(item.studentUid));
				if (tokens.length > 0) {
					const response = await admin.messaging().sendEachForMulticast({tokens, ...base});
					sent = true;
					await pruneInvalidTokens(String(item.studentUid), tokens, response);
				}
			} else if (item.teacherUid) {
				const tokens = await getUserTokens(String(item.teacherUid));
				if (tokens.length > 0) {
					const response = await admin.messaging().sendEachForMulticast({tokens, ...base});
					sent = true;
					await pruneInvalidTokens(String(item.teacherUid), tokens, response);
				}
			}

			if (sent) removals.push(id);
		} catch (e) {
			console.error('Failed to send scheduled notification:', id, e);
			updates[`${id}/lastError`] = String(e.message || e);
		}
	}

	const ref = db.ref('scheduled_notifications');
	if (Object.keys(updates).length > 0) await ref.update(updates);
	for (const id of removals) {
		await ref.child(id).remove();
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
	// Fetch displayName for friendlier text
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
