---
name: drift-codegen
description: Run Drift (SQLite) code generation after modifying tables.dart or app_database.dart. Regenerates *.g.dart files and verifies compilation.
---

# Drift Code Generation

Run this after modifying Drift table definitions or database classes.

## Steps

1. Run code generation:
```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs
```

2. Verify compilation:
```bash
cd frontend && flutter analyze --no-fatal-infos
```

3. Report results: number of outputs generated, any errors found.

## When to use
- After editing `frontend/lib/data/local/database/tables.dart`
- After editing `frontend/lib/data/local/database/app_database.dart`
- After adding new Drift table classes
- When `*.g.dart` files are out of date
