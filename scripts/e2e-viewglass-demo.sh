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
LOCAL_SERVER_REPO="$(cd "$ROOT_DIR/.." && pwd)/ViewglassServer"
E2E_PROJECT_SPEC="$DEMO_DIR/project.e2e.yml"

mkdir -p "$ARTIFACT_DIR"
trap 'rm -f "$E2E_PROJECT_SPEC"' EXIT

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

run_viewglass_capture() {
  local __var_name="$1"
  shift
  local output=""
  output="$(run_viewglass "$@")"
  printf -v "$__var_name" '%s' "$output"
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

json_attr_string() {
  local json_input="$1"
  local accepted_csv="$2"
  JSON_INPUT="$json_input" python3 - "$accepted_csv" <<'PY'
import json
import os
import sys

accepted = {item.strip().lower() for item in sys.argv[1].split(",") if item.strip()}
data = json.loads(os.environ["JSON_INPUT"])
groups = data["attributes"] if isinstance(data, dict) and "attributes" in data else data
for group in groups:
    for attr in group.get("attributes", []):
        names = []
        if attr.get("key"):
            names.append(str(attr["key"]).lower())
        if attr.get("displayName"):
            names.append(str(attr["displayName"]).lower())
        if not any(name in accepted for name in names):
            continue
        value = attr.get("value", {})
        string_value = value.get("string", {}).get("_0")
        if string_value is not None:
            print(string_value)
            sys.exit(0)
print("")
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
    if [[ -d "$LOCAL_SERVER_REPO" ]]; then
      python3 - "$DEMO_DIR/project.yml" "$E2E_PROJECT_SPEC" "$LOCAL_SERVER_REPO" <<'PY'
from pathlib import Path
import sys

source = Path(sys.argv[1]).read_text()
output = Path(sys.argv[2])
local_repo = sys.argv[3]

replacement = f"""packages:
  ViewglassServer:
    path: {local_repo}
"""

needle = """packages:
  ViewglassServer:
    url: https://github.com/WZBbiao/ViewglassServer.git
    branch: main
"""

if needle not in source:
    raise SystemExit("Failed to rewrite ViewglassServer package block in project.yml")

output.write_text(source.replace(needle, replacement))
PY
      xcodegen generate --spec "$E2E_PROJECT_SPEC" >/dev/null
    else
      xcodegen generate >/dev/null
    fi
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

assert_locator_exists() {
  local locator="$1"
  local locate_json
  locate_json="$(run_viewglass locate "$locator" --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$locate_json" 'len(data["matches"])')"
  if [[ "$count" -lt 1 ]]; then
    echo "Expected locator $locator to resolve at least once" >&2
    exit 1
  fi
}

tap_locator() {
  local locator="$1"
  run_viewglass tap "$locator" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
}

long_press_locator() {
  local locator="$1"
  run_viewglass long-press "$locator" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
}

input_locator() {
  local locator="$1"
  local text="$2"
  run_viewglass input "$locator" --text "$text" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
}

assert_controller_present() {
  local locator="$1"
  local query_json
  query_json="$(run_viewglass query "$locator" --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$query_json" 'len(data)')"
  if [[ "$count" -lt 1 ]]; then
    echo "Expected controller locator $locator to return at least one node" >&2
    exit 1
  fi
}

presented_controller_oid() {
  local locator="$1"
  local query_json
  query_json="$(run_viewglass query "$locator" --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$query_json" 'len(data)')"
  if [[ "$count" -lt 1 ]]; then
    echo "Expected controller locator $locator to return at least one node" >&2
    exit 1
  fi
  json_query "$query_json" 'data[0]["hostViewControllerOid"]'
}

assert_status_text() {
  local locator="$1"
  local expected="$2"
  local attr_json actual
  attr_json="$(run_viewglass attr get "$locator" --session "$SESSION_SPEC" --json)"
  actual="$(json_attr_string "$attr_json" "text,displayText,lb_t_t,la_t,tf_t_t,te_t_t")"
  if [[ "$actual" != "$expected" ]]; then
    echo "Expected $locator text '$expected', got '$actual'" >&2
    exit 1
  fi
}

