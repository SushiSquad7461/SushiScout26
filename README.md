# SushiScout 26

[![test](https://github.com/SushiSquad7461/SushiScout26/actions/workflows/test.yml/badge.svg)](https://github.com/SushiSquad7461/SushiScout26/actions/workflows/test.yml)

SushiScout 26 is a scouting app for FRC and FTC robotics competitions. It is built by [SushiSquad 7461](https://github.com/SushiSquad7461). Scouts use the app to record match data on any device, even offline. The app syncs the data to Firestore and to Google Sheets for analysis.

## Features

- **Multi-platform.** The app runs on Windows, macOS, Linux, Android, iOS, and the web.
- **Offline-first.** The app works fully without internet access. It syncs when the connection returns.
- **FRC and FTC support.** The app shows a different scouting form for each program.
- **Team isolation.** The server enforces this rule: a team's events and matches stay private to that team. Two teams can scout the same competition at the same time and not see each other's data.
- **Sheets export.** Each team can connect its own Google Sheet. Match data flows one way, from Firestore to that sheet, for analysis.
- **Schedule import.** The app can pull match schedules from The Blue Alliance (for FRC) and from the FIRST Events API (for FTC).

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
   The create_team, join_team, and leave_team callables are the only
   code that can change team membership. Each callable sets a custom
   auth claim, and Firestore rules enforce that claim.
```

## Quick Start

### Prerequisites

Install these tools before you set up the project:

- [Flutter SDK](https://docs.flutter.dev/get-started/install), version 3.10 or later
- [Python 3.11](https://www.python.org/downloads/), for Cloud Functions. Use exactly version 3.11. This must match the `python311` runtime in `firebase.json`. The Firebase CLI looks for `functions/venv/bin/python3.11` and fails to deploy if that path is missing.
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Node.js](https://nodejs.org/), for the Firestore rules test suite only

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

> **Note on the web build:** use `flutter run -d chrome`. Or build a release
> bundle with `flutter build web --release` and serve `build/web`.
> Do not use `flutter run -d web-server`. In debug mode this command loads
> every module without an error, but the app never starts. You see a blank
> page with no error message.

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

## Web app and iOS install without the App Store

Firebase Hosting serves the Flutter web build. An iPhone user can install
SushiScout from Safari as a home-screen app: tap **Share**, then **Add to
Home Screen**. This install method needs no Apple Developer account and no
TestFlight.

**Live app:** https://sushiscout26-a8f5d.web.app

### Deploying

Every push to `master` deploys the web app automatically
(`.github/workflows/deploy-web.yml`). To deploy by hand, run this command:

```bash
firebase deploy --only hosting
```

The `hosting.predeploy` setting in `firebase.json` runs
`flutter build web --release` for you. This step prevents a stale
`build/web` directory from reaching production. The CI deploy also runs
`flutter analyze` and the test suite first.

### One-time CI setup

The deploy workflow needs a `FIREBASE_SERVICE_ACCOUNT` repository secret.
Run this command to create it:

```bash
# This command creates the service account, grants the Hosting roles, and
# prints JSON output. Paste that output into GitHub, under Settings,
# Secrets, Actions.
firebase init hosting:github
```

### iOS PWA limits

Read this section before you tell scouts to rely on the web build at a
competition.

- **iOS has no background sync.** Queued writes flush to the server only
  while the app stays open and in the foreground. Watch the connection
  indicator clear before you close the app.
- **A cold load transfers 3.6 MB.** This is `main.dart.js` (1.27 MB) plus
  `canvaskit.wasm` (2.12 MB) plus fonts and other assets, all compressed. A
  repeat load inside the cache window costs nothing. The project uses the
  Blaze billing plan, so the first 360 MB per day of Hosting traffic is
  free; traffic above that costs $0.15 per GB. A typical competition day
  (15 scouts, 20 loads each) uses about 390 MB. That costs under one cent.
  Cost is not a risk here.
- **The app has no offline shell.** Flutter 3.41 ships a service worker
  that only unregisters itself. The build has no `--pwa-strategy` flag to
  change this behavior, so nothing precaches the app. The server sends the
  shell with `max-age=300`. This means a scout whose wifi drops can reopen
  the app for about five minutes, then can no longer reopen it. Firestore
  still holds the scout's data offline during this time — this limit is
  only about whether the app itself can *start*. A correct fix needs a
  hand-written service worker. Flutter's bootstrap code actively removes
  any such worker (it registers its own stub over any existing
  registration), so this is not a simple change.
- **Safari deletes site data after 7 days without an app open.** Firestore
  stores its offline cache in IndexedDB, and iOS clears that data for
  sites the user has not visited in a week. A scout with unsynced matches
  queued could in principle lose that data. In practice this is not a
  concern, because scouts open the app far more often than once a week
  during a season. But keep this limit in mind: do not treat the local
  cache as durable storage. Anything that must survive syncs to Firestore.

## How It Works

### Scouting Flow

1. The scout opens the app and selects an event.
2. The app loads the match schedule from the TBA or FIRST Events API. The
   scout can also enter matches by hand.
3. The scout fills in the form. The app selects the FRC or FTC form
   automatically, based on the event type.
4. The app writes the data to Firestore. This write completes instantly,
   even offline, because Firestore queues the write on disk and sends it
   when the connection returns.
5. A Cloud Function exports the match, one way, to the team's Google Sheet
   for analysis.

### Team System

- A scout signs in with Google (on mobile or web) or with email and
  password (on desktop).
- A scout can create a team or join one with an 8-character invite code.
- The app scopes all data to the scout's team. Other teams cannot see
  these matches, even when they scout the same competition.
- Team membership is **server-authoritative**. A Cloud Function validates
  each join request and mints a signed auth claim. Firestore rules trust
  only that claim. A client cannot grant itself membership.
- A team admin can manage team settings and can regenerate the invite
  code.

### Offline Support

Firestore is the app's only data store, on every platform.

- **Firestore's on-disk persistence** (`persistenceEnabled`, with an
  unlimited cache size) queues writes durably when the network is
  unreachable. It sends the writes when the connection returns. The app
  keeps no separate local database and no separate sync queue.
- **Connection status comes from Firestore's own snapshot metadata**
  (`isFromCache` and `hasPendingWrites`), not from the device's network
  state. A captive portal can report "connected" while it blocks all
  traffic. The app trusts what Firestore actually observed instead of
  what the device reports.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter, Riverpod |
| Auth | Firebase Auth, Google Sign-In |
| Database | Cloud Firestore, with on-disk offline persistence |
| Backend | Python 3.11 Firebase Cloud Functions |
| Sync | Google Sheets API, The Blue Alliance API, FIRST Events API |
| Platforms | Windows, macOS, Linux, Android, iOS, Web |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup steps, commit rules, and
the development workflow.

## License

SushiSquad 7461 maintains this project for FIRST Robotics Competition
scouting.
