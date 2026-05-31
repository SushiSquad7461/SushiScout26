---
name: firestore-rules-check
description: Validate and safely deploy Firestore security rules and indexes. Checks team-isolation invariants before deploying.
disable-model-invocation: true
---

# Firestore Rules Check

Validate team-isolation rules before deploying. Team data leaks are the worst-case bug for this app.

## Checklist (review `firestore.rules` before deploying)

- No `allow read, write: if true` wildcards anywhere.
- Every `matches`, `events`, and `teams/**` rule checks team membership via the `teams/{teamId}/members/{userId}` subcollection.
- `create` rules validate `request.resource.data.teamId`.
- `update`/`delete` rules check `resource.data.teamId`.
- `isTeamMember()` (or equivalent) points at the correct subcollection path.
- No leftover merge-conflict markers (`>>>>>>>`).

## Steps

1. Show the current rules and confirm the checklist above passes. Stop and report if any item fails.
2. Deploy rules:
```bash
firebase deploy --only firestore:rules
```
3. If indexes changed (composite queries on teamId + eventId + isDeleted + createdAt), deploy them too:
```bash
firebase deploy --only firestore:indexes
```
4. Report what was deployed.

## Important
- ALWAYS confirm with the user before the deploy step.
- NEVER deploy if a checklist item fails — fix the rule first.
- For deeper review, hand the diff to the `security-reviewer` agent.
