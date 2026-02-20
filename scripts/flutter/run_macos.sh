#!/bin/bash
cd "$(dirname "$0")/../../frontend"
echo "Starting SushiScout 26 macOS app with hot reload..."
echo ""
echo "Press 'r' in this window to hot reload"
echo "Press 'R' to hot restart"
echo "Press 'q' to quit"
echo ""
flutter run -d macos --hot
