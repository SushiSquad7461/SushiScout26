@echo off
cd /d "%~dp0..\..\frontend"
echo Starting SushiScout 26 Android app...
echo.
echo Make sure an Android device or emulator is connected.
echo Press 'r' in this window to hot reload
echo Press 'R' to hot restart
echo Press 'q' to quit
echo.
flutter run -d android --hot
pause
