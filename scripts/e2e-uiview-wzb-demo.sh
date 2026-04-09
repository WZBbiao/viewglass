#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/Users/wangzhenbiao/works/lookin"
BIN="${VIEWGLASS_BIN:-$ROOT_DIR/.build/debug/viewglass}"
APP_DIR="${UIVIEW_WZB_APP_DIR:-/Users/wangzhenbiao/private/private-github-repo/UIView-WZB/Demo/Swift/UIView-WZB}"
WORKSPACE="$APP_DIR/UIView-WZB.xcworkspace"
SCHEME="UIView-WZB"
BUNDLE_ID="com.wzb.UIView-WZB"
SIMULATOR_UDID="${SIMULATOR_UDID:-CE2FFAB6-957B-4647-B331-5E5DC61A54AF}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/viewglass-demo-derived}"
ARTIFACT_DIR="${ARTIFACT_DIR:-/tmp/viewglass-e2e}"

mkdir -p "$ARTIFACT_DIR"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd jq
require_cmd xcodebuild
require_cmd xcrun
[[ -x "$BIN" ]] || {
  echo "Missing viewglass binary at $BIN" >&2
  exit 1
}

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$1"
}

fail() {
  echo "E2E FAILED: $*" >&2
  exit 1
}

build_demo() {
  log "Building UIView-WZB demo"
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration Debug \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -derivedDataPath "$DERIVED_DATA" \
    build >/tmp/viewglass-demo-build.log
}

launch_demo() {
  local app_path="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/UIView-WZB.app"
  log "Installing and launching demo app"
  xcrun simctl install "$SIMULATOR_UDID" "$app_path"
  xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" >/tmp/viewglass-demo-launch.log
}

resolve_session() {
  local attempt
  for attempt in {1..20}; do
    local apps_json
    if ! apps_json="$("$BIN" apps list --json 2>/dev/null)"; then
      sleep 1
      continue
    fi
    SESSION_PORT="$(jq -r --arg bundle "$BUNDLE_ID" 'map(select(.bundleIdentifier == $bundle)) | .[0].port // empty' <<<"$apps_json")"
    if [[ -n "${SESSION_PORT:-}" ]]; then
      log "Resolved session port: $SESSION_PORT"
      return 0
    fi
    sleep 1
  done
  fail "Unable to discover $BUNDLE_ID via viewglass"
}

refresh_session() {
  "$BIN" refresh --session "$SESSION_PORT" --json > /dev/null
}

restart_and_resolve() {
  launch_demo
  resolve_session
}

query_json() {
  local output
  if output="$("$BIN" query "$1" --session "$SESSION_PORT" --json 2>/dev/null)"; then
    echo "$output"
    return 0
  else
    local exit_code=$?
    if [[ $exit_code -eq 10 ]]; then
      echo '[]'
      return 0
    fi

    return $exit_code
  fi
}

tap_target() {
  "$BIN" tap "$1" --session "$SESSION_PORT" --json
}

attr_json() {
  "$BIN" attr get "$1" --session "$SESSION_PORT" --json
}

button_primary_oids_sorted() {
  query_json UIButton | jq -r 'sort_by(.frame.y) | .[].primaryOid'
}

collect_lines() {
  local line
  local -a lines=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && lines+=("$line")
  done
  printf '%s\n' "${lines[@]}"
}

first_scroll_layer_oid() {
  query_json UIScrollView | jq -r '.[0].oid'
}

first_label_with_gesture_primary_oid() {
  local labels_json
  labels_json="$(query_json UILabel)"
  local primary_oid
  for primary_oid in $(jq -r '.[].primaryOid' <<<"$labels_json"); do
    local gesture_json
    gesture_json="$("$BIN" gesture list "primaryOid:${primary_oid}" --session "$SESSION_PORT" --json)"
    if jq -e '.gestures | length > 0' >/dev/null <<<"$gesture_json"; then
      echo "$primary_oid"
      return 0
    fi
  done
  return 1
}

extract_attr_string() {
  local json="$1"
  local key="$2"
  jq -r --arg key "$key" '.attributes[]?.attributes[]? | select(.key == $key) | .value.string._0 // empty' <<<"$json"
}

scenario_alert_and_dismiss() {
  log "Scenario 1: gesture tap opens alert and controller dismiss closes it"
  restart_and_resolve

  local label_primary
  label_primary="$(first_label_with_gesture_primary_oid)" || fail "No tappable UILabel found"
  tap_target "primaryOid:${label_primary}" > "$ARTIFACT_DIR/tap-alert.json"

  local alert_json
  alert_json="$(query_json UIAlertController)"
  jq 'length == 1' <<<"$alert_json" >/dev/null || fail "Alert did not appear"

  local host_oid
  host_oid="$(jq -r '.[0].hostViewControllerOid' <<<"$alert_json")"
  "$BIN" dismiss "primaryOid:${host_oid}" --session "$SESSION_PORT" --json > "$ARTIFACT_DIR/dismiss-alert.json"
  sleep 1
  refresh_session

  local after_json
  after_json="$(query_json UIAlertController)"
  jq 'length == 0' <<<"$after_json" >/dev/null || fail "Alert still visible after dismiss"

  "$BIN" screenshot node "primaryOid:${label_primary}" --session "$SESSION_PORT" -o "$ARTIFACT_DIR/label-node.png" --json > "$ARTIFACT_DIR/label-node.json"
  [[ -f "$ARTIFACT_DIR/label-node.png" ]] || fail "Node screenshot was not produced"
}

