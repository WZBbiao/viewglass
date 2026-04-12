#!/usr/bin/env bash
# e2e_live.sh — Unified E2E smoke-test against an already-running ViewglassDemo session.
#
# Supports both iOS Simulator and real USB device (auto-detected).
# Does NOT restart the app — navigates through all screens via CLI taps.
#
# Prerequisites:
#   1. ViewglassDemo is installed and running (simulator or USB device).
#   2. The viewglass binary is built:  swift build --disable-sandbox
#
# Usage:
#   bash scripts/e2e_live.sh
#   bash scripts/e2e_live.sh --session com.wzb.ViewglassDemo@47164

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/.build/debug/viewglass"
ARTIFACT_DIR="/tmp/viewglass-e2e"
DEMO_BUNDLE="com.wzb.ViewglassDemo"

mkdir -p "$ARTIFACT_DIR"

# ── CLI options ────────────────────────────────────────────────────────────────
SESSION_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session) SESSION_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── helpers ────────────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0

pass()    { echo "  PASS: $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail()    { echo "  FAIL: $*" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
section() { echo; echo "=== $* ==="; }

# Run viewglass CLI, retry up to 3 times on transient errors.
# NOTE: do not use vg() for commands where exit 1 is an expected test outcome
# (assert, wait-timeout).  Call "$BIN" directly in those cases.
vg() {
  local attempt out ec
  for attempt in 1 2 3; do
    ec=0
    out="$("$BIN" "$@" 2>&1)" || ec=$?
    if [[ $ec -eq 0 ]]; then
      printf '%s\n' "$out"
      return 0
    fi
    sleep 0.5
  done
  printf '%s\n' "$out" >&2
  return "$ec"
}

# Extract a value from flat attr JSON: attr_val <json_string> <key>
attr_val() {
  local json="$1" key="$2"
  printf '%s' "$json" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
attrs = d.get('attributes', {})
print(attrs.get('$key', ''))
"
}

# Count leaf nodes in a hierarchy snapshot JSON
hierarchy_node_count() {
  printf '%s' "$1" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
def count(tree):
    return 1 + sum(count(c) for c in tree.get('children', []))
print(sum(count(w) for w in data.get('windows', [])))
"
}

# Count nodes in a query/locate result JSON array
node_count() {
  printf '%s' "$1" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))"
}

# ── session detection ──────────────────────────────────────────────────────────
APPS_JSON=""
if [[ -n "$SESSION_OVERRIDE" ]]; then
  SESSION="$SESSION_OVERRIDE"
else
  APPS_JSON="$("$BIN" apps list --json 2>/dev/null || true)"
  if [[ -n "$APPS_JSON" ]]; then
    SESSION="$(printf '%s' "$APPS_JSON" | python3 -c "
import json, sys
apps = json.loads(sys.stdin.read())
if apps:
    a = apps[0]
    print(a['bundleIdentifier'] + '@' + str(a['port']))
else:
    sys.exit(1)
" 2>/dev/null)" || SESSION="${DEMO_BUNDLE}@47164"
  else
    SESSION="${DEMO_BUNDLE}@47164"
  fi
fi

# Detect real device vs simulator
IS_REAL_DEVICE=false
if [[ -n "$APPS_JSON" ]]; then
  IS_REAL_DEVICE="$(printf '%s' "$APPS_JSON" | python3 -c "
import json, sys
apps = json.loads(sys.stdin.read())
for a in apps:
    sid = a.get('bundleIdentifier','') + '@' + str(a.get('port',''))
    if sid == sys.argv[1]:
        print('true' if a.get('deviceType') == 'device' else 'false')
        sys.exit(0)
print('false')
" "$SESSION" 2>/dev/null)" || IS_REAL_DEVICE=false
fi

S="--session $SESSION"
echo "Using session: $SESSION  (real device: $IS_REAL_DEVICE)"
echo "Artifacts:     $ARTIFACT_DIR"

[[ -x "$BIN" ]] || { echo "Binary not found: $BIN. Run: swift build --disable-sandbox" >&2; exit 1; }

