#!/bin/bash
cd "$(dirname "$0")/../../frontend"
echo "Building SushiScout 26 for iOS (release)..."
echo ""
flutter build ios --release
echo ""
echo "Build complete! Output: build/ios/iphoneos/"
