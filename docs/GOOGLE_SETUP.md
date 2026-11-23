# Google setup: sign-in and maps (iOS)

You need **two things** from Google, both free to create:

| Feature | What you need | Where it goes |
|---|---|---|
| Continue with Google | iOS OAuth client ID (+ its "iOS URL scheme") | `GOOGLE_IOS_CLIENT_ID`, `GOOGLE_REVERSED_CLIENT_ID` |
| Map inside the app | Maps SDK for iOS API key | `GOOGLE_MAPS_API_KEY` |

All three go in `apps/passenger_app/ios/Flutter/Secrets.xcconfig`.
Keep that file private: never share it or upload it to GitHub.

"Directions in Google Maps" (the button that opens the Google Maps app)
needs **no** key and already works.

App bundle ID: **`ng.rentaride.rentARidePassenger`**

---

## 1. Create a Google Cloud project

1. Go to https://console.cloud.google.com and sign in.
2. Top bar → project picker → **New project** → name it `Rent A Ride` → **Create**.
3. Make sure the new project is selected in the top bar.

## 2. Maps key (map inside the app)

1. Menu → **APIs & Services → Library** → search **Maps SDK for iOS** → **Enable**.
   (Google asks you to set up billing. Google Maps has a monthly free
   allowance; set a budget alert under **Billing → Budgets & alerts**.)
2. **APIs & Services → Credentials → Create credentials → API key.** Copy it.
3. Click the new key → **Application restrictions: iOS apps** → add
   `ng.rentaride.rentARidePassenger`.
   **API restrictions: Restrict key** → tick **Maps SDK for iOS** → **Save**.
4. Put it in `Secrets.xcconfig`:
   ```
   GOOGLE_MAPS_API_KEY = AIza...your key...
   ```

## 3. Google sign-in (Continue with Google)

1. **APIs & Services → OAuth consent screen** (or "Google Auth Platform"):
   app name `Rent A Ride`, your support email, **External** audience.
   While testing, add your own Gmail under **Test users**.
2. **Credentials → Create credentials → OAuth client ID**
   → Application type **iOS** → Bundle ID `ng.rentaride.rentARidePassenger`
   → **Create**.
3. Google shows a **Client ID** and an **iOS URL scheme**. Put both in
   `Secrets.xcconfig`:
   ```
   GOOGLE_IOS_CLIENT_ID = 1234567890-abc123.apps.googleusercontent.com
   GOOGLE_REVERSED_CLIENT_ID = com.googleusercontent.apps.1234567890-abc123
   ```

## 4. Run

```bash
cd ~/Downloads/rent-a-ride/apps/passenger_app
~/flutter-3.38/flutter/bin/flutter run
```

Stop and re-run after editing `Secrets.xcconfig` (a hot reload is not enough).

## Before going live

* The backend (Phase 3) must **verify the Google ID token** with Google
  before trusting the email. The demo app does not.
* Create separate keys for Android (and restrict them to the Android
  package and signing certificate) when the Android app is set up.