# ── navigation helpers ─────────────────────────────────────────────────────────
# Navigate to home tab root from any screen (no app restart).
# Uses #switch_tab_home (exists on Forms/Feed VCs) and back buttons.
go_home() {
  # Dismiss any presented modal
  "$BIN" tap "#dismiss_modal" $S >/dev/null 2>&1 || true
  sleep 0.3
  # Pop pushed VCs on whatever tab we're on (try 3 times for nested stacks)
  "$BIN" tap "_UIButtonBarButton" $S >/dev/null 2>&1 || true
  sleep 0.3
  "$BIN" tap "_UIButtonBarButton" $S >/dev/null 2>&1 || true
  sleep 0.3
  "$BIN" tap "_UIButtonBarButton" $S >/dev/null 2>&1 || true
  sleep 0.3
  # If on Forms or Feed tab, switch to Home tab.
  # #switch_tab_home is a UIButton on FormsVC and FeedVC (not on HomeVC).
  "$BIN" tap "#switch_tab_home" $S >/dev/null 2>&1 || true
  sleep 0.4
  # Pop pushed VCs on home tab (in case home was on a pushed VC)
  "$BIN" tap "_UIButtonBarButton" $S >/dev/null 2>&1 || true
  sleep 0.3
  "$BIN" tap "_UIButtonBarButton" $S >/dev/null 2>&1 || true
  sleep 0.4
  vg refresh $S --json >/dev/null
}

# Pop one level of navigation stack and wait for transition
navigate_back() {
  "$BIN" tap "_UIButtonBarButton" $S >/dev/null 2>&1 || true
  sleep 0.5
  vg refresh $S --json >/dev/null
}

# ── test suite ─────────────────────────────────────────────────────────────────

section "0 - Connectivity"
go_home

if vg refresh $S --json >/dev/null 2>&1; then
  pass "refresh: session is live"
else
  echo "ERROR: Cannot connect to session '$SESSION'." \
       "Is ViewglassDemo running on simulator or USB device?" >&2
  exit 1
fi

APPS_OUT="$(vg apps list --json)"
APP_COUNT="$(printf '%s' "$APPS_OUT" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))")"
if [[ "$APP_COUNT" -ge 1 ]]; then
  pass "apps list: $APP_COUNT app(s) detected"
else
  fail "apps list returned 0 apps"
fi

section "1 - Hierarchy"
FULL_HIER="$(vg hierarchy $S --json)"
FULL_COUNT="$(hierarchy_node_count "$FULL_HIER")"
if [[ "$FULL_COUNT" -gt 0 ]]; then
  pass "hierarchy full: $FULL_COUNT node(s)"
else
  fail "hierarchy returned 0 nodes"
fi

FILTERED_HIER="$(vg hierarchy $S --filter UILabel --json)"
FILTERED_COUNT="$(hierarchy_node_count "$FILTERED_HIER")"
if [[ "$FILTERED_COUNT" -gt 0 ]]; then
  pass "hierarchy --filter UILabel: $FILTERED_COUNT node(s)"
else
  fail "hierarchy --filter UILabel: 0 nodes"
fi
if [[ "$FILTERED_COUNT" -lt "$FULL_COUNT" ]]; then
  pass "filtered ($FILTERED_COUNT) < full ($FULL_COUNT)"
else
  fail "filtered should be fewer nodes than full hierarchy"
fi
if printf '%s' "$FILTERED_HIER" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
def has_class(node, cls):
    if node.get('node', {}).get('className') == cls:
        return True
    return any(has_class(c, cls) for c in node.get('children', []))
result = any(has_class(w, 'UILabel') for w in data.get('windows', []))
sys.exit(0 if result else 1)
" 2>/dev/null; then
  pass "filtered hierarchy JSON contains UILabel class"
else
  fail "filtered hierarchy JSON missing UILabel"
fi

section "2 - Query & locate"
BUTTONS_JSON="$(vg query UIButton $S --json)"
BTN_COUNT="$(node_count "$BUTTONS_JSON")"
if [[ "$BTN_COUNT" -gt 0 ]]; then
  pass "query UIButton: $BTN_COUNT node(s)"
else
  fail "query UIButton: 0 nodes"
fi

AND_JSON="$(vg query "UIButton AND .visible" $S --json)"
AND_COUNT="$(node_count "$AND_JSON")"
if [[ "$AND_COUNT" -gt 0 ]]; then
  pass "query 'UIButton AND .visible': $AND_COUNT node(s)"
else
  fail "query 'UIButton AND .visible': 0 nodes"
