# Contributing to SushiScout 26

## Commit Message Convention

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification.

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: New feature
- **fix**: Bug fix  
- **docs**: Documentation changes
- **style**: Code style (formatting, missing semi-colons, etc)
- **refactor**: Code refactoring without changing functionality
- **perf**: Performance improvements
- **test**: Adding or updating tests
- **chore**: Build process or auxiliary tool changes
- **ci**: CI/CD changes
- **revert**: Revert previous commit

### Scopes

- **frontend**: Flutter application changes
- **backend**: FastAPI/Python changes
- **db**: Database schema or queries
- **api**: API endpoint changes
- **ui**: UI components and screens
- **theme**: Theme, colors, and styling
- **sync**: Data synchronization logic
- **test**: Test infrastructure
- **config**: Configuration files
- **deps**: Dependency updates

### Examples

```
feat(frontend): add offline sync queue

Implement local SQLite database with Drift to store
matches when offline. Sync queue processes pending
changes when connectivity is restored.

Closes #42
```

```
fix(backend): resolve race condition in sheets sync

Add proper locking to prevent concurrent updates
to Google Sheets from multiple scouters.
```

```
test(frontend): add widget tests for counter card

Add comprehensive widget tests covering:
- Initial value display
- Increment/decrement functionality
- Long press to clear
- Boundary conditions
```

### Subject Rules

1. Use imperative mood ("add" not "added" or "adds")
2. Don't capitalize first letter
3. No period at the end
4. Maximum 50 characters

### Body Rules

1. Use imperative mood
2. Wrap at 72 characters
3. Explain WHAT and WHY, not HOW
4. Separate from subject with blank line

### Footer Rules

1. Reference issues: `Closes #123`, `Fixes #456`
2. Breaking changes: `BREAKING CHANGE: description`
3. Co-authors: `Co-authored-by: Name <email>`

## Branch Naming

- `feat/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation
- `refactor/description` - Refactoring
- `test/description` - Tests
- `chore/description` - Maintenance

## Development Workflow

1. Create a feature branch from `master`
2. Make your changes with clear, atomic commits
3. Ensure tests pass
4. Update documentation if needed
5. Submit PR (when we have a remote)

## Testing

### Frontend (Flutter)

```bash
cd frontend
flutter test
flutter test integration_test/
```

### Backend (Python)

```bash
cd backend
pytest
pytest --cov=app tests/
```

## Code Style

### Flutter

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `flutter format` before committing
- Run `flutter analyze` to check for issues

### Python

- Follow [PEP 8](https://pep8.org/)
- Use Black formatter: `black app/ tests/`
- Use isort for imports: `isort app/ tests/`

## Project Structure

```
sushiscout26/
├── frontend/          # Flutter application
│   ├── lib/
│   │   ├── core/      # Errors, results, utilities
│   │   ├── data/      # Repositories, models, local DB
│   │   ├── presentation/  # UI layer
│   │   └── main.dart
│   └── test/
├── backend/           # FastAPI application
│   ├── app/
│   │   ├── core/      # Exceptions, config
│   │   ├── models/    # SQLAlchemy models
│   │   ├── schemas/   # Pydantic schemas
│   │   ├── routers/   # API endpoints
│   │   └── services/  # Business logic
│   └── tests/
└── functions/         # Firebase Cloud Functions
```

## Questions?

Open an issue for discussion before major changes.
