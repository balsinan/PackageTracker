const admin = require("firebase-admin");
const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

admin.initializeApp();

const db = admin.firestore();
const TRACK17_BASE_URL = "https://api.17track.net/track/v2.2";
const track17ApiKey = defineSecret("TRACK17_API_KEY");
const functionOptions = {
  region: "us-central1",
  secrets: [track17ApiKey]
};

function now() {
  return admin.firestore.FieldValue.serverTimestamp();
}

function requireMethod(req, res, method) {
  if (req.method !== method) {
    res.status(405).send("Method not allowed");
    return false;
  }

  return true;
}

function sanitizeTrackingNumber(value) {
  return String(value || "").trim().toUpperCase();
}

function trackingDocumentId(trackingNumber) {
  return sanitizeTrackingNumber(trackingNumber)
    .replace(/[^A-Z0-9_-]/g, "_");
}

function titleForPackage(trackingNumber, title) {
  return title && title.trim() ? title.trim() : trackingNumber;
}

function normalizeStatus(rawStatus, rawSubStatus) {
  const status = String(rawStatus || "").toLowerCase();
  const subStatus = String(rawSubStatus || "").toLowerCase();
  const combined = `${status} ${subStatus}`;

  if (combined.includes("delivered")) {
    return "delivered";
  }

  if (combined.includes("out for delivery")) {
    return "outForDelivery";
  }

  if (combined.includes("failed") || combined.includes("attempt")) {
    return "failedAttempt";
  }

  if (combined.includes("exception") || combined.includes("returned") || combined.includes("undeliverable")) {
    return "exception";
  }

  if (combined.includes("expired")) {
    return "expired";
  }

  if (combined.includes("transit") || combined.includes("pickup") || combined.includes("arrival") || combined.includes("departure")) {
    return "inTransit";
  }

  return "pending";
}

function latestStatusValue(trackInfo) {
  const latestStatus = trackInfo?.latest_status;
  if (latestStatus && typeof latestStatus === "object") {
    return {
      status: latestStatus.status || "",
      subStatus: latestStatus.sub_status || latestStatus.subStatus || ""
    };
  }

  return {
    status: latestStatus || "",
    subStatus: trackInfo?.sub_status || ""
  };
}

function latestEventValue(trackInfo) {
  const latestEvent = trackInfo?.latest_event;
  if (!latestEvent || typeof latestEvent !== "object") {
    return {
      description: typeof latestEvent === "string" ? latestEvent : "",
      location: "",
      time: null,
      id: null
    };
  }

  const address = latestEvent.address || {};
  const locationParts = [
    latestEvent.location,
    address.city,
    address.state,
    address.country
  ].filter(Boolean);

  return {
    description:
      latestEvent.description_translation?.description ||
      latestEvent.description ||
      "",
    location: locationParts.join(", "),
    time: latestEvent.time_utc || latestEvent.time_iso || null,
    id: latestEvent.event_id || latestEvent.time_utc || latestEvent.time_iso || null
  };
}

function asArray(value) {
  if (Array.isArray(value)) {
    return value;
  }

  if (value && typeof value === "object") {
    return Object.values(value);
  }

  return [];
}

function normalizeCheckpoint(checkpoint, index) {
  if (!checkpoint || typeof checkpoint !== "object") {
    return null;
  }

  const address = checkpoint.address || {};

  const message =
    checkpoint.message ||
    checkpoint.description ||
    checkpoint.description_translation?.description ||
    checkpoint.checkpoint_message ||
    checkpoint.details ||
    checkpoint.event ||
    checkpoint.status_description ||
    "Tracking updated";

  const location =
    checkpoint.location ||
    address.city ||
    address.state ||
    address.country ||
    checkpoint.city ||
    checkpoint.state ||
    checkpoint.country ||
    checkpoint.site ||
    "";

  const status =
    checkpoint.status ||
    checkpoint.stage ||
    checkpoint.tag ||
    checkpoint.milestone ||
    checkpoint.event ||
    checkpoint.title ||
    "";

  const subStatus =
    checkpoint.sub_status ||
    checkpoint.subtag ||
    checkpoint.subStatus ||
    checkpoint.action ||
    "";

  const time =
    checkpoint.time_utc ||
    checkpoint.time_iso ||
    checkpoint.checkpoint_time ||
    checkpoint.time ||
    checkpoint.created_at ||
    checkpoint.event_time ||
    checkpoint.date ||
    checkpoint.datetime ||
    null;

  return {
    id: checkpoint.id || checkpoint.key || time || `${index}`,
    status,
    subStatus,
    message,
    location,
    time
  };
}

