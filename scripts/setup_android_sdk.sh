#!/usr/bin/env bash
set -euo pipefail

# One-time installer for Android SDK command-line tools, platform-tools, emulator,
# and a default system image + AVD. Designed for macOS/Linux.
# Usage: scripts/setup_android_sdk.sh [ANDROID_SDK_ROOT]
# You may override the command-line tools URL via CMDLINE_TOOLS_URL env var.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEFAULT_SDK_ROOT="$HOME/Android/Sdk"

# Parse arguments: optional --force to remove conflicting cmdline-tools
FORCE_REMOVE=0
SDK_ROOT_ARG=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE_REMOVE=1
      shift
      ;;
    *)
      if [ -z "$SDK_ROOT_ARG" ]; then
        SDK_ROOT_ARG="$1"
        shift
      else
        break
      fi
      ;;
  esac
done

SDK_ROOT="${SDK_ROOT_ARG:-${ANDROID_SDK_ROOT:-$DEFAULT_SDK_ROOT}}"

echo "Android SDK root: $SDK_ROOT"
mkdir -p "$SDK_ROOT"

# Helper: ensure rc contains SDK/JAVA exports
add_to_rc() {
  local rcfile="$1"
  grep -q "# RFDC Android SDK" "$rcfile" 2>/dev/null || cat >> "$rcfile" <<EOF
# RFDC Android SDK
export ANDROID_SDK_ROOT="$SDK_ROOT"
export PATH="\$ANDROID_SDK_ROOT/platform-tools:\$ANDROID_SDK_ROOT/emulator:\$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:\$PATH"
EOF
}

# Ensure Java 11+ is available (sdkmanager requires Java 11)
JAVA_MAJOR=0
if command -v java >/dev/null 2>&1; then
  ver=$(java -version 2>&1 | sed -n 's/.*version "\([^"]*\)".*/\1/p' || true)
  if [ -n "$ver" ]; then
    if [[ "$ver" == 1.* ]]; then
      JAVA_MAJOR=$(echo "$ver" | cut -d. -f2)
    else
      JAVA_MAJOR=$(echo "$ver" | cut -d. -f1)
    fi
  fi
fi

if [ "${JAVA_MAJOR:-0}" -lt 11 ]; then
  echo "Detected Java major version: ${JAVA_MAJOR:-none} — Android SDK command-line tools require Java 11+."
  if command -v brew >/dev/null 2>&1; then
    echo "Attempting to install OpenJDK 11 via Homebrew..."
    brew install openjdk@11 || true
    # try to set JAVA_HOME for current session (prefer /usr/libexec/java_home, else Homebrew path)
    if /usr/libexec/java_home -v 11 >/dev/null 2>&1; then
      export JAVA_HOME=$(/usr/libexec/java_home -v 11)
    else
      # prefer `brew --prefix openjdk@11` if available
      if command -v brew >/dev/null 2>&1 && brew --prefix openjdk@11 >/dev/null 2>&1; then
        bprefix=$(brew --prefix openjdk@11)
        export JAVA_HOME="$bprefix/libexec/openjdk.jdk/Contents/Home"
      fi
    fi
    # validate JAVA_HOME points to a JDK 11+; if not, unset and warn
    if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
      jver=$($JAVA_HOME/bin/java -version 2>&1 | sed -n 's/.*version "\([^\"]*\)".*/\1/p' || true)
      jmaj=0
      if [ -n "$jver" ]; then
        if [[ "$jver" == 1.* ]]; then
          jmaj=$(echo "$jver" | cut -d. -f2)
        else
          jmaj=$(echo "$jver" | cut -d. -f1)
        fi
      fi
      if [ "$jmaj" -lt 11 ]; then
        echo "Detected JAVA_HOME at $JAVA_HOME but Java major version is $jmaj (<11). Unsetting JAVA_HOME." >&2
        unset JAVA_HOME
      else
        echo "Temporarily set JAVA_HOME=$JAVA_HOME"
      fi
      # persist to rc
      RCFILE="$HOME/.zshrc"
      if [ -z "${ZSH_VERSION:-}" ]; then
        RCFILE="$HOME/.bashrc"
      fi
      grep -q "# RFDC Java Home" "$RCFILE" 2>/dev/null || cat >> "$RCFILE" <<EOF
# RFDC Java Home
export JAVA_HOME="$JAVA_HOME"
export PATH="\$JAVA_HOME/bin:\$PATH"
EOF
      echo "Added JAVA_HOME to $RCFILE. Run: source $RCFILE (or open a new shell)."
    else
      echo "Could not set JAVA_HOME automatically after brew install. Please set JAVA_HOME to a JDK 11+ installation and re-run this script." >&2
      exit 7
    fi
  else
    echo "Homebrew not found. Install a JDK 11+ manually (Temurin/Adoptium, Azul, Oracle) and set JAVA_HOME, then re-run." >&2
    exit 8
  fi
