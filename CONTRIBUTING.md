# Contributing to SushiScout 26

## Getting Started

### Prerequisites

Install these tools first:

- [Flutter SDK](https://docs.flutter.dev/get-started/install), version 3.10 or later
- [Python 3.11 or later](https://www.python.org/downloads/)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- [Git](https://git-scm.com/)

### Setup

```bash
# Clone the repo
git clone https://github.com/SushiSquad7461/SushiScout26.git
cd SushiScout26

# Frontend
cd frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs  # Generate Riverpod code

# Cloud Functions
cd ../functions
python -m venv venv
source venv/Scripts/activate   # Windows
# source venv/bin/activate     # macOS/Linux
pip install -r requirements.txt
```

## Development Workflow

Follow these steps for a change:

1. Create a feature branch from `master`.
2. Make your changes. Write clear, atomic commits.
3. Run the tests and `flutter analyze`.
4. Submit a pull request against `master`.

## Running the App

```bash
cd frontend
flutter run -d windows --hot    # Windows
flutter run -d macos --hot      # macOS
flutter run -d chrome            # Web
flutter run                      # Connected mobile device
```

## Testing

### Frontend (Flutter)

```bash
cd frontend
flutter test                                          # All tests
flutter test test/widgets/counter_card_test.dart       # Single test file
flutter test --coverage                                # With coverage
flutter analyze                                        # Static analysis
```

### Cloud Functions (Python)

```bash
cd functions
source venv/Scripts/activate    # Activate the venv first
python -m pytest tests/ -v      # Run tests
```

## Code Generation

Riverpod uses code generation. After you change an annotated provider, run
this command:

```bash
cd frontend
dart run build_runner build --delete-conflicting-outputs
```

**Do not hand-edit** `*.g.dart` or `*.mocks.dart` files. The build tool
regenerates them automatically.

## Commit Message Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/).

### Format

```
<type>(<scope>): <subject>
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation changes |
| `style` | Code style; no logic changes |
| `refactor` | Code refactor; no functional changes |
| `perf` | Performance improvement |
| `test` | New or updated tests |
| `chore` | Build process or tool changes |
| `ci` | CI/CD changes |
| `revert` | Revert of a previous commit |

### Scopes

`frontend`, `backend`, `db`, `api`, `ui`, `theme`, `sync`, `test`, `config`, `deps`, `auth`

### Subject Rules

Follow these four rules for the commit subject:

1. Use the imperative mood: write "add", not "added" or "adds".
2. Do not capitalize the first letter.
3. Do not add a period at the end.
4. Keep the subject to 50 characters or fewer.

### Examples

```
feat(frontend): add offline sync queue
fix(backend): resolve race condition in sheets sync
test(frontend): add widget tests for counter card
fix(auth): add team ownership check to security rules
```

## Branch Naming

Name your branch by change type:

- `feature/<description>` — a new feature
- `fix/<description>` — a bug fix
- `docs/<description>` — a documentation change
- `refactor/<description>` — a code refactor
- `test/<description>` — a test change
- `chore/<description>` — a maintenance task

## Code Style

### Flutter and Dart

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart).
- Run `dart format .` before you commit.
- Run `flutter analyze` to find issues.
- Use Riverpod for state management. Do not use `setState` for shared
  state.

### Python

- Follow [PEP 8](https://pep8.org/).
- Add type hints to every function signature.
- Give each Cloud Function one responsibility.

## Documentation Style

Write new docs, specs, and plans in ASD-STE100 Simplified Technical
English (STE): short sentences, active voice, simple verb tenses, and no
semicolons. See CLAUDE.md, section "Documentation Style", for the full
rule list.

## Project Structure

```
sushiscout26/
├── frontend/                # Flutter application
│   ├── lib/
│   │   ├── core/            # Auth, errors, Result type, utilities
│   │   ├── data/
│   │   │   ├── local/       # Local preferences (no local database)
│   │   │   ├── models/      # Event, MatchReport, Team, UserProfile
│   │   │   ├── repositories/ # Firestore, Auth, Team, Scouting repos
│   │   │   └── services/    # Schedule service, export service
│   │   ├── presentation/
│   │   │   ├── providers/   # Riverpod providers (auth, settings)
│   │   │   ├── screens/     # Dashboard, auth, scouting forms
│   │   │   ├── widgets/     # Reusable components
│   │   │   ├── factories/   # Form factory (FRC vs FTC)
│   │   │   └── theme/       # App theme
│   │   └── main.dart
│   └── test/
├── functions/               # Firebase Cloud Functions (Python)
│   ├── main.py              # Firestore triggers, callable functions
│   ├── tba_sync.py          # FRC schedule fetching (TBA API)
│   ├── ftc_api.py           # FTC schedule fetching (FIRST Events API)
│   ├── services/
│   │   └── sheets_service.py  # Google Sheets API wrapper (one-way export)
│   └── tests/
├── firestore.rules          # Firestore security rules
├── firestore.indexes.json   # Composite index definitions
├── CLAUDE.md                # AI assistant context
└── CONTRIBUTING.md          # This file
```

Firestore is the app's only data store. The app has no local SQLite
database and no separate sync queue.

## Firebase

### Deploying

```bash
firebase deploy --only functions          # Cloud Functions
firebase deploy --only firestore:rules    # Security rules
firebase deploy --only firestore:indexes  # Composite indexes
```

### Environment Secrets

Cloud Functions use these secrets, set through Firebase:

- `GOOGLE_SHEETS_CREDENTIALS` — service account for the Sheets API
  (one-way export, per team)
- `TBA_API_KEY` — The Blue Alliance API key, for FRC schedules
- `FTC_API_USERNAME` and `FTC_API_KEY` — FIRST Events API credentials,
  for FTC schedules

## Questions?

Open an issue for discussion before you make a major change.
