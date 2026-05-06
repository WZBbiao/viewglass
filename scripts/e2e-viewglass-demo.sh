#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DEMO_DIR="$ROOT_DIR/Demo/ViewglassDemo"
SIMULATOR_UDID="CE2FFAB6-957B-4647-B331-5E5DC61A54AF"
APP_BUNDLE_ID="com.wzb.ViewglassDemo"
SESSION_SPEC="${APP_BUNDLE_ID}@47164"
DERIVED_DATA_DIR="$(mktemp -d /tmp/ViewglassDemoDerivedData.XXXXXX)"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/ViewglassDemo.app"
ARTIFACT_DIR="/tmp/viewglass-demo-e2e"
LOCAL_SERVER_REPO="$(cd "$ROOT_DIR/.." && pwd)/ViewglassServer"
E2E_PROJECT_SPEC="$DEMO_DIR/project.e2e.yml"

mkdir -p "$ARTIFACT_DIR"
trap 'rm -f "$E2E_PROJECT_SPEC"; rm -rf "$DERIVED_DATA_DIR"' EXIT

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
attrs = data.get("attributes", data) if isinstance(data, dict) else data

if isinstance(attrs, dict):
    # New flat format: {"readable_key": value, ...}
    for key, value in attrs.items():
        if key.lower() in accepted and value is not None:
            print(value if isinstance(value, str) else str(value))
            sys.exit(0)
    print("")
    sys.exit(0)

# Old nested format: list of attribute groups
for group in attrs:
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
  xcrun simctl boot "$SIMULATOR_UDID" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$SIMULATOR_UDID" -b >/dev/null
}

launch_demo() {
  # Terminate ViewglassDemo on every booted simulator to free port 47164
  # (multiple simulators sharing localhost would cause the wrong one to hold the port).
  while IFS= read -r udid; do
    xcrun simctl terminate "$udid" "$APP_BUNDLE_ID" >/dev/null 2>&1 || true
  done < <(xcrun simctl list devices --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
for devices in data['devices'].values():
    for d in devices:
        if d.get('state') == 'Booted':
            print(d['udid'])
")
  sleep 0.5
  SIMCTL_CHILD_VIEWGLASS_DEMO_FLOATING_KEY_WINDOW=1 xcrun simctl launch "$SIMULATOR_UDID" "$APP_BUNDLE_ID" >/dev/null
  run_viewglass wait appears "#push_buttons_screen" --session "$SESSION_SPEC" --timeout 12 --interval-ms 500 --json >/dev/null
}

assert_alert_present() {
  local alert_json
  alert_json="$(run_viewglass query "controller:UIAlertController" --session "$SESSION_SPEC" --json)"
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
  alert_json="$(run_viewglass query "controller:UIAlertController" --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$alert_json" 'len(data)')"
  if [[ "$count" -ne 0 ]]; then
    echo "Expected alert to be dismissed, but query still returned $count result(s)" >&2
    exit 1
  fi
}

alert_action_oid() {
  local title="$1"
  local query_json
  query_json="$(run_viewglass query "contains:\"$title\" AND *Action*" --session "$SESSION_SPEC" --json)"
  JSON_INPUT="$query_json" python3 - "$title" <<'PY'
import json
import os
import sys

title = sys.argv[1]
nodes = json.loads(os.environ["JSON_INPUT"])
preferred = [
    node for node in nodes
    if node.get("accessibilityLabel") == title and node.get("className") == "_UIAlertControllerActionView"
]
fallback = [
    node for node in nodes
    if node.get("accessibilityLabel") == title and "Action" in node.get("className", "")
]
matches = preferred or fallback
if not matches:
    raise SystemExit(f"Expected an alert action view titled {title!r}")
print(matches[0]["oid"])
PY
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

assert_query_count_at_least() {
  local locator="$1"
  local minimum="$2"
  local query_json
  query_json="$(run_viewglass query "$locator" --session "$SESSION_SPEC" --json)"
  local count
  count="$(json_query "$query_json" 'len(data)')"
  if [[ "$count" -lt "$minimum" ]]; then
    echo "Expected query $locator to return at least $minimum result(s), got $count" >&2
    exit 1
  fi
}