fi

LOCATE_JSON="$(vg locate "#home_buttons_stack" $S --json)"
LOC_COUNT="$(printf '%s' "$LOCATE_JSON" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
print(len(d.get('matches', [])))
")"
if [[ "$LOC_COUNT" -ge 1 ]]; then
  pass "locate #home_buttons_stack: $LOC_COUNT match(es)"
else
  fail "locate #home_buttons_stack: 0 matches"
fi

section "3 - attr keys"
KEYS_TXT="$(vg attr keys)"
if [[ -n "$KEYS_TXT" ]]; then
  pass "attr keys: non-empty output"
else
  fail "attr keys: empty output"
fi

KEYS_JSON="$(vg attr keys --json)"
KEY_COUNT="$(printf '%s' "$KEYS_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len(d.get('keys', [])))
")"
if [[ "$KEY_COUNT" -gt 0 ]]; then
  pass "attr keys --json: $KEY_COUNT keys"
else
  fail "attr keys --json: 0 keys"
fi
if printf '%s' "$KEYS_TXT" | grep -q "^alpha$"; then
  pass "attr keys: well-known key 'alpha' present"
else
  fail "attr keys: missing 'alpha'"
fi

# ── navigate to Gestures screen ───────────────────────────────────────────────
section "4 - Navigate: Home → Gestures screen"
vg tap "#push_gestures_screen" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null

GESTURE_STATUS_JSON="$(vg query "#gesture_status" $S --json)"
if [[ "$(node_count "$GESTURE_STATUS_JSON")" -ge 1 ]]; then
  pass "#gesture_status found after navigation"
else
  fail "#gesture_status not found — navigation to Gestures screen failed"
fi

section "5 - tap gesture"
vg tap "#tappable_label" $S --json >/dev/null
sleep 0.4
vg refresh $S --json >/dev/null

TAP_ATTR="$(vg attr get "#gesture_status" $S --json)"
TAP_TEXT="$(attr_val "$TAP_ATTR" "text")"
if [[ "$TAP_TEXT" == "Tap gesture fired" ]]; then
  pass "tap: statusLabel shows 'Tap gesture fired'"
else
  fail "tap: expected 'Tap gesture fired', got '$TAP_TEXT'"
fi

section "6 - long-press & contains: query"
vg long-press "#long_press_card" $S --json >/dev/null
sleep 0.4
vg refresh $S --json >/dev/null

LP_ATTR="$(vg attr get "#gesture_status" $S --json)"
LP_TEXT="$(attr_val "$LP_ATTR" "text")"
if [[ "$LP_TEXT" == "Long press fired" ]]; then
  pass "long-press: statusLabel shows 'Long press fired'"
else
  fail "long-press: expected 'Long press fired', got '$LP_TEXT'"
fi

CONTAINS_JSON="$(vg query 'contains:"Long press"' $S --json)"
CONTAINS_COUNT="$(node_count "$CONTAINS_JSON")"
if [[ "$CONTAINS_COUNT" -ge 1 ]]; then
  pass "contains:\"Long press\" matched $CONTAINS_COUNT node(s)"
else
  fail "contains:\"Long press\": 0 nodes"
fi

section "7 - attr get (flat format + enum names)"
ATTR_FLAT="$(vg attr get "#gesture_status" $S --json)"

CLASS_NAME="$(printf '%s' "$ATTR_FLAT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d.get('className', ''))
")"
if [[ -n "$CLASS_NAME" ]]; then
  pass "attr get --json: className present ($CLASS_NAME)"
else
  fail "attr get --json: missing className field"
fi

TEXT_VAL="$(attr_val "$ATTR_FLAT" "text")"
if [[ "$TEXT_VAL" == "Long press fired" ]]; then
  pass "attr get --json: readable key 'text' works"
else
  fail "attr get --json: expected text='Long press fired', got '$TEXT_VAL'"
fi

TEXT_ALIGN="$(attr_val "$ATTR_FLAT" "textAlignment")"
if [[ -n "$TEXT_ALIGN" ]] && printf '%s' "$TEXT_ALIGN" | grep -qvE '^[0-9]+$'; then
  pass "textAlignment is enum name: '$TEXT_ALIGN' (not raw int)"
else
  fail "textAlignment expected a name, got: '$TEXT_ALIGN'"
