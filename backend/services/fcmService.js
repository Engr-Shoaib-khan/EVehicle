const { initializeApp, cert, getApps } = require("firebase-admin/app");
const { getMessaging }                  = require("firebase-admin/messaging");

// ── Lazy-init Firebase Admin (singleton) ─────────────────────────
const getFirebaseApp = () => {
  if (getApps().length > 0) return getApps()[0];

  const key = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;
  if (!key) {
    console.warn("[FCM] FIREBASE_SERVICE_ACCOUNT_KEY not set — push notifications disabled.");
    return null;
  }

  let serviceAccount;
  try {
    serviceAccount = JSON.parse(key);
  } catch {
    console.error("[FCM] Failed to parse FIREBASE_SERVICE_ACCOUNT_KEY — must be valid JSON.");
    return null;
  }

  return initializeApp({ credential: cert(serviceAccount) });
};

// ── Send single FCM notification ─────────────────────────────────
const sendPushNotification = async ({ fcmToken, title, body, data = {} }) => {
  if (!fcmToken) return;
  const app = getFirebaseApp();
  if (!app) return;

  try {
    const message = {
      token: fcmToken,
      notification: { title, body },
      data:  Object.fromEntries(
        Object.entries(data).map(([k, v]) => [k, String(v)])
      ),
      android: {
        priority:     "high",
        notification: {
          sound:       "default",
          channelId:   "ev_ride_rides",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      apns: {
        payload: { aps: { sound: "default", badge: 1 } },
        headers: { "apns-priority": "10" },
      },
    };

    const response = await getMessaging(app).send(message);
    console.log(`[FCM] Sent to ${fcmToken.substring(0, 12)}… | msgId: ${response}`);
    return response;
  } catch (err) {
    // Stale/invalid token — log but don't crash the ride request flow
    console.error(`[FCM] Push failed for token ${fcmToken.substring(0, 12)}…: ${err.message}`);
  }
};

// ── Send to multiple drivers (batch) ─────────────────────────────
const sendBatchPushNotifications = async (drivers, title, body, data = {}) => {
  const app = getFirebaseApp();
  if (!app) return;

  const tokens = drivers
    .map((d) => d.fcmToken)
    .filter(Boolean);

  if (tokens.length === 0) return;

  const messages = tokens.map((token) => ({
    token,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([k, v]) => [k, String(v)])
    ),
    android: {
      priority:     "high",
      notification: { sound: "default", channelId: "ev_ride_rides" },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
      headers: { "apns-priority": "10" },
    },
  }));

  try {
    // sendEachForMulticast — replaces deprecated sendMulticast
    const res = await getMessaging(app).sendEach(messages);
    console.log(`[FCM] Batch: ${res.successCount} sent, ${res.failureCount} failed.`);
    return res;
  } catch (err) {
    console.error("[FCM] Batch send error:", err.message);
  }
};

// ── Notify drivers of new ride request ────────────────────────────
const notifyDriversOfNewRide = async (drivers, ride) => {
  const fare  = ride.fare?.estimated ?? 0;
  const dist  = ride.distanceKm ?? 0;

  await sendBatchPushNotifications(
    drivers,
    "⚡ New Ride Request!",
    `Rs. ${fare} · ${parseFloat(dist).toFixed(1)} km — Tap to accept`,
    {
      type:          "new_ride_request",
      rideId:        ride._id.toString(),
      fare:          String(fare),
      distanceKm:    String(dist),
      vehicleTypeId: ride.vehicleTypeId ?? "ev_bike",
    }
  );
};

module.exports = {
  sendPushNotification,
  sendBatchPushNotifications,
  notifyDriversOfNewRide,
};
