#!/bin/bash
cd "$(dirname "$0")/../../frontend"
echo "Starting SushiScout 26 iOS app..."
echo ""
echo "Make sure an iOS device or simulator is connected."
echo "Press 'r' in this window to hot reload"
echo "Press 'R' to hot restart"
echo "Press 'q' to quit"
echo ""
flutter run -d ios --hot