fi

section "8 - assert commands"
if "$BIN" assert visible "#gesture_status" $S >/dev/null 2>&1; then
  pass "assert visible #gesture_status (positive case)"
else
  fail "assert visible #gesture_status failed"
fi

if "$BIN" assert visible "UIClassThatDoesNotExist999" $S >/dev/null 2>&1; then
  fail "assert visible non-existent class should have exited 1"
else
  pass "assert visible: correctly fails for non-existent element"
fi

if "$BIN" assert text "#gesture_status" "Long press fired" $S >/dev/null 2>&1; then
  pass "assert text 'Long press fired' passed"
else
  fail "assert text 'Long press fired' failed"
fi

if "$BIN" assert count UILabel --min 1 $S >/dev/null 2>&1; then
  pass "assert count UILabel --min 1 passed"
else
  fail "assert count UILabel --min 1 failed"
fi

if "$BIN" assert attr "#gesture_status" --key hidden --equals "false" $S >/dev/null 2>&1; then
  pass "assert attr hidden==false passed"
else
  fail "assert attr hidden==false failed"
fi

if "$BIN" assert attr "#gesture_status" --key hidden --equals "true" $S >/dev/null 2>&1; then
  fail "assert attr hidden==true should have exited 1 (label is visible)"
else
  pass "assert attr: correctly fails when value does not match"
fi

section "9 - wait commands"
if "$BIN" wait appears "#gesture_status" --timeout 3 $S >/dev/null 2>&1; then
  pass "wait appears: immediately satisfied for visible element"
else
  fail "wait appears: failed for already-visible element"
fi

if "$BIN" wait gone "UIClassThatDoesNotExist999" --timeout 3 $S >/dev/null 2>&1; then
  pass "wait gone: immediately satisfied for non-existent class"
else
  fail "wait gone: failed for non-existent class"
fi

if "$BIN" wait appears "UIClassThatDoesNotExist999" --timeout 1 $S >/dev/null 2>&1; then
  fail "wait appears: non-existent class should have timed out (exit 1)"
else
  pass "wait appears: correctly times out (exit 1)"
fi

if "$BIN" wait attr "#gesture_status" --key text --contains "Long press" \
   --timeout 5 $S >/dev/null 2>&1; then
  pass "wait attr --contains: satisfied on first poll"
else
  fail "wait attr --contains: failed"
fi

# Real polling: trigger tap ~0.8s after starting wait
(sleep 0.8 && "$BIN" tap "#tappable_label" $S --json >/dev/null 2>&1) &
BG_TAP_PID=$!
if "$BIN" wait attr "#gesture_status" --key text --equals "Tap gesture fired" \
   --timeout 6 --interval-ms 400 $S >/dev/null 2>&1; then
  pass "wait attr: polls and detects attr change after async tap"
else
  fail "wait attr: failed to detect attribute change within timeout"
fi
wait $BG_TAP_PID 2>/dev/null || true

if "$BIN" wait attr "#gesture_status" --key text --equals "ThisWillNeverHappen" \
   --timeout 1 $S >/dev/null 2>&1; then
  fail "wait attr: unachievable condition should time out (exit 1)"
else
  pass "wait attr: correctly times out for unachievable condition"
fi

# Navigate back to home
navigate_back

# ── navigate to Buttons screen ────────────────────────────────────────────────
section "10 - screenshot (Buttons screen)"
vg tap "#push_buttons_screen" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null

SCREEN_JSON="$(vg screenshot screen $S -o "$ARTIFACT_DIR/buttons-screen.png" --json)"
if printf '%s' "$SCREEN_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d.get('filePath') else 1)
" 2>/dev/null; then
  pass "screenshot screen: saved to $ARTIFACT_DIR/buttons-screen.png"
else
  fail "screenshot screen: failed or missing filePath in JSON"
fi

NODE_SCREEN_JSON="$(vg screenshot node "#open_alert" $S -o "$ARTIFACT_DIR/open-alert-btn.png" --json 2>/dev/null || true)"
if [[ -n "$NODE_SCREEN_JSON" ]] && printf '%s' "$NODE_SCREEN_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
sys.exit(0 if d.get('filePath') else 1)
" 2>/dev/null; then
  pass "screenshot node #open_alert: saved to $ARTIFACT_DIR/open-alert-btn.png"
