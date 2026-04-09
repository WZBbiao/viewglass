#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Demo/ViewglassDemo"
SIMULATOR_UDID="CE2FFAB6-957B-4647-B331-5E5DC61A54AF"
APP_BUNDLE_ID="com.wzb.ViewglassDemo"
SESSION_SPEC="${APP_BUNDLE_ID}@47164"
DERIVED_DATA_DIR="/tmp/ViewglassDemoDerivedData"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/ViewglassDemo.app"
ARTIFACT_DIR="/tmp/viewglass-demo-e2e"

mkdir -p "$ARTIFACT_DIR"

run_viewglass() {
  local output=""
  local exit_code=0
  local attempt=0

  for attempt in 1 2 3; do
    if output="$("$ROOT_DIR/.build/debug/viewglass" "$@" 2>&1)"; then
      printf '%s\n' "$output"
      return 0
    fi
    exit_code=$?
    sleep 1
  done

  printf '%s\n' "$output" >&2
  return "$exit_code"
}

json_query() {
  local json_input="$1"
  local expression="$2"
  JSON_INPUT="$json_input" python3 - "$expression" <<'PY'
import json
import os
import sys

expr = sys.argv[1]
data = json.loads(os.environ["JSON_INPUT"])
namespace = {"data": data}
safe_builtins = {"len": len, "sorted": sorted, "next": next}
result = eval(expr, {"__builtins__": safe_builtins}, namespace)
if isinstance(result, (dict, list)):
    print(json.dumps(result))
elif result is None:
    print("")
else:
    print(result)
PY
}

ensure_debug_cli() {
  (
    cd "$ROOT_DIR"
    swift build -c debug --disable-sandbox >/dev/null
  )
}

build_demo() {
  (
    cd "$DEMO_DIR"
    xcodegen generate >/dev/null
    xcodebuild \
      -project ViewglassDemo.xcodeproj \
      -scheme ViewglassDemo \
      -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
      -derivedDataPath "$DERIVED_DATA_DIR" \
      build >/dev/null
  )
}

install_demo() {
  xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH" >/dev/null
}

prepare_simulator() {
  xcrun simctl shutdown 8DE39716-E197-466F-9FE5-5938A7726C3B >/dev/null 2>&1 || true
  xcrun simctl shutdown E487EE87-BA68-4A03-955A-A93507361E82 >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b >/dev/null
}

launch_demo() {
  xcrun simctl terminate "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null
  sleep 2
}

home_button_oid() {
  local index="$1"
  local buttons_json
  buttons_json="$(run_viewglass query UIButton --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$buttons_json" 'len(data)')"
  if [[ "$count" -lt 5 ]]; then
    echo "Expected 5 home buttons, got $count" >&2
    exit 1
  fi
  json_query "$buttons_json" "sorted(data, key=lambda item: item['frame']['y'])[$index]['oid']"
}

buttons_page_button_oid() {
  local index="$1"
  local buttons_json
  buttons_json="$(run_viewglass query UIButton --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$buttons_json" 'len(data)')"
  if [[ "$count" -lt 4 ]]; then
    echo "Expected at least 4 modal-state buttons, got $count" >&2
    exit 1
  fi
  json_query "$buttons_json" "sorted(data, key=lambda item: item['frame']['y'])[$index]['oid']"
}

assert_alert_present() {
  local alert_json
  alert_json="$(run_viewglass query UIAlertController --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$alert_json" 'len(data)')"
  if [[ "$count" -ne 1 ]]; then
    echo "Expected exactly one UIAlertController, got $count" >&2
    exit 1
  fi
  json_query "$alert_json" 'data[0]["hostViewControllerOid"]'
}

assert_alert_dismissed() {
  local alert_json
  alert_json="$(run_viewglass query UIAlertController --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$alert_json" 'len(data)')"
  if [[ "$count" -ne 0 ]]; then
    echo "Expected alert to be dismissed, but query still returned $count result(s)" >&2
    exit 1
  fi
}

assert_forms_surface() {
  local fields_json
  fields_json="$(run_viewglass query UITextField --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$fields_json" 'len(data)')"
  if [[ "$count" -lt 2 ]]; then
    echo "Expected at least two UITextField nodes on the forms surface, got $count" >&2
    exit 1
  fi
}

scroll_feed_and_verify() {
  local scroll_json scroll_oid before_json after_json before_offset after_offset
  scroll_json="$(run_viewglass query UIScrollView --session "$SESSION_SPEC" --json)"
  scroll_oid="$(json_query "$scroll_json" 'data[0]["oid"]')"

  before_json="$(run_viewglass attr get "$scroll_oid" --session "$SESSION_SPEC" --json)"
  before_offset="$(json_query "$before_json" 'next(attr["value"]["string"]["_0"] for group in data["attributes"] for attr in group["attributes"] if attr["key"] == "sv_o_o")')"
  if [[ "$before_offset" != "NSPoint: {0, 0}" ]]; then
    echo "Unexpected initial contentOffset: $before_offset" >&2
    exit 1
  fi

  run_viewglass scroll "$scroll_oid" --to 0,320 --session "$SESSION_SPEC" --json >/dev/null

  after_json="$(run_viewglass attr get "$scroll_oid" --session "$SESSION_SPEC" --json)"
  after_offset="$(json_query "$after_json" 'next(attr["value"]["string"]["_0"] for group in data["attributes"] for attr in group["attributes"] if attr["key"] == "sv_o_o")')"
  if [[ "$after_offset" != "NSPoint: {0, 320}" ]]; then
    echo "Expected contentOffset to become {0, 320}, got $after_offset" >&2
    exit 1
  fi
}

main() {
  prepare_simulator
  ensure_debug_cli
  build_demo
  install_demo

  launch_demo
  local home_alert_button_oid
  home_alert_button_oid="$(home_button_oid 0)"
  run_viewglass tap "$home_alert_button_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/buttons-page.png" --json >/dev/null
  local alert_button_oid
  alert_button_oid="$(buttons_page_button_oid 0)"
  run_viewglass tap "$alert_button_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/alert.png" --json >/dev/null
  local alert_controller_oid
  alert_controller_oid="$(assert_alert_present)"
  run_viewglass dismiss "$alert_controller_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  assert_alert_dismissed

  launch_demo
  local forms_button_oid
  forms_button_oid="$(home_button_oid 1)"
  run_viewglass tap "$forms_button_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/forms.png" --json >/dev/null
  assert_forms_surface

  launch_demo
  local feed_button_oid
  feed_button_oid="$(home_button_oid 2)"
  run_viewglass tap "$feed_button_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/feed-before-scroll.png" --json >/dev/null
  scroll_feed_and_verify
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/feed-after-scroll.png" --json >/dev/null

  echo "All ViewglassDemo E2E scenarios passed"
}

main "$@"
