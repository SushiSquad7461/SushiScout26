---
name: run-tests
description: Run the right test suite based on what changed - Flutter (frontend) and/or pytest (functions). Regenerates Drift/Riverpod code first when needed.
disable-model-invocation: true
---

# Run Tests

Run the appropriate suite(s) for the current change. Prefer running only what's relevant.

## Decide what to run

Check `git status`/`git diff --name-only` for what changed:
- Files under `frontend/` -> run the Flutter suite.
- Files under `functions/` -> run the Python suite.
- Both -> run both.

## Frontend (Flutter) — 285 tests

1. If `tables.dart`, `app_database.dart`, or any `*.dart` with Riverpod/Drift annotations changed, regenerate first:
```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs
```
2. Run tests:
```bash
cd frontend && flutter test
```
3. For a single test: `cd frontend && flutter test test/path/to/test.dart`

## Backend (Python) — 24 tests

```bash
cd functions && python -m pytest tests/ -v
```
If imports fail, activate the venv first: `cd functions && source venv/Scripts/activate`

## Report
- Which suite(s) ran and why
- Pass/fail counts
- For failures: the failing test name + the assertion, not the whole log