else
  fail "screenshot node #open_alert: failed"
fi

section "11 - dismiss (alert, action sheet, page sheet, full screen)"

# Alert
vg tap "#open_alert" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null
ALERT_JSON="$(vg query UIAlertController $S --json)"
if [[ "$(node_count "$ALERT_JSON")" -eq 1 ]]; then
  pass "UIAlertController present after open_alert"
  ALERT_OID="$(printf '%s' "$ALERT_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d[0].get('hostViewControllerOid', ''))
")"
  if vg dismiss "$ALERT_OID" $S --json >/dev/null 2>&1; then
    sleep 0.5
    vg refresh $S --json >/dev/null
    if [[ "$(node_count "$(vg query UIAlertController $S --json)")" -eq 0 ]]; then
      pass "dismiss alert: gone after dismiss"
    else
      fail "dismiss alert: still present after dismiss"
    fi
  else
    fail "dismiss alert: dismiss command failed"
  fi
else
  fail "UIAlertController not found after open_alert"
fi

# Action sheet
vg tap "#open_action_sheet" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null
SHEET_JSON="$(vg query UIAlertController $S --json)"
if [[ "$(node_count "$SHEET_JSON")" -eq 1 ]]; then
  pass "UIAlertController (action sheet) present"
  SHEET_OID="$(printf '%s' "$SHEET_JSON" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(d[0].get('hostViewControllerOid', ''))
")"
  vg dismiss "$SHEET_OID" $S --json >/dev/null 2>&1 || true
  sleep 0.5
  vg refresh $S --json >/dev/null
  if [[ "$(node_count "$(vg query UIAlertController $S --json)")" -eq 0 ]]; then
    pass "dismiss action sheet: gone"
  else
    fail "dismiss action sheet: still present"
  fi
else
  fail "action sheet not found"
fi

# Page sheet (ModalCardViewController)
vg tap "#open_page_sheet" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null
PAGE_JSON="$(vg query "controller:ModalCardViewController" $S --json)"
if [[ "$(node_count "$PAGE_JSON")" -ge 1 ]]; then
  pass "ModalCardViewController (page sheet) present"
  vg tap "#dismiss_modal" $S --json >/dev/null 2>&1 || true
  sleep 0.5
  vg refresh $S --json >/dev/null
  if [[ "$(node_count "$(vg query "controller:ModalCardViewController" $S --json)")" -eq 0 ]]; then
    pass "page sheet dismissed via #dismiss_modal"
  else
    fail "page sheet still present after #dismiss_modal"
  fi
else
  fail "ModalCardViewController (page sheet) not found"
fi

# Full screen
vg tap "#open_full_screen" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null
FS_JSON="$(vg query "controller:ModalCardViewController" $S --json)"
if [[ "$(node_count "$FS_JSON")" -ge 1 ]]; then
  pass "ModalCardViewController (full screen) present"
  vg tap "#dismiss_modal" $S --json >/dev/null 2>&1 || true
  sleep 0.5
  vg refresh $S --json >/dev/null
  if [[ "$(node_count "$(vg query "controller:ModalCardViewController" $S --json)")" -eq 0 ]]; then
    pass "full screen dismissed via #dismiss_modal"
  else
    fail "full screen still present after #dismiss_modal"
  fi
else
  fail "ModalCardViewController (full screen) not found"
fi

# Navigate back to home
navigate_back

# ── Feed (via push nav) ───────────────────────────────────────────────────────
section "12 - scroll, scroll --animated & swipe (Feed screen)"
vg tap "#push_feed_screen" $S --json >/dev/null
sleep 0.5
vg refresh $S --json >/dev/null

FEED_ATTR="$(vg attr get "#long_feed_scroll" $S --json)"
INITIAL_OFFSET="$(attr_val "$FEED_ATTR" "contentOffset")"
if printf '%s' "$INITIAL_OFFSET" | grep -qE "[0-9].*0.*0|0.*0"; then
  pass "initial contentOffset near zero: $INITIAL_OFFSET"
else
  fail "unexpected initial contentOffset: $INITIAL_OFFSET"
fi

