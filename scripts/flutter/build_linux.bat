@echo off
cd /d "%~dp0..\..\frontend"
echo Building SushiScout 26 for Linux (release)...
echo.
flutter build linux --release
echo.
echo Build complete! Output: build\linux\x64\release\
pause
