#!/usr/bin/env bash

set -euo pipefail

: "${NAKED_UI_GIT_SHA:?NAKED_UI_GIT_SHA must be set}"
: "${NAKED_UI_FLUTTER_VERSION:?NAKED_UI_FLUTTER_VERSION must be set}"

device_id="emulator-${EMULATOR_PORT:-5554}"
adb -s "$device_id" get-state

(
  cd packages/example

  flutter test -r compact \
    -d "$device_id" \
    integration_test/all_tests.dart

  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/screenshot_smoke.dart \
    -d "$device_id" \
    --dart-define=NAKED_UI_CAPTURE_SCREENSHOTS=true \
    --dart-define="NAKED_UI_GIT_SHA=$NAKED_UI_GIT_SHA" \
    --dart-define="NAKED_UI_FLUTTER_VERSION=$NAKED_UI_FLUTTER_VERSION"

  test -s build/integration_test_screenshots/dialog__open__android__reference.png
  test -s build/integration_test_screenshots/alert_dialog__destructive_action__android__reference.png
  test -s build/integration_test_screenshots/toggle_group__vertical_disabled__android__reference.png
  test -s build/integration_test_screenshots/manifest.json
)
