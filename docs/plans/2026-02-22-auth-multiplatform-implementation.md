# Auth Multi-Platform Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add Linux support to reuse desktop OAuth client, Android already works via google-services.json

**Architecture:** Platform detection in auth_provider.dart using defaultTargetPlatform

**Tech Stack:** Flutter, google_sign_in, Firebase Auth

---

### Task 1: Add Linux to platform detection

**Files:**
- Modify: `frontend/lib/presentation/providers/auth_provider.dart:23-30`

**Step 1: Modify the platform check**

Change:
```dart
} else if (defaultTargetPlatform == TargetPlatform.windows) {
```

To:
```dart
} else if (defaultTargetPlatform == TargetPlatform.windows ||
           defaultTargetPlatform == TargetPlatform.linux) {
```

**Step 2: Verify build still works**

Run: `flutter build web --release`
Expected: PASS

**Step 3: Commit**

```bash
git add frontend/lib/presentation/providers/auth_provider.dart
git commit -m "feat(frontend): add Linux support for Google Sign-In"
```

---

### Task 2: Verify Android works

**Step 1: Ensure google-services.json is in place**

File should be at: `frontend/android/app/google-services.json`

**Step 2: Commit if not already committed**

```bash
git add frontend/android/app/google-services.json
git commit -m "chore(frontend): add Android Firebase config with debug SHA-1"
```

---

## Summary

| Platform | Status | Action |
|----------|--------|--------|
| Web | Working | No change |
| Windows | Working | No change |
| Linux | Add | Modify auth_provider.dart |
| Android | Works via config | Verify google-services.json |
| iOS/macOS | Future | No change (needs signing) |
