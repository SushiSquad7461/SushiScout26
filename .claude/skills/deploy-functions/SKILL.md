---
name: deploy-functions
description: Validate and deploy Firebase Cloud Functions. Checks Python syntax, runs tests, then deploys.
disable-model-invocation: true
---

# Deploy Cloud Functions

Safely validate and deploy Python Cloud Functions to Firebase.

## Steps

1. Validate Python syntax:
```bash
cd functions && python -c "import ast; [ast.parse(open(f).read()) for f in ['main.py','ftc_api.py','tba_sync.py']]; print('All Python files parse OK')"
```

2. Run tests:
```bash
cd functions && python -m pytest tests/ -v
```

3. If tests pass, confirm with user before deploying:
```bash
firebase deploy --only functions
```

4. Report deployment status.

## Important
- NEVER deploy if syntax check or tests fail
- ALWAYS ask user for confirmation before the deploy step
- Check that the virtual environment is activated if imports fail
