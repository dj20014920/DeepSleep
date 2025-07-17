#!/bin/bash

# Change to project directory
cd /Users/dj20014920/Desktop/DeepSleep

# Build the project
echo "🔧 Building DeepSleep project..."
xcodebuild -project DeepSleep.xcodeproj -scheme DeepSleep -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
else
    echo "❌ Build failed!"
    exit 1
fi