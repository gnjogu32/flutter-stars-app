/**
 * Starpage – Firebase Cloud Functions
 *
 * Listens to every new document written to
 *   notifications/{userId}/userNotifications/{notificationId}
 * and delivers a push notification to the recipient's registered FCM token.
 *
 * Notification type → push text mapping:
 *   follow          → "X started following you"
 *   like_post       → "X liked your post"
 *   comment         → "X commented: …"
 *   mention_followers → "X mentioned all followers: …"
 *   message         → "X sent you a message"
 */

const functions = require('firebase-functions/v1');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

// ─── helpers ────────────────────────────────────────────────────────────────

/**
 * Build a human-readable push title + body from a notification document.
 * @param {object} data – Firestore notification document fields
 * @returns {{ title: string, body: string }}
 */
function buildPushText(data) {
  const actor = data.triggeredByName || 'Someone';
  const type  = data.type || '';

  switch (type) {
    case 'follow':
      return {
        title: 'New Follower',
        body: `${actor} started following you.`,
      };
    case 'like_post':
      return {
        title: 'New Like',
        body: `${actor} liked your post.`,
      };
    case 'comment': {
      const snippet = (data.content || '').substring(0, 80);
      return {
        title: 'New Comment',
        body: `${actor} commented: ${snippet}`,
      };
    }
    case 'mention_followers': {
      const snippet = (data.content || '').substring(0, 80);
      return {
        title: 'Mentioned Followers',
        body: `${actor}: ${snippet}`,
      };
    }
    case 'message': {
      const snippet = (data.content || '').substring(0, 80);
      return {
        title: `Message from ${actor}`,
        body: snippet || 'You have a new message.',
      };
    }
    default:
      return {
        title: 'Starpage',
        body: data.content || 'You have a new notification.',
      };
  }
}

// ─── Cloud Function ──────────────────────────────────────────────────────────

exports.sendPushOnNotification = functions.firestore
  .document('notifications/{userId}/userNotifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const userId = context.params.userId;
    const notificationId = context.params.notificationId;
    const data = snap.data();

    if (!data) {
      console.warn(`[FCM] empty doc ${notificationId} for user ${userId}`);
      return null;
    }

    // 1. Fetch the recipient's FCM token
    const userSnap = await getFirestore().collection('users').doc(userId).get();
    if (!userSnap.exists) {
      console.warn(`[FCM] user doc not found: ${userId}`);
      return null;
    }

    const fcmToken = userSnap.data()?.fcmToken;
    if (!fcmToken) {
      console.log(`[FCM] no token for user ${userId} – skipping`);
      return null;
    }

    // 2. Build push payload
    const { title, body } = buildPushText(data);

    const message = {
      token: fcmToken,
      notification: { title, body },
      data: {
        type:        data.type        || '',
        postId:      data.postId      || '',
        senderId:    data.triggeredBy || '',
        notificationId,
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'starpage_notifications',
          icon: 'ic_launcher',
          color: '#673AB7',
          clickAction: 'FLUTTER_NOTIFICATION_CLICK',
        },
      },
      apns: {
        payload: {
          aps: {
            badge: 1,
            sound: 'default',
          },
        },
      },
    };

    // 3. Send
    try {
      const response = await getMessaging().send(message);
      console.log(`[FCM] sent ${notificationId} → ${userId}: ${response}`);
      return response;
    } catch (err) {
      // Token invalid / unregistered – clean it up so we don't retry
      if (
        err.code === 'messaging/invalid-registration-token' ||
        err.code === 'messaging/registration-token-not-registered'
      ) {
        console.warn(`[FCM] stale token for ${userId} – removing`);
        await getFirestore()
          .collection('users')
          .doc(userId)
          .update({ fcmToken: FieldValue.delete() });
      } else {
        console.error(`[FCM] send error for ${userId}:`, err);
      }
      return null;
    }
  });
