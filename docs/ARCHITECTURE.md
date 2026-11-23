# Rent A Ride — Architecture

> Your Ride. Your Destination. Your Choice.

This document describes how the Rent A Ride platform is organised. It is the
reference for every phase of development; update it when a decision changes.

## 1. System overview

```
 ┌──────────────────┐   ┌──────────────────┐   ┌──────────────────────┐
 │ Passenger app    │   │ Driver app       │   │ Admin dashboard      │
 │ Flutter (iOS/And)│   │ Flutter (iOS/And)│   │ Next.js + Tailwind   │
 └───────┬──────────┘   └───────┬──────────┘   └──────────┬───────────┘
         │  HTTPS (REST, JWT)   │                         │
         │  WSS (Socket.IO)     │                         │
         └──────────────┬───────┴─────────────────────────┘
                        ▼
              ┌───────────────────┐        ┌─────────────────────┐
              │ Nginx (TLS, rate  │        │ FCM (push)          │
              │ limiting, WS)     │        │ Google Maps Platform│
              └────────┬──────────┘        │ Paystack/Flutterwave│
                       ▼                   └──────────▲──────────┘
              ┌───────────────────┐                   │
              │ NestJS API        │───────────────────┘
              │  modules: auth,   │
              │  users, drivers,  │◀──── Redis (socket adapter, geo
              │  rides, fares,    │       cache of online drivers,
              │  payments, wallet │       rate limits, OTP)
              │  admin, notif...  │
              └────────┬──────────┘
                       ▼
              ┌───────────────────┐
              │ PostgreSQL+PostGIS│
              └───────────────────┘
```

* **Mobile apps** never talk to payment providers or hold secrets. They
  call the backend, which initialises transactions and verifies webhooks.
* **Real-time**: Socket.IO namespaces `/passenger`, `/driver`, `/admin`.
  Rooms per ride (`ride:<id>`) carry location updates, fare offers and status
  changes. Redis adapter allows horizontal scaling.
* **Driver matching**: online drivers publish location every 3–5 s; the
  latest position is kept in Redis GEO for nearest-driver queries, and
  persisted to PostGIS at a lower rate for history and analytics.

## 2. Repository layout (monorepo)

```
rent-a-ride/
├── apps/
│   ├── passenger_app/          Flutter — rider experience (Phase 1)
│   ├── driver_app/             Flutter — partner experience (Phase 2)
│   └── admin_dashboard/        Next.js + Tailwind (Phase 4)
├── packages/
│   └── rar_design_system/      Shared Flutter design system (tokens,
│                               theme, glass components, logo, fonts)
├── backend/                    NestJS API + Socket.IO gateway (Phase 3)
├── infra/                      Docker Compose, Nginx, deployment (Phase 5)
└── docs/                       Architecture, design system, decisions
```

Both Flutter apps depend on `rar_design_system` via a path dependency, so the
blue glassmorphism identity is defined once and cannot drift between apps.

## 3. Flutter app architecture

Feature-first clean architecture. Each feature owns its layers:

```
lib/
├── main.dart                   Entry point (ProviderScope + App)
├── app/
│   ├── app.dart                MaterialApp.router, theme, text-scale clamp
│   └── router/                 go_router configuration and route names
├── core/
│   ├── config/                 AppConfig from --dart-define (no secrets)
│   ├── network/                (Phase 3) Dio client, interceptors, errors
│   └── utils/
└── features/
    └── <feature>/
        ├── domain/             Entities, repository interfaces, use cases
        ├── data/               DTOs, data sources, repository impls
        └── presentation/
            ├── controllers/    Riverpod notifiers / providers
            ├── screens/        Route-level widgets
            └── widgets/        Feature-specific widgets
```

| Concern          | Choice                                   |
|------------------|------------------------------------------|
| State management | Riverpod                                 |
| Navigation       | go_router (typed route names, deep links)|
| Networking       | Dio + retry/backoff (Phase 3)            |
| Local storage    | flutter_secure_storage (tokens), shared_preferences (flags) |
| Maps             | google_maps_flutter                      |
| Real-time        | socket_io_client                         |
| Push             | firebase_messaging                       |

### Rules
* Widgets never call HTTP directly; they go through controllers → repositories.
* No hard-coded secrets. Public, non-secret config (API base URL, Maps key
  restricted by app signature) is passed with `--dart-define`; anything
  secret lives only on the backend in environment variables.
* Every interactive element has an action, a disabled state, and semantics.

## 4. Design system (`packages/rar_design_system`)

| Token group | File |
|-------------|------|
| Colours (`#061B49` navy, `#0866FF` royal, `#00C8FF` cyan, `#FFFFFF`) | `tokens/rar_colors.dart` |
| Typography (Poppins 400/500/600/700/800, bundled offline) | `tokens/rar_typography.dart` |
| Spacing, radii | `tokens/rar_spacing.dart` |
| Shadows, gradients, motion | `tokens/rar_effects.dart` |
| Theme (dark "glass" + light) | `theme/rar_theme.dart` |

Components: `GlassContainer`, `RarButton` (primary / glass / text, loading),
`RarLogo`, `RarWordmark`, `FeatureTile`, `PillBadge`, `PageDots`, `IconTile`,
`RarResponsive` helpers, and skeleton loaders (`RarShimmer`, `SkeletonBox`,
`SkeletonLine`, `SkeletonCircle`, `SkeletonListTile`, `SkeletonPostCard`,
`SkeletonList`, `RarSkeletonSwitcher`).

**Loading rule:** when the shape of incoming content is known (lists,
cards, profiles, fares, history), show skeleton placeholders, never a
full-screen spinner. Spinners are only for in-button actions. Preview all
loading states in dev builds at `/dev/loading-states`.

Brand assets (logo, lockups, app icons) live in `brand/`.

Fonts are bundled rather than fetched at runtime so first launch works on a
slow or offline Nigerian mobile connection.

Glass blur (`BackdropFilter`) is expensive on low-end Android devices.
`GlassContainer` reads `RarGlassSettings` so blur can be reduced or disabled
globally (e.g. when the OS "reduce motion / battery saver" flag is on) while
keeping the translucent look.

## 5. Backend (Phase 3, planned)

NestJS modules: `auth` (phone OTP, email, JWT access/refresh, social),
`users`, `passengers`, `drivers` (documents, verification), `vehicles`,
`rides` (requests, trips, state machine), `fares` (pricing rules, fixed
quote, negotiation engine), `realtime` (Socket.IO gateway), `payments`
(Paystack, Flutterwave, webhooks), `wallet` (ledger, withdrawals),
`ratings`, `notifications` (FCM), `complaints`, `admin`, `settings`.

Validation with `class-validator` DTOs on every endpoint; Prisma or TypeORM
migrations against PostgreSQL + PostGIS (`geography(Point,4326)` columns with
GIST indexes for pickup/driver locations). Money stored as integer kobo.

## 6. Phases

1. **Design system & passenger UI** — tokens, theme, welcome/onboarding ✅,
   authentication, home dashboard, booking screens.
2. Driver app.
3. Backend, real-time, negotiation engine.
4. Payments, wallet, admin dashboard.
5. Testing, hardening, store builds, deployment.
