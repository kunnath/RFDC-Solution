#!/bin/bash
# 1. Config
SDK_PATH="/Users/kunnath/Android/Sdk"
AVD_NAME="Samsung_Rooted_API31"
SYS_IMG="system-images;android-31;google_apis;arm64-v8a"
ROOTAVD_PATH="/Users/kunnath/Documents/tools/rootAVD" # UPDATE THIS to your rootAVD folder
APK_PATH="/Users/kunnath/Downloads/Cricfy_v6.1_new.apk" # UPDATE THIS to your APK path

# 2. Create the device (Google APIs image, NOT Google Play)
echo "no" | $SDK_PATH/cmdline-tools/latest/bin/avdmanager create avd -n "$AVD_NAME" -k "$SYS_IMG" --force

# 3. Launch emulator in background
$SDK_PATH/emulator/emulator -avd "$AVD_NAME" -writable-system & 
echo "Waiting for emulator to boot..."
$SDK_PATH/platform-tools/adb wait-for-device

# 4. Run rootAVD to patch with Magisk
# This specific command targets API 31 Google APIs
cd $ROOTAVD_PATH
./rootAVD.sh "$SYS_IMG"

# 5. Install the APK with 'test' and 'downgrade' flags to bypass blocks
$SDK_PATH/platform-tools/adb install -r -t -d "$APK_PATH"

echo "Rooted and App Installed successfully."

