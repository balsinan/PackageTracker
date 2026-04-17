# Firebase Backend Overview

This backend sits between the iOS app and 17TRACK.

## Why the backend exists

- Keeps the `TRACK17_API_KEY` off the device
- Normalizes 17TRACK statuses into app statuses like `pending`, `inTransit`, `outForDelivery`, `delivered`
- Stores tracking state so the app can read cached shipment data quickly
- Supports more than one device subscribing to the same tracking number
- Sends push notifications only to subscribed installations when a webhook changes the shipment state

## Firestore structure

```text
installations/{installationId}
  installationId
  fcmToken
  notificationsEnabled
  platform
  updatedAt

installations/{installationId}/trackings/{trackingId}
  trackingNumber
  title
  carrierSlug
  updatedAt

trackings/{trackingId}
  trackingNumber
  title
  carrierSlug
  carrierName
  trackingId
  status
  rawStatus
  rawSubStatus
  lastUpdate
  latestEventKey
  checkpoints[]
  updatedAt
  lastWebhookAt

trackings/{trackingId}/subscribers/{installationId}
  installationId
  title
  updatedAt
```

## Functions

- `upsertInstallation`
  Saves the installation id, FCM token, and notification preference.

- `registerTracking`
  Registers a tracking number with 17TRACK if needed, stores normalized tracking data, and subscribes the current installation to it.

- `getTrackingStatus`
  Returns the latest cached tracking state for the app.

- `listInstallationTrackings`
  Returns all tracking items subscribed by one installation.

- `stopTracking`
  Removes one installation from one tracking subscription.

- `onTrackingWebhook`
  Accepts 17TRACK webhook updates, updates Firestore, compares previous vs new state, and pushes notifications to relevant subscribers.

## Push flow

```text
17TRACK webhook -> Firebase Function -> update Firestore -> look up subscribers -> send FCM push
```

Push is sent when:

- normalized status changed, or
- latest event/checkpoint changed

## Required setup later

Before deploying, set:

- `TRACK17_API_KEY`

And after deploy, put the function base URL into the app:

- `FUNCTIONS_BASE_URL` in `PackageTracker/Info.plist`