function extractCheckpoints(trackInfo) {
  const providerEvents = asArray(trackInfo?.tracking?.providers)
    .flatMap((provider) => asArray(provider?.events));
  const sources = [
    trackInfo?.latest_event,
    ...asArray(trackInfo?.checkpoint_statuses),
    ...asArray(trackInfo?.z1),
    ...providerEvents,
    ...asArray(trackInfo?.milestone)
  ];

  const seen = new Set();
  return sources
    .map((checkpoint, index) => normalizeCheckpoint(checkpoint, index))
    .filter(Boolean)
    .filter((checkpoint) => {
      const key = `${checkpoint.id}|${checkpoint.time}|${checkpoint.message}`;
      if (seen.has(key)) {
        return false;
      }
      seen.add(key);
      return true;
    })
    .slice(0, 20);
}

function carrierNameFromTrackInfo(trackInfo, fallback) {
  return (
    trackInfo?.carrier_name ||
    trackInfo?.tracking?.providers?.[0]?.provider?.name ||
    fallback ||
    "Auto-detect pending"
  );
}

function acceptedTrackInfo(response) {
  return response?.data?.accepted?.[0]?.track_info || null;
}

async function fetchTrackInfo({trackingNumber, carrierCode}) {
  const realTimePayload = [{
    number: trackingNumber,
    carrier: carrierCode || undefined,
    cacheLevel: 0
  }];
  const standardPayload = [{
    number: trackingNumber,
    carrier: carrierCode || undefined
  }];

  try {
    const realTimeResponse = await callTrack17("getRealTimeTrackInfo", "POST", realTimePayload);
    const trackInfo = acceptedTrackInfo(realTimeResponse);
    if (trackInfo) {
      return trackInfo;
    }
  } catch (error) {
    console.log("getRealTimeTrackInfo failed", trackingNumber, error.message);
  }

  try {
    const detailsResponse = await callTrack17("gettrackinfo", "POST", standardPayload);
    return acceptedTrackInfo(detailsResponse);
  } catch (error) {
    console.log("gettrackinfo failed", trackingNumber, error.message);
    return null;
  }
}

function buildTrackingSnapshot({trackingNumber, existingData, title, carrierSlug, carrierCode, carrierName, trackInfo}) {
  const checkpoints = extractCheckpoints(trackInfo);
  const latestCheckpoint = checkpoints[0] || null;
  const latestStatus = latestStatusValue(trackInfo);
  const latestEvent = latestEventValue(trackInfo);
  const normalizedStatus = normalizeStatus(
    latestStatus.status || existingData?.rawStatus,
    latestStatus.subStatus || latestCheckpoint?.subStatus || existingData?.rawSubStatus
  );

  const lastUpdate =
    latestEvent.description ||
    latestCheckpoint?.message ||
    existingData?.lastUpdate ||
    "Tracking created.";

  return {
    trackingNumber,
    title: titleForPackage(trackingNumber, title || existingData?.title),
    carrierSlug: carrierSlug || existingData?.carrierSlug || "unknown",
    carrierCode: carrierCode || existingData?.carrierCode || null,
    carrierName: carrierNameFromTrackInfo(trackInfo, carrierName || existingData?.carrierName),
    trackingId: trackInfo?.tracking_id || existingData?.trackingId || null,
    status: normalizedStatus,
    rawStatus: latestStatus.status || existingData?.rawStatus || "",
    rawSubStatus: latestStatus.subStatus || latestCheckpoint?.subStatus || existingData?.rawSubStatus || "",
    lastUpdate,
    lastCheckpointLocation: latestEvent.location || latestCheckpoint?.location || existingData?.lastCheckpointLocation || "",
    lastCheckpointTime: latestEvent.time || latestCheckpoint?.time || existingData?.lastCheckpointTime || null,
    latestEventKey: latestEvent.id || latestCheckpoint?.id || latestCheckpoint?.time || existingData?.latestEventKey || null,
    checkpoints,
    updatedAt: now()
  };
}

function buildClientPackage(trackingData, subscriptionData) {
  return {
    trackingNumber: trackingData.trackingNumber,
    title: subscriptionData?.title || trackingData.title || trackingData.trackingNumber,
    carrierSlug: trackingData.carrierSlug || "unknown",
    carrierName: trackingData.carrierName || "Unknown carrier",
    status: trackingData.status || "pending",
    lastUpdate: trackingData.lastUpdate || "Tracking created.",
    trackingId: trackingData.trackingId || null,
    checkpoints: Array.isArray(trackingData.checkpoints) ? trackingData.checkpoints : []
  };
}

