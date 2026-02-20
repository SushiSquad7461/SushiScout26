#!/bin/bash
cd "$(dirname "$0")/../../frontend"
echo "Building SushiScout 26 for macOS (release)..."
echo ""
flutter build macos --release
echo ""
echo "Build complete! Output: build/macos/Build/Products/Release/"
