# Contributing to SushiScout 26

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10+)
- [Python 3.11+](https://www.python.org/downloads/)
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
dart run build_runner build --delete-conflicting-outputs  # Generate Drift/Riverpod code

# Cloud Functions
cd ../functions
python -m venv venv
source venv/Scripts/activate   # Windows
# source venv/bin/activate     # macOS/Linux
pip install -r requirements.txt
```

## Development Workflow

1. Create a feature branch from `master`
2. Make your changes with clear, atomic commits
3. Run tests and `flutter analyze`
4. Submit a PR against `master`

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
source venv/Scripts/activate    # Activate venv first
python -m pytest tests/ -v      # Run tests
```

## Code Generation

Drift (SQLite) and Riverpod use code generation. After modifying table definitions or annotated providers:

```bash
cd frontend
dart run build_runner build --delete-conflicting-outputs
```

**Never hand-edit** `*.g.dart` or `*.mocks.dart` files — they are regenerated automatically.

## Commit Message Convention

We follow [Conventional Commits](https://www.conventionalcommits.org/).

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
| `style` | Code style (formatting, no logic changes) |
| `refactor` | Code refactoring without changing functionality |
| `perf` | Performance improvements |
| `test` | Adding or updating tests |
| `chore` | Build process or auxiliary tool changes |
| `ci` | CI/CD changes |
| `revert` | Revert previous commit |

### Scopes

`frontend`, `backend`, `db`, `api`, `ui`, `theme`, `sync`, `test`, `config`, `deps`, `auth`

### Subject Rules

1. Use imperative mood ("add" not "added" or "adds")
2. Don't capitalize first letter
3. No period at the end
4. Maximum 50 characters

### Examples

```
feat(frontend): add offline sync queue
fix(backend): resolve race condition in sheets sync
test(frontend): add widget tests for counter card
fix(auth): add team ownership check to security rules
```

## Branch Naming

- `feature/<description>` — New features
- `fix/<description>` — Bug fixes
- `docs/<description>` — Documentation
- `refactor/<description>` — Refactoring
- `test/<description>` — Tests
- `chore/<description>` — Maintenance

## Code Style

### Flutter/Dart

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Run `dart format .` before committing
- Run `flutter analyze` to check for issues
- Use Riverpod for state management (not setState for shared state)

### Python

- Follow [PEP 8](https://pep8.org/)
- Use type hints for function signatures
- Keep Cloud Functions focused — one responsibility per function

## Project Structure

```
sushiscout26/
├── frontend/                # Flutter application
│   ├── lib/
│   │   ├── core/            # Auth, errors, results, utilities
│   │   ├── data/
│   │   │   ├── local/       # Drift DB, sync manager, preferences
│   │   │   ├── models/      # Event, MatchReport, Team, UserProfile
│   │   │   ├── repositories/ # Hybrid, Firestore, Auth, Team repos
│   │   │   └── services/    # Schedule service
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
│   │   ├── sheets_service.py  # Google Sheets API wrapper
│   │   └── sync_tracker.py    # Firestore↔Sheets row mapping
│   └── tests/
├── firestore.rules          # Firestore security rules
├── firestore.indexes.json   # Composite index definitions
├── CLAUDE.md                # AI assistant context
└── CONTRIBUTING.md           # This file
```

## Firebase

### Deploying

```bash
firebase deploy --only functions          # Cloud Functions
firebase deploy --only firestore:rules    # Security rules
firebase deploy --only firestore:indexes  # Composite indexes
```

### Environment Secrets

Cloud Functions use these secrets (configured via Firebase):
- `GOOGLE_SHEETS_CREDENTIALS` — Service account for Sheets API
- `MASTER_SPREADSHEET_ID` — Target spreadsheet
- `SYNC_API_KEY` — HTTP endpoint authentication
- `TBA_API_KEY` — The Blue Alliance API key

## Questions?

Open an issue for discussion before making major changes.
