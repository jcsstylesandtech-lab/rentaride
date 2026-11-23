# Rent A Ride

**Your Ride. Your Destination. Your Choice.**

Ride-hailing platform for Nigeria (then wider Africa): passenger app, driver
app and web admin dashboard, with both fixed fares and inDrive-style fare
negotiation.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full architecture.

## Repository layout

| Path | What | Status |
|------|------|--------|
| `packages/rar_design_system` | Shared Flutter design system (tokens, theme, glass components, Poppins) | ✅ |
| `apps/passenger_app` | Passenger Flutter app (iOS / Android) | 🚧 Welcome, auth, map home, messages, profile (demo data) |
| `apps/admin_dashboard` | Next.js + Tailwind admin console on Supabase | 🚧 Overview, driver verification, passengers, rides, payments, SOS, support chats, staff access, audit log |
| `supabase/migrations` | Database schema (PostgreSQL + PostGIS, row-level security) | ✅ Applied to the Supabase project |
| `apps/driver_app` | Driver Flutter app | Next |

## Run

**Passenger app** (macOS 13 needs Flutter 3.38):

```bash
cd apps/passenger_app
cp ios/Flutter/Secrets.example.xcconfig ios/Flutter/Secrets.xcconfig   # then add Google keys (docs/GOOGLE_SETUP.md)
flutter run
```

**Admin dashboard:**

```bash
cd apps/admin_dashboard
cp .env.example .env.local   # Supabase URL + publishable key
npm install
npm run dev                  # http://localhost:3000
```

Staff sign up on the dashboard's sign-in page; a super admin then grants a role
under **Staff & access** (Super admin, Operations, Verifier, Support, Finance).
The database enforces each role's permissions.

## Secrets

Never commit `ios/Flutter/Secrets.xcconfig`, `.env.local` or any Supabase
service-role key. Apps only ever use the public (publishable) key; payments and
wallet changes are written by the backend.

## Requirements

* Flutter **3.50+** (Dart 3.14). Material widgets come from the
  `material_ui` package, which replaced the old in-SDK
  `package:flutter/material.dart` in Flutter 3.47+.
* Android Studio / Android SDK for Android builds, Xcode for iOS builds.

## Run the passenger app

```bash
cd apps/passenger_app
flutter pub get
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

## Test

```bash
(cd packages/rar_design_system && flutter test)
(cd apps/passenger_app && flutter test)
```

Screenshots of the current UI are in [docs/screenshots](docs/screenshots).

## Secrets

Never commit secrets. Mobile apps receive only public configuration via
`--dart-define`; payment provider secret keys, JWT secrets and database
credentials will live in the backend's environment (see `.env.example` once the
backend lands in Phase 3).
