@echo off
cd /d "%~dp0..\..\frontend"
echo Building SushiScout 26 for Windows (release)...
echo.
flutter build windows --release
echo.
echo Build complete! Output: build\windows\x64\runner\Release\
pause