assert_hierarchy_system_noise_absent() {
  local hierarchy_json
  hierarchy_json="$(run_viewglass hierarchy --session "$SESSION_SPEC" --json)"
  JSON_INPUT="$hierarchy_json" python3 <<'PY'
import json
import os

data = json.loads(os.environ["JSON_INPUT"])
noise = [
    "_UITouchPassthroughView",
    "_UIFloatingBarContainerView",
    "FloatingBarHostingView",
    "FloatingBarContainer",
    "_UIPointerInteractionAssistantEffectContainerView",
    "ScrollEdgeEffectView",
    "_UIPortalView",
    "_UITabBarContainerWrapperView",
    "_UITabBarContainerView",
    "_UIMultiLayer",
]
matches = []

def walk(tree):
    node = tree.get("node", {})
    class_name = node.get("className", "")
    if any(term in class_name for term in noise):
        matches.append(f'{node.get("oid")}:{class_name}')
    for child in tree.get("children", []):
        walk(child)

for window in data.get("windows", []):
    walk(window)

if matches:
    raise SystemExit("Expected UIKit system noise to be filtered, found: " + ", ".join(matches[:20]))
PY
}

assert_screenshot_has_visible_content() {
  local image_path="$1"
  local bmp_path="${image_path}.bmp"
  /usr/bin/sips -s format bmp "$image_path" --out "$bmp_path" >/dev/null
  python3 - "$bmp_path" <<'PY'
import struct
import sys

path = sys.argv[1]
data = open(path, "rb").read()
if data[:2] != b"BM":
    raise SystemExit(f"Expected BMP data from {path}")

offset = struct.unpack_from("<I", data, 10)[0]
width = struct.unpack_from("<i", data, 18)[0]
height = struct.unpack_from("<i", data, 22)[0]
bpp = struct.unpack_from("<H", data, 28)[0]
if width <= 0 or height == 0 or bpp not in (24, 32):
    raise SystemExit(f"Unsupported BMP shape: {width}x{height} bpp={bpp}")

abs_height = abs(height)
bytes_per_pixel = bpp // 8
row_size = ((width * bpp + 31) // 32) * 4
step = max(1, min(width, abs_height) // 80)
sampled = 0
non_black = 0
for y in range(0, abs_height, step):
    row_y = abs_height - 1 - y if height > 0 else y
    row = offset + row_y * row_size
    for x in range(0, width, step):
        pixel = row + x * bytes_per_pixel
        b, g, r = data[pixel], data[pixel + 1], data[pixel + 2]
        sampled += 1
        if max(r, g, b) > 35 and (r + g + b) > 80:
            non_black += 1

ratio = non_black / sampled if sampled else 0
if ratio < 0.03:
    raise SystemExit(f"Screenshot is mostly black/empty: non-black sample ratio {ratio:.4f}")
PY
  rm -f "$bmp_path"
}

assert_screenshot_region_has_visible_content() {
  local image_path="$1"
  local nodes_json="$2"
  local min_ratio="${3:-0.12}"
  local bmp_path="${image_path}.region.bmp"
  /usr/bin/sips -s format bmp "$image_path" --out "$bmp_path" >/dev/null
  NODES_JSON="$nodes_json" python3 - "$bmp_path" "$min_ratio" <<'PY'
import json
import os
import struct
import sys

path = sys.argv[1]
min_ratio = float(sys.argv[2])
nodes = json.loads(os.environ["NODES_JSON"])
if not nodes:
    raise SystemExit("No node frame available for screenshot region assertion")
frame = nodes[0].get("frame") or {}
fx = float(frame.get("x", 0))
fy = float(frame.get("y", 0))
fw = float(frame.get("width", 0))
fh = float(frame.get("height", 0))
if fw <= 0 or fh <= 0:
    raise SystemExit(f"Invalid node frame: {frame}")

data = open(path, "rb").read()
if data[:2] != b"BM":
    raise SystemExit(f"Expected BMP data from {path}")
offset = struct.unpack_from("<I", data, 10)[0]
width = struct.unpack_from("<i", data, 18)[0]
height = struct.unpack_from("<i", data, 22)[0]
bpp = struct.unpack_from("<H", data, 28)[0]
if width <= 0 or height == 0 or bpp not in (24, 32):
    raise SystemExit(f"Unsupported BMP shape: {width}x{height} bpp={bpp}")

abs_height = abs(height)
bytes_per_pixel = bpp // 8
row_size = ((width * bpp + 31) // 32) * 4

screen_points_width = fx * 2 + fw
scale = width / screen_points_width if screen_points_width > 0 else 1
x0 = max(0, int((fx + fw * 0.15) * scale))
x1 = min(width, int((fx + fw * 0.85) * scale))
y0 = max(0, int((fy + fh * 0.15) * scale))
y1 = min(abs_height, int((fy + fh * 0.85) * scale))
if x1 <= x0 or y1 <= y0:
    raise SystemExit(f"Computed empty crop for frame={frame}, image={width}x{abs_height}, scale={scale:.3f}")

step = max(1, min(x1 - x0, y1 - y0) // 60)
sampled = 0
non_black = 0
for y in range(y0, y1, step):
    row_y = abs_height - 1 - y if height > 0 else y
    row = offset + row_y * row_size
    for x in range(x0, x1, step):
        pixel = row + x * bytes_per_pixel
        b, g, r = data[pixel], data[pixel + 1], data[pixel + 2]
        sampled += 1
        if max(r, g, b) > 35 and (r + g + b) > 90:
            non_black += 1

ratio = non_black / sampled if sampled else 0
if ratio < min_ratio:
    raise SystemExit(
        f"Screenshot region is too black: ratio {ratio:.4f}, expected >= {min_ratio:.4f}, "
        f"crop=({x0},{y0})-({x1},{y1}), frame={frame}, image={width}x{abs_height}"
    )
PY
  rm -f "$bmp_path"
}

assert_full_screen_screenshot() {
  local output_path="$1"
  local allow_mostly_black="${2:-false}"
  local screenshot_json width height provider fallback_reason warnings_count
  screenshot_json="$(run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$output_path" --json)"
  width="$(json_query "$screenshot_json" 'data["width"]')"
  height="$(json_query "$screenshot_json" 'data["height"]')"
  provider="$(json_query "$screenshot_json" 'data.get("captureProvider", "")')"
  fallback_reason="$(json_query "$screenshot_json" 'data.get("fallbackReason", "")')"
  warnings_count="$(json_query "$screenshot_json" 'len(data.get("qualityWarnings", []))')"
  if [[ "$width" -lt 1000 || "$height" -lt 2000 ]]; then
    echo "Expected full-screen screenshot to be at least 1000x2000 px, got ${width}x${height}" >&2
    echo "$screenshot_json" >&2
    exit 1
  fi
  if [[ "$provider" != "simctl" && "$provider" != "server" ]]; then
    echo "Expected simulator full-screen screenshot provider to be simctl or server fallback, got '$provider'" >&2
    echo "$screenshot_json" >&2
    exit 1
  fi
  if [[ "$provider" == "server" && -z "$fallback_reason" ]]; then
    echo "Expected server fallback screenshot to include fallbackReason" >&2
    echo "$screenshot_json" >&2
    exit 1
  fi
  if [[ "$provider" == "server" ]]; then
    if [[ "$warnings_count" -ne 0 ]]; then
      echo "Expected server fallback screenshot to avoid quality warnings" >&2
      echo "$screenshot_json" >&2
      exit 1
    fi
    assert_screenshot_has_visible_content "$output_path"
    return
  fi
  if [[ "$allow_mostly_black" == "true" ]]; then
    local has_mostly_black
    has_mostly_black="$(json_query "$screenshot_json" '"mostlyBlack" in data.get("qualityWarnings", [])')"
    if [[ "$has_mostly_black" != "True" ]]; then
      echo "Expected mostlyBlack quality warning for intentionally empty overlay screenshot" >&2
      echo "$screenshot_json" >&2
      exit 1
    fi
  else
    if [[ "$warnings_count" -ne 0 ]]; then
      echo "Expected simulator full-screen screenshot to have no quality warnings" >&2
      echo "$screenshot_json" >&2
      exit 1
    fi
    assert_screenshot_has_visible_content "$output_path"
  fi
}

assert_server_fallback_screenshot() {
  local output_path="$1"
  local screenshot_json provider fallback_reason warnings_count
  screenshot_json="$(run_viewglass screenshot screen --session "$SESSION_SPEC" --udid "invalid-host-provider-for-e2e" -o "$output_path" --json)"
  provider="$(json_query "$screenshot_json" 'data.get("captureProvider", "")')"
  fallback_reason="$(json_query "$screenshot_json" 'data.get("fallbackReason", "")')"
  warnings_count="$(json_query "$screenshot_json" 'len(data.get("qualityWarnings", []))')"
  if [[ "$provider" != "server" ]]; then
    echo "Expected forced host failure to fall back to server provider, got '$provider'" >&2
    echo "$screenshot_json" >&2
    exit 1
  fi
  if [[ -z "$fallback_reason" ]]; then
    echo "Expected server fallback screenshot to include fallbackReason" >&2
    echo "$screenshot_json" >&2
    exit 1
  fi
  if [[ "$warnings_count" -ne 0 ]]; then
    echo "Expected server fallback screenshot to avoid quality warnings" >&2
    echo "$screenshot_json" >&2
    exit 1
  fi
  assert_screenshot_has_visible_content "$output_path"
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
  actual="$(json_attr_string "$attr_json" "text,displayText,lb_t_t,la_t,tf_t_t,te_t_t,textField.text,textView.text")"
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
  actual="$(json_attr_string "$attr_json" "text,displayText,lb_t_t,la_t,tf_t_t,te_t_t,textField.text,textView.text")"
  if [[ "$actual" != *"$expected_fragment"* ]]; then
    echo "Expected $locator text to contain '$expected_fragment', got '$actual'" >&2
    exit 1
  fi
}

read_content_offset() {
  local locator="$1"
  local attr_json
  attr_json="$(run_viewglass attr get "$locator" --session "$SESSION_SPEC" --json)"
  JSON_INPUT="$attr_json" python3 <<'PY'
import json, os
data = json.loads(os.environ["JSON_INPUT"])
attrs = data.get("attributes", {})
if isinstance(attrs, dict):
    print(attrs.get("contentOffset", ""))
else:
    val = next((a["value"]["string"]["_0"] for g in attrs for a in g.get("attributes", []) if a.get("key") == "sv_o_o"), "")
    print(val)
PY
}

scroll_feed_and_verify() {
  local before_offset after_to_offset after_by_offset
  before_offset="$(read_content_offset "#long_feed_scroll")"
  if [[ "$before_offset" != "NSPoint: {0, 0}" ]]; then
    echo "Unexpected initial contentOffset: $before_offset" >&2
    exit 1
  fi

  run_viewglass scroll "#long_feed_scroll" --to 0,320 --session "$SESSION_SPEC" --json >/dev/null

  after_to_offset="$(read_content_offset "#long_feed_scroll")"
  if [[ "$after_to_offset" != "NSPoint: {0, 320}" ]]; then
    echo "Expected contentOffset to become {0, 320}, got $after_to_offset" >&2
    exit 1
  fi

  run_viewglass scroll "#long_feed_scroll" --by 0,80 --session "$SESSION_SPEC" --json >/dev/null

  after_by_offset="$(read_content_offset "#long_feed_scroll")"
  if [[ "$after_by_offset" != "NSPoint: {0, 400}" ]]; then
    echo "Expected contentOffset to become {0, 400} after --by scroll, got $after_by_offset" >&2
    exit 1
  fi
}

main() {
  prepare_simulator
  ensure_debug_cli
  build_demo
  install_demo

  launch_demo
  assert_hierarchy_system_noise_absent
  tap_locator "#push_buttons_screen"
  sleep 1
  assert_hierarchy_system_noise_absent
  assert_full_screen_screenshot "$ARTIFACT_DIR/buttons-page.png"
  assert_server_fallback_screenshot "$ARTIFACT_DIR/buttons-page-server-fallback.png"
  tap_locator "#show_empty_overlay_window"
  sleep 0.2
  assert_full_screen_screenshot "$ARTIFACT_DIR/buttons-empty-overlay.png" true
  tap_locator "#open_alert"
  sleep 1
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/alert.png" --json >/dev/null
  local alert_controller_oid
  alert_controller_oid="$(assert_alert_present)"
  run_viewglass dismiss "$alert_controller_oid" --session "$SESSION_SPEC" --json >/dev/null
  sleep 1
  assert_alert_dismissed
  tap_locator "#open_alert"
  sleep 1
  assert_alert_present >/dev/null
  local ship_action_oid
  ship_action_oid="$(alert_action_oid "Ship")"
  run_viewglass tap "$ship_action_oid" --session "$SESSION_SPEC" --json >/dev/null
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
  local coordinate_tap_json coordinate_strategy
  coordinate_tap_json="$(run_viewglass tap "#coordinate_fallback_wrapper" --session "$SESSION_SPEC" --json)"
  coordinate_strategy="$(json_query "$coordinate_tap_json" 'data["strategyUsed"]')"
  if [[ "$coordinate_strategy" != "coordinateSemantic" ]]; then
    echo "Expected coordinate fallback strategy, got '$coordinate_strategy'" >&2
    exit 1
  fi
  sleep 1
  assert_status_text "#gesture_status" "Coordinate fallback fired"
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/gestures.png" --json >/dev/null

  launch_demo
  tap_locator "#push_selectable_surfaces_screen"
  assert_locator_exists "#selection_status"
  assert_locator_exists "#table_selection_timeline"
  assert_locator_exists "#collection_selection_timeline"
  tap_locator "#table_row_label_1"
  assert_status_text "#selection_status" "Table selected: Profile"
  assert_status_contains "#table_selection_timeline" "didSelect:Profile"
  tap_locator "#collection_tile_label_2"
  assert_status_text "#selection_status" "Collection selected: Sunset"
  assert_status_contains "#collection_selection_timeline" "didSelect:Sunset"
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/selectable-surfaces.png" --json >/dev/null

  launch_demo
  tap_locator "#switch_tab_forms"
  assert_locator_exists "#primary_text_field"
  assert_query_count_at_least "UITabBar" 1
  assert_query_count_at_least "TabBar" 1
  assert_query_count_at_least "tabbar" 1
  tap_locator "#switch_tab_feed"
  assert_locator_exists "#long_feed_scroll"
  tap_locator "#switch_tab_home"
  assert_locator_exists "#push_buttons_screen"

  launch_demo
  tap_locator "#push_selectable_surfaces_screen"
  assert_query_count_at_least "tableview" 1
  assert_query_count_at_least "collectionview" 1

  launch_demo
  tap_locator "#push_media_screen"
  assert_locator_exists "#media_player"
  assert_locator_exists "#media_web_view"
  assert_locator_exists "#media_web_input_status"
  local web_input_text="Viewglass web editor input ok."
  input_locator "#media_web_view" "$web_input_text"
  assert_status_contains "#media_web_input_status" "Web editor: ${#web_input_text} chars"
  media_player_nodes="$(run_viewglass query "#media_player" --session "$SESSION_SPEC" --json)"
  assert_full_screen_screenshot "$ARTIFACT_DIR/media-webkit-player.png"
  assert_screenshot_region_has_visible_content "$ARTIFACT_DIR/media-webkit-player.png" "$media_player_nodes" 0.12
  run_viewglass screenshot screen --session "$SESSION_SPEC" --udid "invalid-host-provider-for-e2e" -o "$ARTIFACT_DIR/media-webkit-player-server.png" --json >/dev/null
  assert_screenshot_region_has_visible_content "$ARTIFACT_DIR/media-webkit-player-server.png" "$media_player_nodes" 0.12
  run_viewglass screenshot node "#media_player" --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/media-player-node.png" --json >/dev/null
  assert_screenshot_has_visible_content "$ARTIFACT_DIR/media-player-node.png"
  tap_locator "#media_keyboard_field"
  sleep 1
  assert_full_screen_screenshot "$ARTIFACT_DIR/media-keyboard.png"

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
  run_viewglass attr set "#primary_text_field" text "attrset@example.com" --session "$SESSION_SPEC" --json >/dev/null
  assert_status_text "#primary_text_field" "attrset@example.com"
  run_viewglass attr set "#notes_text_view" text "Attr set notes body." --session "$SESSION_SPEC" --json >/dev/null
  assert_status_text "#notes_text_view" "Attr set notes body."
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/forms-after-input.png" --json >/dev/null

  launch_demo
  tap_locator "#push_feed_screen"
  sleep 1
  assert_hierarchy_system_noise_absent
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/feed-before-scroll.png" --json >/dev/null
  scroll_feed_and_verify
  run_viewglass screenshot screen --session "$SESSION_SPEC" -o "$ARTIFACT_DIR/feed-after-scroll.png" --json >/dev/null

  echo "All ViewglassDemo E2E scenarios passed"
}

main "$@"
