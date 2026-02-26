#!/bin/bash
# 1. Define paths and names
SDK_PATH="/Users/kunnath/Android/Sdk"
AVD_NAME="Samsung_S25_Auto"
 # Use x86_64 for Intel Mac
SYS_IMG="system-images;android-31;google_apis;arm64-v8a"
# 2. Download the system image automatically (if not present)
$SDK_PATH/cmdline-tools/latest/bin/sdkmanager --install "$SYS_IMG"

# 3. Create the AVD automatically (pipes "no" to the setup prompt)
echo "no" | $SDK_PATH/cmdline-tools/latest/bin/avdmanager create avd -n "$AVD_NAME" -k "$SYS_IMG" --force

# 4. Launch the emulator
$SDK_PATH/emulator/emulator -avd "$AVD_NAME"