assert_status_contains() {
  local locator="$1"
  local expected_fragment="$2"
  local attr_json actual
  attr_json="$(run_viewglass attr get "$locator" --session "$SESSION_SPEC" --json)"
  actual="$(json_attr_string "$attr_json" "text,displayText,lb_t_t,la_t,tf_t_t,te_t_t")"
  if [[ "$actual" != *"$expected_fragment"* ]]; then
    echo "Expected $locator text to contain '$expected_fragment', got '$actual'" >&2
    exit 1
  fi
}

scroll_feed_and_verify() {
  local before_json after_json before_offset after_offset
  before_json="$(run_viewglass attr get "#long_feed_scroll" --session "$SESSION_SPEC" --json)"
  before_offset="$(json_query "$before_json" 'next(attr["value"]["string"]["_0"] for group in data["attributes"] for attr in group["attributes"] if attr["key"] == "sv_o_o")')"
  if [[ "$before_offset" != "NSPoint: {0, 0}" ]]; then
    echo "Unexpected initial contentOffset: $before_offset" >&2
    exit 1
  fi

  run_viewglass scroll "#long_feed_scroll" --to 0,320 --session "$SESSION_SPEC" --json >/dev/null

  after_json="$(run_viewglass attr get "#long_feed_scroll" --session "$SESSION_SPEC" --json)"
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
  tap_locator "#push_buttons_screen"
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/buttons-page.png" --json >/dev/null
  tap_locator "#open_alert"
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/alert.png" --json >/dev/null
  local alert_controller_oid
  alert_controller_oid="$(assert_alert_present)"
  run_viewglass dismiss "$alert_controller_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  assert_alert_dismissed

  tap_locator "#open_action_sheet"
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/action-sheet.png" --json >/dev/null
  local action_sheet_controller_oid
  action_sheet_controller_oid="$(assert_alert_present)"
  run_viewglass dismiss "$action_sheet_controller_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  assert_alert_dismissed

  tap_locator "#open_page_sheet"
  sleep 1
  assert_controller_present "controller:ModalCardViewController"
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/page-sheet.png" --json >/dev/null
  tap_locator "#dismiss_modal"

  tap_locator "#open_full_screen"
  sleep 1
  assert_controller_present "controller:ModalCardViewController"
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/full-screen.png" --json >/dev/null
  tap_locator "#dismiss_modal"

  launch_demo
  tap_locator "#push_gestures_screen"
  assert_locator_exists "#gesture_status"
  tap_locator "#tappable_label"
  assert_status_text "#gesture_status" "Tap gesture fired"
  long_press_locator "#long_press_card"
  assert_status_text "#gesture_status" "Long press fired"
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/gestures.png" --json >/dev/null

  launch_demo
  tap_locator "#switch_tab_forms"
  assert_locator_exists "#primary_text_field"
  tap_locator "#switch_tab_feed"
  assert_locator_exists "#long_feed_scroll"
  tap_locator "#switch_tab_home"
  assert_locator_exists "#push_buttons_screen"

  launch_demo
  tap_locator "#switch_tab_forms"
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/forms.png" --json >/dev/null
  assert_forms_surface
  input_locator "#primary_text_field" "agent@example.com"
  input_locator "#secure_text_field" "hunter2!"
  input_locator "#notes_text_view" "Agent entered multiline notes."
  assert_status_contains "#forms_status" "Email: agent@example.com"
  assert_status_contains "#forms_status" "Password: 8 chars"
  assert_status_contains "#forms_status" "Notes: 30 chars"
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/forms-after-input.png" --json >/dev/null

  launch_demo
  tap_locator "#push_feed_screen"
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/feed-before-scroll.png" --json >/dev/null
  scroll_feed_and_verify
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/feed-after-scroll.png" --json >/dev/null

  echo "All ViewglassDemo E2E scenarios passed"
}

main "$@"
