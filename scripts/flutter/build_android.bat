@echo off
cd /d "%~dp0..\..\frontend"
echo Building SushiScout 26 for Android (release)...
echo.
flutter build apk --release
echo.
echo Build complete! Output: build\app\outputs\flutter-apk\app-release.apk
pause