fi

# If already has platform-tools and emulator, assume installed
if [ -x "$SDK_ROOT/platform-tools/adb" ] && [ -x "$SDK_ROOT/emulator/emulator" ] && [ -x "$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "Android SDK already appears installed under $SDK_ROOT"
  echo "Ensuring shell rc contains SDK/JAVA exports and exporting into current session."
  # Ensure rc has exports
  if [ -n "${ZSH_VERSION:-}" ]; then
    RCFILE="$HOME/.zshrc"
  else
    RCFILE="$HOME/.bashrc"
  fi
  add_to_rc "$RCFILE"

  # Try to set JAVA_HOME for current session (prefer Homebrew openjdk@11)
  if command -v brew >/dev/null 2>&1 && brew --prefix openjdk@11 >/dev/null 2>&1; then
    export JAVA_HOME="$(brew --prefix openjdk@11)/libexec/openjdk.jdk/Contents/Home"
  elif /usr/libexec/java_home -v 11 >/dev/null 2>&1; then
    export JAVA_HOME=$(/usr/libexec/java_home -v 11)
  fi

  # Export into current session PATH
  export ANDROID_SDK_ROOT="$SDK_ROOT"
  export PATH="$SDK_ROOT/platform-tools:$SDK_ROOT/emulator:$SDK_ROOT/cmdline-tools/latest/bin:$PATH"
  if [ -n "${JAVA_HOME:-}" ]; then
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "Set JAVA_HOME=$JAVA_HOME"
  fi

  echo "Added SDK/JAVA exports to $RCFILE (if not already present)."
  echo "Run: source $RCFILE or open a new shell to persist changes." 
  if [ "$FORCE_REMOVE" -eq 1 ]; then
    echo "--force provided: continuing to install/update SDK components despite existing installation."
  else
    exit 0
  fi
fi

# Select download URL for commandline tools
case "$(uname -s)" in
  Darwin)
    CMDLINE_URL="${CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-mac-9477386_latest.zip}"
    ;;
  Linux)
    CMDLINE_URL="${CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip}"
    ;;
  *)
    echo "Unsupported OS: $(uname -s)" >&2
    exit 2
    ;;
esac

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

echo "Downloading Android command-line tools from: $CMDLINE_URL"
if ! curl -fL "$CMDLINE_URL" -o "$TMPDIR/cmdline.zip"; then
  echo "Failed to download command-line tools. Set CMDLINE_TOOLS_URL to a valid URL and retry." >&2
  exit 3
fi

echo "Extracting command-line tools..."
unzip -q "$TMPDIR/cmdline.zip" -d "$TMPDIR"

# Move into $SDK_ROOT/cmdline-tools/latest so sdkmanager path is stable
mkdir -p "$SDK_ROOT/cmdline-tools"
TARGET="$SDK_ROOT/cmdline-tools/latest"

# If target exists and force removal requested, remove it to avoid conflicts
if [ -d "$TARGET" ] && [ "$FORCE_REMOVE" -eq 1 ]; then
  echo "--force provided: removing existing $TARGET to avoid conflicts"
  rm -rf "$TARGET"
fi

# If target exists and not forcing removal, instruct user to re-run with --force to remove
if [ -d "$TARGET" ] && [ "$FORCE_REMOVE" -ne 1 ]; then
  echo "Found existing $TARGET which may cause conflicts."
  echo "Re-run this script with --force to remove the existing cmdline-tools/latest before installing."
  echo "Or remove $TARGET manually and re-run."
  exit 9
fi

mkdir -p "$TARGET"
if [ -d "$TMPDIR/cmdline-tools" ]; then
  SRC_DIR="$TMPDIR/cmdline-tools"
else
  # some zips may contain 'cmdline-tools' folder nested; try to find
  SRC_DIR=$(find "$TMPDIR" -maxdepth 3 -type d -name cmdline-tools | head -n1 || true)
fi
if [ -z "$SRC_DIR" ]; then
  echo "Could not locate cmdline-tools in archive" >&2
  exit 4
fi

# Merge contents into the target (non-destructive) to avoid "Directory not empty" errors
if command -v rsync >/dev/null 2>&1; then
  rsync -a "$SRC_DIR/" "$TARGET/"
else
  cp -R "$SRC_DIR/." "$TARGET/"
fi

SDKMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
AVDMANAGER="$SDK_ROOT/cmdline-tools/latest/bin/avdmanager"

