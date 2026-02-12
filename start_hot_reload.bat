@echo off
cd /d "%~dp0\frontend"
echo Starting SushiScout 26 with hot reload...
echo.
echo Build will be available at: http://localhost:8080
echo Press 'r' in this window to hot reload
echo Press 'R' to hot restart
echo Press 'q' to quit
echo.
flutter run -d chrome --web-port=8080 --hot
pause
