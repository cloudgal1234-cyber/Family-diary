/**
 * cloud_functions.js — Firebase Cloud Functions
 * שרת ה-Backend: שליחת Push Notifications ועיבוד אירועים
 *
 * פרויקט: Family Diary
 * לפריסה: firebase deploy --only functions
 */

const functions = require('firebase-functions');
const admin     = require('firebase-admin');

admin.initializeApp();
const db = admin.database();

// ============================================================
// TRIGGER: שינוי סטטוס אירוע → שלח Push Notification לכל המשפחה
// ============================================================
exports.onEventStatusChanged = functions.database
  .ref('/families/{familyId}/events/{eventId}/status')
  .onUpdate(async (change, context) => {
    const { familyId, eventId } = context.params;
    const newStatus  = change.after.val();
    const prevStatus = change.before.val();

    if (newStatus === prevStatus) return null;

    // קרא פרטי האירוע
    const eventSnap = await db.ref(`families/${familyId}/events/${eventId}`).get();
    if (!eventSnap.exists()) return null;
    const event = eventSnap.val();

    // קרא את הטוקנים של כל בני המשפחה
    const usersSnap = await db.ref(`families/${familyId}/users`).get();
    const tokens    = [];
    usersSnap.forEach(userSnap => {
      const user = userSnap.val();
      if (user.fcm_token && user.id !== event.updated_by) {
        tokens.push(user.fcm_token);
      }
    });

    if (tokens.length === 0) return null;

    // בנה הודעה לפי סטטוס
    const { title, body, icon } = buildNotificationContent(newStatus, event);

    const message = {
      tokens,
      notification: { title, body },
      android: {
        priority: 'high',
        notification: {
          channelId: 'hot_updates',
          color:     getStatusColor(newStatus),
          icon:      icon,
          sound:     'default',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
      data: {
        type:      `EVENT_${newStatus}`,
        family_id: familyId,
        event_id:  eventId,
        title:     event.title || '',
      },
    };

    try {
      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(`Sent ${response.successCount}/${tokens.length} notifications for event ${eventId}`);

      // נקה טוקנים לא תקינים
      response.responses.forEach((resp, idx) => {
        if (!resp.success &&
            (resp.error.code === 'messaging/invalid-registration-token' ||
             resp.error.code === 'messaging/registration-token-not-registered')) {
          db.ref(`families/${familyId}/users`)
            .orderByChild('fcm_token')
            .equalTo(tokens[idx])
            .once('value', snap => {
              snap.forEach(u => u.ref.child('fcm_token').remove());
            });
        }
      });
    } catch (err) {
      console.error('Error sending notifications:', err);
    }

    return null;
  });

// ============================================================
// TRIGGER: משימה שעומדת לפוג — תזכורת שעה לפני
// ============================================================
exports.sendTaskReminders = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async () => {
    const now        = Date.now();
    const inOneHour  = now + 3600000;
    const in15Min    = now + 900000;

    const familiesSnap = await db.ref('families').get();

    familiesSnap.forEach(familySnap => {
      const familyId = familySnap.key;
      const tasksRef = db.ref(`families/${familyId}/tasks`);

      tasksRef
        .orderByChild('due/timestamp')
        .startAt(in15Min)
        .endAt(inOneHour)
        .get()
        .then(async tasksSnap => {
          if (!tasksSnap.exists()) return;

          const usersSnap = await db.ref(`families/${familyId}/users`).get();
          const userTokenMap = {};
          usersSnap.forEach(u => {
            const ud = u.val();
            if (ud.fcm_token) userTokenMap[ud.id] = ud.fcm_token;
          });

          tasksSnap.forEach(taskSnap => {
            const task = taskSnap.val();
            if (task.status === 'DONE' || task.status === 'SKIPPED') return;

            const token = userTokenMap[task.assigned_to];
            if (!token) return;

            const minutesLeft = Math.round((task.due.timestamp - now) / 60000);
            admin.messaging().send({
              token,
              notification: {
                title: `📚 תזכורת: ${task.title}`,
                body:  `יש להגיש בעוד ${minutesLeft} דקות`,
              },
              data: {
                type:      'TASK_DUE',
                family_id: familyId,
                task_id:   taskSnap.key,
              },
            });
          });
        });
    });

    return null;
  });

// ============================================================
// TRIGGER: ניקוי התראות ישנות (מעל 7 ימים)
// ============================================================
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async () => {
    const cutoff   = Date.now() - 7 * 24 * 3600000;
    const families = await db.ref('families').get();

    families.forEach(familySnap => {
      db.ref(`families/${familySnap.key}/notifications`)
        .orderByChild('created_at')
        .endAt(cutoff)
        .get()
        .then(snap => {
          if (!snap.exists()) return;
          const updates = {};
          snap.forEach(n => { updates[n.key] = null; });
          db.ref(`families/${familySnap.key}/notifications`).update(updates);
        });
    });

    return null;
  });

