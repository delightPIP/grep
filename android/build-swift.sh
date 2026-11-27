#!/usr/bin/env bash
# WSL Ubuntu 또는 macOS/Linux에서 Android용 libGrepBridge.so와 swift-java 바인딩을 빌드한다.
# 사용법:
#   bash android/build-swift.sh                 # arm64-v8a release .so 빌드
#   bash android/build-swift.sh x86_64          # x86_64 에뮬레이터용 빌드
#   bash android/build-swift.sh test            # 호스트에서 Swift 단위 테스트 실행
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_DIR="$SCRIPT_DIR/swift"

if [ -f "$HOME/.profile" ]; then
  # shellcheck disable=SC1091
  source "$HOME/.profile" 2>/dev/null || true
fi
if [ -x "/opt/swift/usr/bin/swift" ]; then
  export PATH="/opt/swift/usr/bin:$PATH"
fi

set -u

SWIFT_BIN="${SWIFT_CLI:-$(command -v swift)}"
ANDROID_API="${SWIFT_ANDROID_API:-28}"
export ANDROID_NDK_HOME="${ANDROID_NDK_HOME:-$HOME/Android/Sdk/ndk/30.0.16248370}"
export JAVA_HOME="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"

MODE="${1:-arm64-v8a}"

cd "$SWIFT_DIR"
if [ "$MODE" = "test" ]; then
  exec "$SWIFT_BIN" test --disable-sandbox
fi

case "$MODE" in
  arm64-v8a) TRIPLE="aarch64-unknown-linux-android${ANDROID_API}" ;;
  x86_64)    TRIPLE="x86_64-unknown-linux-android${ANDROID_API}" ;;
  *)
    echo "Unsupported ABI: $MODE (use arm64-v8a, x86_64, or test)" >&2
    exit 1
    ;;
esac

exec "$SWIFT_BIN" build --disable-sandbox --swift-sdk "$TRIPLE" -c release