scenario_scroll() {
  log "Scenario 2: semantic scroll updates UIScrollView content offset"
  restart_and_resolve

  local scroll_oid
  scroll_oid="$(first_scroll_layer_oid)"
  [[ -n "$scroll_oid" ]] || fail "No UIScrollView found"

  local before_json
  before_json="$(attr_json "oid:${scroll_oid}")"
  local before_offset
  before_offset="$(extract_attr_string "$before_json" "sv_o_o")"

  "$BIN" scroll "oid:${scroll_oid}" --to 0,320 --session "$SESSION_PORT" --json > "$ARTIFACT_DIR/scroll.json"
  local after_json
  after_json="$(attr_json "oid:${scroll_oid}")"
  local after_offset
  after_offset="$(extract_attr_string "$after_json" "sv_o_o")"

  [[ "$before_offset" != "$after_offset" ]] || fail "contentOffset did not change"
  [[ "$after_offset" == *"320"* ]] || fail "Expected contentOffset to include 320, got: $after_offset"
}

scenario_navigation_and_modal() {
  log "Scenario 3: push detail screen, present modal, dismiss modal"
  restart_and_resolve

  local -a home_buttons
  home_buttons=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && home_buttons+=("$line")
  done < <(button_primary_oids_sorted)
  [[ "${#home_buttons[@]}" -ge 3 ]] || fail "Expected at least 3 home buttons"

  tap_target "primaryOid:${home_buttons[0]}" > "$ARTIFACT_DIR/push-detail.json"
  sleep 1
  refresh_session

  local -a detail_buttons
  detail_buttons=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && detail_buttons+=("$line")
  done < <(button_primary_oids_sorted)
  [[ "${#detail_buttons[@]}" -eq 2 ]] || fail "Expected 2 buttons on detail screen, got ${#detail_buttons[@]}"

  tap_target "primaryOid:${detail_buttons[0]}" > "$ARTIFACT_DIR/show-sheet.json"
  sleep 1
  refresh_session

  local -a modal_buttons
  modal_buttons=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && modal_buttons+=("$line")
  done < <(button_primary_oids_sorted)
  [[ "${#modal_buttons[@]}" -eq 3 ]] || fail "Expected 3 buttons with modal visible, got ${#modal_buttons[@]}"

  tap_target "primaryOid:${modal_buttons[0]}" > "$ARTIFACT_DIR/dismiss-modal-button.json"
  sleep 1
  refresh_session

  local -a buttons_after_dismiss
  buttons_after_dismiss=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && buttons_after_dismiss+=("$line")
  done < <(button_primary_oids_sorted)
  [[ "${#buttons_after_dismiss[@]}" -eq 2 ]] || fail "Expected modal dismissal to restore 2 detail buttons, got ${#buttons_after_dismiss[@]}"

  "$BIN" screenshot screen --session "$SESSION_PORT" -o "$ARTIFACT_DIR/detail-screen.png" --json > "$ARTIFACT_DIR/detail-screen.json"
  [[ -f "$ARTIFACT_DIR/detail-screen.png" ]] || fail "Detail screen screenshot missing"
}

scenario_forms_surface() {
  log "Scenario 4: push forms surface and inspect real UIKit controls"
  restart_and_resolve

  local -a home_buttons
  home_buttons=()
  while IFS= read -r line; do
    [[ -n "$line" ]] && home_buttons+=("$line")
  done < <(button_primary_oids_sorted)
  [[ "${#home_buttons[@]}" -ge 3 ]] || fail "Expected at least 3 home buttons"

  tap_target "primaryOid:${home_buttons[2]}" > "$ARTIFACT_DIR/push-forms.json"
  sleep 1
  refresh_session

  local text_fields switches segments sliders
  text_fields="$(query_json UITextField)"
  switches="$(query_json UISwitch)"
  segments="$(query_json UISegmentedControl)"
  sliders="$(query_json UISlider)"

  jq 'length > 0' <<<"$text_fields" >/dev/null || fail "No UITextField found on forms surface"
  jq 'length > 0' <<<"$switches" >/dev/null || fail "No UISwitch found on forms surface"
  jq 'length > 0' <<<"$segments" >/dev/null || fail "No UISegmentedControl found on forms surface"
  jq 'length > 0' <<<"$sliders" >/dev/null || fail "No UISlider found on forms surface"
}

build_demo
scenario_alert_and_dismiss
scenario_scroll
scenario_navigation_and_modal
scenario_forms_surface

log "All UIView-WZB demo E2E scenarios passed"