// ============================================================
// HTTP: קבלת קוד הצטרפות למשפחה
// ============================================================
exports.generateJoinCode = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'נדרשת כניסה');

  const { familyId } = data;

  // בדוק שהמשתמש הוא הורה במשפחה
  const userSnap = await db.ref(`families/${familyId}/users/${context.auth.uid}`).get();
  if (!userSnap.exists() || userSnap.val().role !== 'PARENT') {
    throw new functions.https.HttpsError('permission-denied', 'רק הורים יכולים ליצור קוד הצטרפות');
  }

  const code    = Math.random().toString(36).substring(2, 8).toUpperCase();
  const expires = Date.now() + 24 * 3600000;

  await db.ref(`join_codes/${code}`).set({ familyId, expires, createdBy: context.auth.uid });

  return { code, expires };
});

exports.joinFamily = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError('unauthenticated', 'נדרשת כניסה');

  const { code, name, role } = data;

  const codeSnap = await db.ref(`join_codes/${code}`).get();
  if (!codeSnap.exists()) {
    throw new functions.https.HttpsError('not-found', 'קוד לא תקין');
  }

  const codeData = codeSnap.val();
  if (codeData.expires < Date.now()) {
    throw new functions.https.HttpsError('deadline-exceeded', 'הקוד פג תוקף');
  }

  const { familyId } = codeData;
  await db.ref(`families/${familyId}/users/${context.auth.uid}`).set({
    id:       context.auth.uid,
    name:     name || 'משתמש חדש',
    role:     role || 'CHILD',
    color:    '#4ECDC4',
    family_id: familyId,
  });

  return { familyId };
});

// ============================================================
// עזרים
// ============================================================
function buildNotificationContent(status, event) {
  const title = event.title || 'אירוע';
  switch (status) {
    case 'MOVED':
      return { title: `⏰ ${title} הוזז`, body: event.status_note || 'הזמן השתנה', icon: 'ic_event_moved' };
    case 'CANCELED':
      return { title: `❌ ${title} בוטל`, body: event.status_note || 'האירוע בוטל', icon: 'ic_event_canceled' };
    case 'POSTPONED':
      return { title: `⏩ ${title} נדחה`, body: event.status_note || 'האירוע נדחה', icon: 'ic_event_postponed' };
    case 'RESCHEDULED':
      return { title: `📅 ${title} נקבע מחדש`, body: event.status_note || '', icon: 'ic_event_rescheduled' };
    default:
      return { title: `✅ ${title} — בזמן`, body: '', icon: 'ic_event' };
  }
}

function getStatusColor(status) {
  const colors = {
    MOVED:       '#F39C12',
    CANCELED:    '#E74C3C',
    POSTPONED:   '#9B59B6',
    RESCHEDULED: '#3498DB',
    ON_TIME:     '#2ECC71',
  };
  return colors[status] || '#1A237E';
}
