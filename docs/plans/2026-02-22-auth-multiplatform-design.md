# Auth Multi-Platform Support Design

## Date
2026-02-22

## Status
Approved

## Overview
Add Google Sign-In support for Android, Linux, and ensure iOS/macOS are ready for future signing certificates.

## Current State
- Web: Working with web OAuth client
- Windows: Working with desktop OAuth client

## Changes Needed

### 1. Linux Support
Add Linux to use the same desktop OAuth client as Windows.
- File: `frontend/lib/presentation/providers/auth_provider.dart`
- Add `TargetPlatform.linux` to the desktop client check

### 2. Android Support
Already configured - uses google-services.json automatically via Firebase.
- No code changes needed
- Already downloaded new google-services.json with SHA-1

### 3. iOS/macOS
Reserved for future - requires signing certificates.
- Will need OAuth client setup when certificates available

## Architecture
Platform detection using `defaultTargetPlatform` from `flutter/foundation.dart`.

## Testing
- Android: Run on device/emulator
- Linux: Run with `flutter run -d linux`
