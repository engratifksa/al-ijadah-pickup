#!/bin/bash
set -e

echo "=== Building Al Ijadah Pickup iOS Package ==="

# 1. Fetch dependencies
flutter pub get

# 2. Build iOS Release without codesign (or with your Apple Developer Team)
flutter build ios --release --no-codesign

# 3. Create IPA package from Runner.app
echo "Packaging into IPA..."
rm -rf Payload Al_Ijadah_Pickup_iOS.ipa
mkdir -p Payload
cp -r build/ios/iphoneos/Runner.app Payload/
zip -r Al_Ijadah_Pickup_iOS.ipa Payload
rm -rf Payload

echo "=== SUCCESS ==="
echo "iOS Package created: Al_Ijadah_Pickup_iOS.ipa"