async function callTrack17(path, method, body) {
  const apiKey = track17ApiKey.value();

  if (!apiKey) {
    throw new Error("TRACK17_API_KEY is missing in Firebase Functions environment.");
  }

  const response = await fetch(`${TRACK17_BASE_URL}/${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      "17token": apiKey
    },
    body: body ? JSON.stringify(body) : undefined
  });

  const data = await response.json();

  if (!response.ok) {
    throw new Error(JSON.stringify(data));
  }

  return data;
}

async function upsertInstallationRecord({installationId, fcmToken, notificationsEnabled, platform}) {
  await db.collection("installations").doc(installationId).set({
    installationId,
    fcmToken: fcmToken || null,
    notificationsEnabled: notificationsEnabled !== false,
    platform: platform || "ios",
    updatedAt: now()
  }, { merge: true });
}

async function subscribeInstallationToTracking({installationId, trackingId, trackingNumber, title, carrierSlug}) {
  const subscriptionPayload = {
    installationId,
    trackingNumber,
    title: titleForPackage(trackingNumber, title),
    carrierSlug: carrierSlug || "unknown",
    updatedAt: now()
  };

  await Promise.all([
    db.collection("trackings").doc(trackingId).collection("subscribers").doc(installationId).set(subscriptionPayload, { merge: true }),
    db.collection("installations").doc(installationId).collection("trackings").doc(trackingId).set(subscriptionPayload, { merge: true })
  ]);
}

async function loadInstallationSubscription(installationId, trackingId) {
  const snapshot = await db.collection("installations").doc(installationId).collection("trackings").doc(trackingId).get();
  return snapshot.exists ? snapshot.data() : null;
}

function webhookEventsFromBody(body) {
  if (Array.isArray(body)) {
    return body;
  }

  if (Array.isArray(body?.data)) {
    return body.data;
  }

  if (body?.data && typeof body.data === "object") {
    return [body.data];
  }

  if (body && typeof body === "object") {
    return [body];
  }

  return [];
}

function summarizeWebhookPayload(body) {
  const firstEvent = webhookEventsFromBody(body)[0] || {};
  const firstTrackInfo = firstEvent?.track_info || firstEvent;

  return {
    bodyType: Array.isArray(body) ? "array" : typeof body,
    topLevelKeys: body && typeof body === "object" && !Array.isArray(body) ? Object.keys(body).slice(0, 20) : [],
    eventCount: webhookEventsFromBody(body).length,
    eventKeys: firstEvent && typeof firstEvent === "object" ? Object.keys(firstEvent).slice(0, 20) : [],
    trackInfoKeys: firstTrackInfo && typeof firstTrackInfo === "object" ? Object.keys(firstTrackInfo).slice(0, 20) : [],
    trackingNumberCandidates: {
      eventNumber: firstEvent?.number || null,
      eventTrackNumber: firstEvent?.tracking_number || null,
      trackInfoNumber: firstTrackInfo?.number || null,
      trackInfoTrackingNumber: firstTrackInfo?.tracking_number || null
    }
  };
}

function buildPushMessage(trackingData, subscriptionData) {
  const title = subscriptionData?.title || trackingData.title || trackingData.trackingNumber;
  const locationSuffix = trackingData.lastCheckpointLocation
    ? ` in ${trackingData.lastCheckpointLocation}`
    : "";

  switch (trackingData.status) {
    case "delivered":
      return {
        title: `${title} delivered`,
        body: trackingData.lastUpdate || `Your package has been delivered${locationSuffix}.`
      };
    case "outForDelivery":
      return {
        title: `${title} is arriving today`,
        body: trackingData.lastUpdate || `Out for delivery${locationSuffix}.`
      };
    case "failedAttempt":
      return {
        title: `${title} delivery attempt failed`,
        body: trackingData.lastUpdate || `The courier could not complete delivery${locationSuffix}.`
      };
    case "exception":
      return {
        title: `${title} needs attention`,
        body: trackingData.lastUpdate || `There is an exception on this shipment${locationSuffix}.`
      };
    case "inTransit":
      return {
        title: `${title} is moving`,
        body: trackingData.lastUpdate || `The shipment is still in transit${locationSuffix}.`
      };
    default:
      return {
        title: `${title} updated`,
        body: trackingData.lastUpdate || `Tracking status changed${locationSuffix}.`
      };
  }
}

async function pushTrackingUpdateToSubscribers(trackingId, trackingData, previousData) {
  const statusChanged = previousData?.status !== trackingData.status;
  const eventChanged = previousData?.latestEventKey !== trackingData.latestEventKey;

  if (!statusChanged && !eventChanged) {
    return;
  }

  const subscribersSnapshot = await db.collection("trackings").doc(trackingId).collection("subscribers").get();
  if (subscribersSnapshot.empty) {
    return;
  }

  const tokens = [];
  const tokenToSubscription = new Map();

  for (const subscriberDoc of subscribersSnapshot.docs) {
    const subscriptionData = subscriberDoc.data();
    const installationSnapshot = await db.collection("installations").doc(subscriberDoc.id).get();
    if (!installationSnapshot.exists) {
      continue;
    }

    const installationData = installationSnapshot.data();
    if (!installationData?.notificationsEnabled || !installationData?.fcmToken) {
      continue;
    }

    tokens.push(installationData.fcmToken);
    tokenToSubscription.set(installationData.fcmToken, subscriptionData);
  }

  if (!tokens.length) {
    return;
  }

  const multicastMessages = tokens.map((token) => {
    const subscriptionData = tokenToSubscription.get(token);
    const push = buildPushMessage(trackingData, subscriptionData);

    return {
      token,
      notification: push,
      data: {
        trackingNumber: trackingData.trackingNumber,
        trackingId
      }
    };
  });

  await Promise.all(multicastMessages.map((message) => admin.messaging().send(message)));
}

exports.upsertInstallation = onRequest(functionOptions, async (req, res) => {
  try {
    if (!requireMethod(req, res, "POST")) {
      return;
    }

    const {installationId, fcmToken, notificationsEnabled, platform} = req.body || {};
    if (!installationId) {
      res.status(400).send("installationId is required");
      return;
    }

    await upsertInstallationRecord({installationId, fcmToken, notificationsEnabled, platform});
    res.json({ok: true});
  } catch (error) {
    res.status(500).send(error.message);
  }
});

exports.registerTracking = onRequest(functionOptions, async (req, res) => {
  try {
    if (!requireMethod(req, res, "POST")) {
      return;
    }

    const {trackingNumber: rawTrackingNumber, title, carrierSlug, carrierCode, installationId} = req.body || {};
    const trackingNumber = sanitizeTrackingNumber(rawTrackingNumber);

    if (!trackingNumber || !installationId) {
      res.status(400).send("trackingNumber and installationId are required");
      return;
    }

    const trackingId = trackingDocumentId(trackingNumber);
    const trackingRef = db.collection("trackings").doc(trackingId);
    const existingSnapshot = await trackingRef.get();
    const existingData = existingSnapshot.exists ? existingSnapshot.data() : null;

    await upsertInstallationRecord({
      installationId,
      fcmToken: null,
      notificationsEnabled: true,
      platform: "ios"
    });

    let trackInfo = null;
    let resolvedCarrierCode = carrierCode || existingData?.carrierCode || null;
    let carrierName = existingData?.carrierName || "Auto-detect pending";

    if (!existingData?.trackingId) {
      const response = await callTrack17("register", "POST", [
        {
          number: trackingNumber,
          carrier: resolvedCarrierCode || undefined
        }
      ]);

      const acceptedItem = response?.data?.accepted?.[0] || {};
      trackInfo = acceptedItem?.track_info || null;
      resolvedCarrierCode = acceptedItem?.carrier || resolvedCarrierCode;
      carrierName = trackInfo?.carrier_name || carrierName;
    }

    const freshTrackInfo = await fetchTrackInfo({
      trackingNumber,
      carrierCode: resolvedCarrierCode
    });
    trackInfo = freshTrackInfo || trackInfo;

    const trackingPayload = buildTrackingSnapshot({
      trackingNumber,
      existingData,
      title,
      carrierSlug,
      carrierCode: resolvedCarrierCode,
      carrierName,
      trackInfo
    });

    await trackingRef.set({
      ...trackingPayload,
      registeredAt: existingData?.registeredAt || now()
    }, { merge: true });

    await subscribeInstallationToTracking({
      installationId,
      trackingId,
      trackingNumber,
      title,
      carrierSlug: trackingPayload.carrierSlug
    });

    const subscriptionData = await loadInstallationSubscription(installationId, trackingId);
    res.json(buildClientPackage(trackingPayload, subscriptionData));
  } catch (error) {
    res.status(500).send(error.message);
  }
});

exports.getTrackingStatus = onRequest(functionOptions, async (req, res) => {
  try {
    if (!requireMethod(req, res, "GET")) {
      return;
    }

    const trackingNumber = sanitizeTrackingNumber(req.query.trackingNumber);
    const installationId = String(req.query.installationId || "");
    const trackingId = trackingDocumentId(trackingNumber);

    if (!trackingNumber) {
      res.status(400).send("trackingNumber is required");
      return;
    }

    const trackingSnapshot = await db.collection("trackings").doc(trackingId).get();
    if (!trackingSnapshot.exists) {
      res.status(404).send("Tracking not found");
      return;
    }

    const trackingData = trackingSnapshot.data();
    const freshTrackInfo = await fetchTrackInfo({
      trackingNumber,
      carrierCode: trackingData?.carrierCode
    });
    const latestTrackingData = freshTrackInfo
      ? buildTrackingSnapshot({
        trackingNumber,
        existingData: trackingData,
        title: trackingData?.title,
        carrierSlug: trackingData?.carrierSlug,
        carrierCode: trackingData?.carrierCode,
        carrierName: trackingData?.carrierName,
        trackInfo: freshTrackInfo
      })
      : trackingData;

    if (freshTrackInfo) {
      await db.collection("trackings").doc(trackingId).set(latestTrackingData, {merge: true});
    }
    const subscriptionData = installationId
      ? await loadInstallationSubscription(installationId, trackingId)
      : null;

    res.json(buildClientPackage(latestTrackingData, subscriptionData));
  } catch (error) {
    res.status(500).send(error.message);
  }
});

exports.listInstallationTrackings = onRequest(functionOptions, async (req, res) => {
  try {
    if (!requireMethod(req, res, "GET")) {
      return;
    }

    const installationId = String(req.query.installationId || "");
    if (!installationId) {
      res.status(400).send("installationId is required");
      return;
    }

    const subscriptionsSnapshot = await db.collection("installations").doc(installationId).collection("trackings").get();
    const packages = [];

    for (const subscriptionDoc of subscriptionsSnapshot.docs) {
      const trackingId = subscriptionDoc.id;
      const trackingSnapshot = await db.collection("trackings").doc(trackingId).get();
      if (!trackingSnapshot.exists) {
        continue;
      }

      packages.push(buildClientPackage(trackingSnapshot.data(), subscriptionDoc.data()));
    }

    res.json({packages});
  } catch (error) {
    res.status(500).send(error.message);
  }
});

exports.stopTracking = onRequest(functionOptions, async (req, res) => {
  try {
    if (!requireMethod(req, res, "POST")) {
      return;
    }

    const trackingNumber = sanitizeTrackingNumber(req.body?.trackingNumber);
    const installationId = String(req.body?.installationId || "");
    const trackingId = trackingDocumentId(trackingNumber);

    if (!trackingNumber || !installationId) {
      res.status(400).send("trackingNumber and installationId are required");
      return;
    }

    await Promise.all([
      db.collection("trackings").doc(trackingId).collection("subscribers").doc(installationId).delete(),
      db.collection("installations").doc(installationId).collection("trackings").doc(trackingId).delete()
    ]);

    res.json({ok: true});
  } catch (error) {
    res.status(500).send(error.message);
  }
});

exports.onTrackingWebhook = onRequest(functionOptions, async (req, res) => {
  try {
    if (!requireMethod(req, res, "POST")) {
      return;
    }

    console.log("webhook_summary", JSON.stringify(summarizeWebhookPayload(req.body)));

    const updates = webhookEventsFromBody(req.body);

    for (const update of updates) {
      const trackInfo = update?.track_info || update;
      const trackingNumber = sanitizeTrackingNumber(
        update?.number ||
        trackInfo?.tracking_number ||
        trackInfo?.number
      );

      if (!trackingNumber) {
        continue;
      }

      const trackingId = trackingDocumentId(trackingNumber);
      const trackingRef = db.collection("trackings").doc(trackingId);
      const snapshot = await trackingRef.get();

      if (!snapshot.exists) {
        continue;
      }

      const previousData = snapshot.data();
      const trackingPayload = buildTrackingSnapshot({
        trackingNumber,
        existingData: previousData,
        title: previousData?.title,
        carrierSlug: previousData?.carrierSlug,
        carrierName: trackInfo?.carrier_name || previousData?.carrierName,
        trackInfo
      });

      await trackingRef.set({
        ...trackingPayload,
        lastWebhookAt: now()
      }, { merge: true });

      await pushTrackingUpdateToSubscribers(trackingId, trackingPayload, previousData);
    }

    res.json({ok: true});
  } catch (error) {
    res.status(500).send(error.message);
  }
});
