# SushiScout 26

[![test](https://github.com/SushiSquad7461/SushiScout26/actions/workflows/test.yml/badge.svg)](https://github.com/SushiSquad7461/SushiScout26/actions/workflows/test.yml)

A cross-platform FRC & FTC scouting app built by [SushiSquad 7461](https://github.com/SushiSquad7461). Scouts record match data on any device, even offline, and it syncs automatically to Firestore and Google Sheets for real-time analysis.

## Features

- **Multi-platform** — Windows, macOS, Linux, Android, iOS, and web
- **Offline-first** — Full functionality without internet; syncs when back online
- **FRC + FTC** — Separate scouting forms tailored to each program
- **Team isolation** — server-enforced: every team's events and matches are private to that team, so multiple teams can scout the same competition independently
- **Sheets export** — Each team can connect its own Google Sheet; match data exports one-way from Firestore to that sheet for analysis
- **Schedule import** — Pull match schedules from The Blue Alliance (FRC) and FIRST Events API (FTC)

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Flutter App                     │
│  ┌───────────┐  ┌────────────┐  ┌────────────┐  │
│  │ Scouting  │  │  Dashboard │  │    Auth     │  │
│  │   Forms   │  │  & Stats   │  │  & Teams   │  │
│  └─────┬─────┘  └─────┬──────┘  └─────┬──────┘  │
│        │              │               │          │
│  ┌─────┴──────────────┴───────────────┴──────┐   │
│  │           Firestore Repository            │   │
│  │  (single store; Firestore's own on-disk   │   │
│  │   persistence provides offline support)   │   │
│  └──────────────────────┬───────────────────┘    │
└─────────────────────────┼─────────────────────────┘
                           │
                    ┌──────┴────────────────────────┐
                    │     Firebase Cloud Functions   │
                    │  ┌────────┐ ┌────────┐ ┌─────┐ │
                    │  │ Sheets │ │Schedule│ │Team │ │
                    │  │  Sync  │ │ Fetch  │ │Member│ │
                    │  └────────┘ └────────┘ └─────┘ │
                    └───────────────────────────────┘
   Team membership is mutated ONLY by the create_team/join_team/leave_team
   callables, which set a custom auth claim that Firestore rules enforce.
```

## Quick Start

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) 3.10+
- [Python **3.11**](https://www.python.org/downloads/) (for Cloud Functions — must be 3.11 exactly, matching the `python311` runtime in `firebase.json`; the Firebase CLI looks for `functions/venv/bin/python3.11` and fails to deploy otherwise)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Node.js](https://nodejs.org/) (only for the Firestore rules test suite)

### Setup

```bash
git clone https://github.com/SushiSquad7461/SushiScout26.git
cd SushiScout26

# Install Flutter dependencies and generate code
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run -d windows    # or macos, linux, chrome
```

> **Running on the web:** use `flutter run -d chrome`, or build and serve a
> release bundle (`flutter build web --release` then serve `build/web`).
> Avoid `flutter run -d web-server` — in debug it loads every module without
> error but never starts the app, giving a silent blank page.

### Cloud Functions (optional, for deployment)

```bash
cd functions
python3.11 -m venv venv        # must be 3.11 (see Prerequisites)
source venv/bin/activate       # Windows: venv\Scripts\activate
pip install -r requirements.txt
python -m pytest tests/ -v     # Verify tests pass
```

### Firestore rules tests

```bash
cd test/firestore-rules && npm install && cd ../..
firebase emulators:exec --only firestore \
  "cd test/firestore-rules && ./node_modules/.bin/jest --runInBand"
```

## Web app / iOS without the App Store

The Flutter web build is deployed to Firebase Hosting, which lets iPhone users
install SushiScout from Safari (**Share -> Add to Home Screen**) as a PWA. No
Apple Developer account, no TestFlight.

**Live:** https://sushiscout26-a8f5d.web.app

### Deploying

Pushes to `master` deploy automatically (`.github/workflows/deploy-web.yml`).
To deploy by hand:

```bash
firebase deploy --only hosting
```

`hosting.predeploy` in `firebase.json` runs `flutter build web --release` for
you, so there is no way to ship a stale `build/web`.

### One-time CI setup

The deploy workflow needs a `FIREBASE_SERVICE_ACCOUNT` repo secret:

```bash
# Creates the service account, grants the Hosting roles, and prints the JSON
# to paste into GitHub -> Settings -> Secrets -> Actions.
firebase init hosting:github
```

### iOS PWA caveats

Read this before telling scouts to rely on the web build at a competition:

- **iOS has no background sync.** Queued writes only flush while the app is open
  and in the foreground. Watch the connection indicator clear before closing.
- **First load is roughly 5-6 MB** (CanvasKit + `main.dart.js`, gzipped). The
  Spark free tier allows ~360 MB/day of transfer, so about 60 cold loads per
  day. Repeat visits are served from the service worker cache and cost nothing,
  but every deploy invalidates it for all scouts -- avoid deploying mid-event.
- **Safari evicts site data after 7 days without opening the app.** Firestore's
  offline cache is IndexedDB, and iOS clears it for sites not visited in a week,
  so a scout with unsynced matches queued could in principle lose them. Not a
  practical concern for us -- the app gets opened far more often than weekly
  during a season -- but worth knowing before anyone treats the local cache as
  durable storage. Anything that must survive is synced to Firestore.

## How It Works

### Scouting Flow

1. **Scout opens the app** and selects their event
2. **Match schedule loads** from TBA/FIRST Events API (or manual entry)
3. **Scout fills in the form** — FRC or FTC, selected automatically by event type
4. **Data writes to Firestore** — instant even offline, since Firestore queues the write on disk and flushes it when the connection recovers
5. **Cloud Function** exports the match one-way to the team's Google Sheet for analysis

### Team System

- Sign in with Google (mobile/web) or email/password (desktop)
- Create or join a team with an 8-character invite code
- All data is scoped to your team — other teams can't see your matches, even when scouting the same competition
- Membership is **server-authoritative**: joining is validated by a Cloud Function that mints a signed auth claim, and Firestore rules trust only that claim. Clients cannot grant themselves membership.
- Team admins can manage settings and regenerate invite codes

### Offline Support

Firestore is the app's only data store, on every platform:
- **Firestore's on-disk persistence** (`persistenceEnabled`, unlimited cache size) queues writes durably when the network is unreachable and flushes them when the stream recovers — there is no separate local database or sync queue to keep in sync
- **Connection status** comes from Firestore snapshot metadata (`isFromCache` / `hasPendingWrites`), not device connectivity — a captive portal can report "connected" while blocking all traffic, so the UI trusts what Firestore actually observed instead

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter, Riverpod |
| Auth | Firebase Auth, Google Sign-In |
| Database | Cloud Firestore (with on-disk offline persistence) |
| Backend | Python 3.11 Firebase Cloud Functions |
| Sync | Google Sheets API, The Blue Alliance API, FIRST Events API |
| Platforms | Windows, macOS, Linux, Android, iOS, Web |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, commit conventions, and development workflow.

## License

This project is maintained by SushiSquad 7461 for FIRST Robotics Competition scouting.