# Immediate scroll to 320
vg scroll "#long_feed_scroll" --to 0,320 $S --json >/dev/null
sleep 0.2
vg refresh $S --json >/dev/null
AFTER_ATTR="$(vg attr get "#long_feed_scroll" $S --json)"
AFTER_OFFSET="$(attr_val "$AFTER_ATTR" "contentOffset")"
if printf '%s' "$AFTER_OFFSET" | grep -qE "320"; then
  pass "scroll --to 0,320: contentOffset updated ($AFTER_OFFSET)"
else
  fail "scroll --to 0,320: unexpected offset '$AFTER_OFFSET'"
fi

# Animated scroll back to 0
if vg scroll "#long_feed_scroll" --to 0,0 --animated $S --json >/dev/null 2>&1; then
  vg refresh $S --json >/dev/null
  ANIMATED_ATTR="$(vg attr get "#long_feed_scroll" $S --json)"
  ANIMATED_OFFSET="$(attr_val "$ANIMATED_ATTR" "contentOffset")"
  if printf '%s' "$ANIMATED_OFFSET" | grep -qE "0.*0"; then
    pass "scroll --animated: offset back to 0 ($ANIMATED_OFFSET)"
  else
    fail "scroll --animated: expected near 0, got '$ANIMATED_OFFSET'"
  fi
else
  fail "scroll --animated failed (requires updated ViewglassServer)"
fi

# Swipe up (moves scroll position)
if vg swipe "#long_feed_scroll" --direction up $S --json >/dev/null 2>&1; then
  sleep 0.4
  vg refresh $S --json >/dev/null
  SWIPE_ATTR="$(vg attr get "#long_feed_scroll" $S --json)"
  SWIPE_OFFSET="$(attr_val "$SWIPE_ATTR" "contentOffset")"
  if printf '%s' "$SWIPE_OFFSET" | grep -qE "[1-9][0-9]*"; then
    pass "swipe up: contentOffset is non-zero ($SWIPE_OFFSET)"
  else
    fail "swipe up: offset still at zero ($SWIPE_OFFSET)"
  fi
else
  fail "swipe command failed"
fi

# Navigate back to home before Forms section
navigate_back

# ── Forms (via push nav) ──────────────────────────────────────────────────────
section "13 - input (Forms screen)"
vg tap "#push_forms_screen" $S --json >/dev/null
sleep 0.5
vg refresh $S --json >/dev/null

TF_JSON="$(vg query UITextField $S --json)"
TF_COUNT="$(node_count "$TF_JSON")"
if [[ "$TF_COUNT" -ge 2 ]]; then
  pass "Forms tab: $TF_COUNT UITextField(s) found"
else
  fail "Forms tab: expected ≥2 UITextFields, got $TF_COUNT"
fi

vg input "#primary_text_field" --text "agent@example.com" $S --json >/dev/null
sleep 0.3
vg input "#secure_text_field" --text "hunter2!" $S --json >/dev/null
sleep 0.3
vg input "#notes_text_view" --text "Agent entered multiline notes." $S --json >/dev/null
sleep 0.3
vg refresh $S --json >/dev/null

FORMS_ATTR="$(vg attr get "#forms_status" $S --json)"
FORMS_TEXT="$(attr_val "$FORMS_ATTR" "text")"
if [[ "$FORMS_TEXT" == *"agent@example.com"* ]]; then
  pass "input: forms status contains email"
else
  fail "input: forms status missing email; got: '$FORMS_TEXT'"
fi
if [[ "$FORMS_TEXT" == *"8 chars"* ]]; then
  pass "input: forms status shows password length"
else
  fail "input: forms status missing password info; got: '$FORMS_TEXT'"
fi

# ── Home: final checks ────────────────────────────────────────────────────────
section "14 - UIStackView axis (Home screen)"
navigate_back

STACK_ATTR="$(vg attr get "#home_buttons_stack" $S --json)"
AXIS_VAL="$(attr_val "$STACK_ATTR" "axis")"
if [[ "$AXIS_VAL" == "vertical" ]]; then
  pass "UIStackView axis: 'vertical' (not raw int)"
else
  fail "UIStackView axis: expected 'vertical', got: '$AXIS_VAL'"
fi

# ── summary ────────────────────────────────────────────────────────────────────
echo
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "Screenshots: $ARTIFACT_DIR"
echo "========================================"

[[ "$FAIL_COUNT" -eq 0 ]] || exit 1