if [ ! -x "$SDKMANAGER" ]; then
  echo "sdkmanager not found at $SDKMANAGER" >&2
  exit 5
fi

API_LEVEL=${ANDROID_API:-30}

echo "Detected host arch: $(uname -m)"
HOST_ARCH=$(uname -m)
if [[ "$HOST_ARCH" == "arm64" || "$HOST_ARCH" == "aarch64" ]]; then
  ABI="arm64-v8a"
else
  ABI="x86_64"
fi

SYSTEM_IMAGE="system-images;android-${API_LEVEL};google_apis;${ABI}"

echo "Installing platform-tools, emulator, platforms and system-images (API ${API_LEVEL}, ABI ${ABI})..."
# Ensure we run sdkmanager with a Java 11+ runtime by setting JAVA_HOME if possible
if [ -z "${JAVA_HOME:-}" ] || { command -v java >/dev/null 2>&1 && java -version 2>&1 | sed -n 's/.*version "\([^\"]*\)".*/\1/p' | awk -F. '{ if ($1=="1") print $2; else print $1 }' | awk '{exit ($1>=11?0:1)}'; } ; then
  # Prefer Homebrew openjdk@11 if available, else /usr/libexec/java_home, then common locations
  if command -v brew >/dev/null 2>&1 && brew --prefix openjdk@11 >/dev/null 2>&1; then
    bprefix=$(brew --prefix openjdk@11)
    JAVA_HOME="$bprefix/libexec/openjdk.jdk/Contents/Home"
  elif /usr/libexec/java_home -v 11 >/dev/null 2>&1; then
    JAVA_HOME=$(/usr/libexec/java_home -v 11)
  else
    # Try common JVM install locations
    for p in /Library/Java/JavaVirtualMachines/*jdk-11*/Contents/Home /Library/Java/JavaVirtualMachines/*openjdk-11*/Contents/Home; do
      if [ -d "$p" ]; then
        JAVA_HOME="$p"
        break
      fi
    done
  fi
  if [ -z "${JAVA_HOME:-}" ]; then
    echo "Java 11+ not found. Please install a JDK 11+ (e.g. brew install openjdk@11) and set JAVA_HOME." >&2
    exit 7
  fi
  echo "Using JAVA_HOME=$JAVA_HOME for sdkmanager"
fi

PKGS=("platform-tools" "emulator" "platforms;android-${API_LEVEL}" "${SYSTEM_IMAGE}")
export JAVA_HOME
# Ensure the selected Java is used by sdkmanager
export PATH="$JAVA_HOME/bin:$PATH"
echo "Using java: $(which java) -> $(java -version 2>&1 | sed -n '1p')"
# Accept licenses and install packages using the located JAVA_HOME
yes | "$SDKMANAGER" --sdk_root="$SDK_ROOT" "${PKGS[@]}" >/dev/null

echo "Accepting licenses..."
yes | "$SDKMANAGER" --sdk_root="$SDK_ROOT" --licenses >/dev/null || true

# Ensure platform-tools and emulator are installed
if [ ! -x "$SDK_ROOT/platform-tools/adb" ] || [ ! -x "$SDK_ROOT/emulator/emulator" ]; then
  echo "Installation incomplete: platform-tools or emulator missing." >&2
  echo "Please re-run sdkmanager to install required components." >&2
  exit 6
fi

if [ -n "${ZSH_VERSION:-}" ]; then
  RC="$HOME/.zshrc"
  add_to_rc "$RC"
  echo "Added SDK exports to $RC. Run: source $RC"
elif [ -n "${BASH_VERSION:-}" ]; then
  RC="$HOME/.bashrc"
  add_to_rc "$RC"
  echo "Added SDK exports to $RC. Run: source $RC"
else
  RC="$HOME/.profile"
  add_to_rc "$RC"
  echo "Added SDK exports to $RC. Run: source $RC"
fi

# Create a default AVD if not present
AVD_NAME="rfdc_avd"
  if command -v "$AVDMANAGER" >/dev/null 2>&1; then
  if ! "$AVDMANAGER" list avd | grep -q "$AVD_NAME"; then
    echo "Creating AVD $AVD_NAME using system-image ${SYSTEM_IMAGE}"
    echo "no" | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "${SYSTEM_IMAGE}" --force >/dev/null
    echo "AVD $AVD_NAME created. Use scripts/start_emulator.sh $AVD_NAME to boot it."
  else
    echo "AVD $AVD_NAME already exists." 
  fi
else
  echo "avdmanager not found; skipping AVD creation." >&2
fi

echo "Android SDK setup complete."
echo "Source your shell rc (e.g. source ~/.zshrc) or open a new terminal to pick up PATH changes."
