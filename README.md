# SushiScout 26

A cross-platform FRC & FTC scouting app built by [SushiSquad 7461](https://github.com/SushiSquad7461). Scouts record match data on any device, even offline, and it syncs automatically to Firestore and Google Sheets for real-time analysis.

## Features

- **Multi-platform** — Windows, macOS, Linux, Android, iOS, and web
- **Offline-first** — Full functionality without internet; syncs when back online
- **FRC + FTC** — Separate scouting forms tailored to each program
- **Team isolation** — server-enforced: every team's events and matches are private to that team, so multiple teams can scout the same competition independently
- **Live sync** — Match data syncs bidirectionally between Firestore and Google Sheets
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
│  │          Hybrid Repository                │   │
│  │   (reads local, queues writes for sync)   │   │
│  └──────┬─────────────────────────┬──────────┘   │
│   ┌─────┴─────┐           ┌──────┴───────┐      │
│   │ Drift DB  │           │  Firestore   │      │
│   │ (SQLite)  │           │  Repository  │      │
│   └───────────┘           └──────────────┘      │
└─────────────────────────────────────────────────┘
                                    │
                    ┌───────────────┴───────────────┐
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

## How It Works

### Scouting Flow

1. **Scout opens the app** and selects their event
2. **Match schedule loads** from TBA/FIRST Events API (or manual entry)
3. **Scout fills in the form** — FRC or FTC, selected automatically by event type
4. **Data saves locally** to SQLite (instant, works offline)
5. **Background sync** pushes to Firestore when online
6. **Cloud Function** mirrors data to Google Sheets for analysis

### Team System

- Sign in with Google (mobile/web) or email/password (desktop)
- Create or join a team with an 8-character invite code
- All data is scoped to your team — other teams can't see your matches, even when scouting the same competition
- Membership is **server-authoritative**: joining is validated by a Cloud Function that mints a signed auth claim, and Firestore rules trust only that claim. Clients cannot grant themselves membership.
- Team admins can manage settings and regenerate invite codes

### Offline Support

The app uses an offline-first architecture:
- **Local SQLite** (via Drift) stores all data immediately
- **Sync queue** tracks pending changes with retry logic
- **Firestore** syncs in the background with conflict detection
- On web, Firestore's built-in offline persistence is used instead

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter, Riverpod, Drift (SQLite) |
| Auth | Firebase Auth, Google Sign-In |
| Database | Cloud Firestore, local SQLite |
| Backend | Python 3.11 Firebase Cloud Functions |
| Sync | Google Sheets API, The Blue Alliance API |
| Platforms | Windows, macOS, Linux, Android, iOS, Web |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup instructions, commit conventions, and development workflow.

## License

This project is maintained by SushiSquad 7461 for FIRST Robotics Competition scouting.
