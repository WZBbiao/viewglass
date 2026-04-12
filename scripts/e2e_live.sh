#!/usr/bin/env bash
# e2e_live.sh — Smoke-tests against an already-running ViewglassDemo session.
#
# Prerequisites:
#   1. ViewglassDemo is installed and running on a simulator.
#   2. The viewglass binary is already built:  swift build --disable-sandbox
#
# Usage:
#   bash scripts/e2e_live.sh
#   bash scripts/e2e_live.sh --session com.wzb.ViewglassDemo@47164

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$ROOT/.build/debug/viewglass"

DEMO_BUNDLE="com.wzb.ViewglassDemo"
DEFAULT_SESSION="$DEMO_BUNDLE@47164"

# ── CLI options ───────────────────────────────────────────────────────────────
SESSION_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session) SESSION_OVERRIDE="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# ── helpers ───────────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0

pass() { echo "  PASS: $*"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo "  FAIL: $*" >&2; FAIL_COUNT=$((FAIL_COUNT + 1)); }
section() { echo; echo "=== $* ==="; }

# Run viewglass CLI, retry up to 3 times on transient errors
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
  local json="$1"
  local key="$2"
  printf '%s' "$json" | python3 -c "
import json, sys
d = json.loads(sys.stdin.read())
attrs = d.get('attributes', {})
print(attrs.get('$key', ''))
"
}

# Count all leaf nodes in a hierarchy snapshot JSON (recursive tree walk)
hierarchy_node_count() {
  printf '%s' "$1" | python3 -c "
import json, sys
data = json.loads(sys.stdin.read())
def count_tree(tree):
    return 1 + sum(count_tree(c) for c in tree.get('children', []))
print(sum(count_tree(w) for w in data.get('windows', [])))
"
}

# Get the count of nodes from a query/locate JSON array
node_count() {
  printf '%s' "$1" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))"
}

# ── session detection ─────────────────────────────────────────────────────────
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
" 2>/dev/null)" || SESSION="$DEFAULT_SESSION"
  else
    SESSION="$DEFAULT_SESSION"
  fi
fi

# Detect real device: session deviceType is device
IS_REAL_DEVICE=false
if [[ -n "${APPS_JSON:-}" ]]; then
  IS_REAL_DEVICE="$(printf '%s' "$APPS_JSON" | python3 -c "
import json, sys
apps = json.loads(sys.stdin.read())
for a in apps:
    port = str(a.get('port',''))
    bundle = a.get('bundleIdentifier','')
    session_id = bundle + '@' + port
    if session_id == sys.argv[1] or port == sys.argv[1]:
        print('true' if a.get('deviceType') == 'device' else 'false')
        sys.exit(0)
print('false')
" "$SESSION" 2>/dev/null)" || IS_REAL_DEVICE=false
fi

sim_relaunch() {
  if [[ "$IS_REAL_DEVICE" == "true" ]]; then
    echo "  (INFO: skipping app relaunch on real device — attempting to pop to Home screen)"
    "$BIN" tap _UIButtonBarButton $S >/dev/null 2>&1 || true
    sleep 0.3
    "$BIN" tap _UIButtonBarButton $S >/dev/null 2>&1 || true
    sleep 0.3
    "$BIN" tap "#switch_tab_home" $S >/dev/null 2>&1 || true
    sleep 0.5
  else
    xcrun simctl terminate booted "$DEMO_BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl launch    booted "$DEMO_BUNDLE" >/dev/null 2>&1 || true
    sleep 1.5
  fi
}

echo "Using session: $SESSION"
S="--session $SESSION"

# Verify the binary exists
[[ -x "$BIN" ]] || { echo "Binary not found: $BIN. Run: swift build --disable-sandbox" >&2; exit 1; }

# ── test suite ────────────────────────────────────────────────────────────────

section "0 - Session & hierarchy"
# Ensure a clean launch so we start from the Home screen.
sim_relaunch

if vg refresh $S --json >/dev/null 2>&1; then
  pass "refresh succeeded (session is live)"
else
  echo "ERROR: Cannot connect to session '$SESSION'. Is ViewglassDemo running in the simulator?" >&2
  exit 1
fi

section "1 - Basic query"
BUTTONS_JSON="$(vg query UIButton $S --json)"
BTN_COUNT="$(node_count "$BUTTONS_JSON")"
if [[ "$BTN_COUNT" -gt 0 ]]; then
  pass "query UIButton returned $BTN_COUNT nodes"
else
  fail "query UIButton returned 0 nodes"
fi

AND_JSON="$(vg query "UIButton AND .visible" $S --json)"
AND_COUNT="$(node_count "$AND_JSON")"
if [[ "$AND_COUNT" -gt 0 ]]; then
  pass "query 'UIButton AND .visible' returned $AND_COUNT nodes"
else
  fail "query 'UIButton AND .visible' returned 0 nodes (LKLocator routing bug?)"
fi

section "2 - Gestures screen & long-press"
vg tap "#push_gestures_screen" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null

# Verify the gestures screen loaded
GESTURE_STATUS_JSON="$(vg query "#gesture_status" $S --json)"
if [[ "$(node_count "$GESTURE_STATUS_JSON")" -ge 1 ]]; then
  pass "#gesture_status found on Gestures screen"
else
  fail "#gesture_status not found — navigation may have failed"
fi

vg long-press "#long_press_card" $S --json >/dev/null
sleep 0.4
vg refresh $S --json >/dev/null

ATTR_JSON="$(vg attr get "#gesture_status" $S --json)"
STATUS_TEXT="$(attr_val "$ATTR_JSON" "text")"
if [[ "$STATUS_TEXT" == "Long press fired" ]]; then
  pass "long-press: statusLabel shows 'Long press fired'"
else
  fail "long-press: expected 'Long press fired', got '$STATUS_TEXT'"
fi

section "3 - contains: query syntax"
CONTAINS_JSON="$(vg query 'contains:"Long press"' $S --json)"
CONTAINS_COUNT="$(node_count "$CONTAINS_JSON")"
if [[ "$CONTAINS_COUNT" -ge 1 ]]; then
  pass "contains:\"Long press\" matched $CONTAINS_COUNT node(s)"
else
  fail "contains:\"Long press\" returned 0 nodes"
fi

section "4 - attr get --json flat format"
ATTR_FLAT="$(vg attr get "#gesture_status" $S --json)"
# The new format: {"oid": N, "className": "...", "attributes": {"text": "...", ...}}
CLASS_NAME="$(printf '%s' "$ATTR_FLAT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('className',''))")"
if [[ -n "$CLASS_NAME" ]]; then
  pass "attr get --json flat format OK (className: $CLASS_NAME)"
else
  fail "attr get --json missing className field"
fi
TEXT_FROM_FLAT="$(attr_val "$ATTR_FLAT" "text")"
if [[ "$TEXT_FROM_FLAT" == "Long press fired" ]]; then
  pass "attr get --json flat attrs: readable key 'text' works"
else
  fail "attr get --json flat attrs: expected 'text'='Long press fired', got '$TEXT_FROM_FLAT'"
fi

section "5 - Feed tab: scroll and scroll --animated"
# Re-launch to get back to Home, then navigate to Feed tab
sim_relaunch
vg refresh $S --json >/dev/null

vg tap "#switch_tab_feed" $S --json >/dev/null
sleep 0.4
vg refresh $S --json >/dev/null

FEED_ATTR="$(vg attr get "#long_feed_scroll" $S --json)"
INITIAL_OFFSET="$(attr_val "$FEED_ATTR" "contentOffset")"
# Expect offset near {0, 0}
if printf '%s' "$INITIAL_OFFSET" | grep -qE "0.*0"; then
  pass "initial contentOffset is near zero: $INITIAL_OFFSET"
else
  fail "unexpected initial contentOffset: $INITIAL_OFFSET"
fi

# Immediate scroll
vg scroll "#long_feed_scroll" --to 0,320 $S --json >/dev/null
sleep 0.2
vg refresh $S --json >/dev/null
AFTER_ATTR="$(vg attr get "#long_feed_scroll" $S --json)"
AFTER_OFFSET="$(attr_val "$AFTER_ATTR" "contentOffset")"
if printf '%s' "$AFTER_OFFSET" | grep -qE "320"; then
  pass "scroll --to 0,320 reflects in contentOffset: $AFTER_OFFSET"
else
  fail "scroll --to 0,320 failed: got '$AFTER_OFFSET'"
fi

# Animated scroll back to top — CLI blocks until animation completes
# (Requires app built with the updated ViewglassServer that handles request type 220.)
if vg scroll "#long_feed_scroll" --to 0,0 --animated $S --json >/dev/null 2>&1; then
  vg refresh $S --json >/dev/null
  ANIMATED_ATTR="$(vg attr get "#long_feed_scroll" $S --json)"
  ANIMATED_OFFSET="$(attr_val "$ANIMATED_ATTR" "contentOffset")"
  if printf '%s' "$ANIMATED_OFFSET" | grep -qE "0.*0"; then
    pass "scroll --animated returns after animation; offset back at 0: $ANIMATED_OFFSET"
  else
    fail "scroll --animated: expected offset near 0, got '$ANIMATED_OFFSET'"
  fi
else
  fail "scroll --animated failed (likely old ViewglassServer; rebuild Demo to enable this test)"
fi

section "6 - Forms tab: text input"
vg tap "#switch_tab_forms" $S --json >/dev/null
sleep 0.4
vg refresh $S --json >/dev/null

TF_JSON="$(vg query UITextField $S --json)"
TF_COUNT="$(node_count "$TF_JSON")"
if [[ "$TF_COUNT" -ge 1 ]]; then
  pass "Forms tab has $TF_COUNT UITextField(s)"
else
  fail "Forms tab: no UITextFields found"
fi

vg input "#primary_text_field" --text "agent@example.com" $S --json >/dev/null
sleep 0.3
vg refresh $S --json >/dev/null

FORMS_ATTR="$(vg attr get "#forms_status" $S --json)"
FORMS_TEXT="$(attr_val "$FORMS_ATTR" "text")"
if [[ "$FORMS_TEXT" == *"agent@example.com"* ]]; then
  pass "Forms status reflects email input"
else
  fail "Forms status does not contain email; got: '$FORMS_TEXT'"
fi

# ── summary ───────────────────────────────────────────────────────────────────

section "7 - attr keys"
KEYS_TXT="$(vg attr keys)"
if [[ -n "$KEYS_TXT" ]]; then
  pass "attr keys returns non-empty list"
else
  fail "attr keys returned empty output"
fi

KEYS_JSON="$(vg attr keys --json)"
KEY_COUNT="$(printf '%s' "$KEYS_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('keys', [])))")"
if [[ "$KEY_COUNT" -gt 0 ]]; then
  pass "attr keys --json returns $KEY_COUNT keys"
else
  fail "attr keys --json returned 0 keys"
fi
# Well-known key must be present in both outputs
if printf '%s' "$KEYS_TXT" | grep -q "^alpha$"; then
  pass "attr keys contains 'alpha'"
else
  fail "attr keys missing 'alpha'"
fi

section "8 - enum names in attr get --json"
# Re-launch and navigate to gestures screen for a live UILabel
sim_relaunch
vg refresh $S --json >/dev/null
vg tap "#push_gestures_screen" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null

ENUM_ATTR="$(vg attr get "#gesture_status" $S --json)"
TEXT_ALIGN="$(attr_val "$ENUM_ATTR" "textAlignment")"
# textAlignment value must be a string name, not a bare integer
if [[ -n "$TEXT_ALIGN" ]] && printf '%s' "$TEXT_ALIGN" | grep -qvE '^[0-9]+$'; then
  pass "textAlignment is an enum name: '$TEXT_ALIGN' (not a raw integer)"
else
  fail "textAlignment expected a name, got: '$TEXT_ALIGN'"
fi

section "9 - assert commands"
# assert visible — #gesture_status is on screen
if vg assert visible "#gesture_status" $S >/dev/null 2>&1; then
  pass "assert visible #gesture_status passed"
else
  fail "assert visible #gesture_status failed (expected exit 0)"
fi

# assert visible — force a failure for a non-existent element
if vg assert visible "UIClassThatDoesNotExist999" $S >/dev/null 2>&1; then
  fail "assert visible non-existent class should have exited 1"
else
  pass "assert visible correctly fails for non-existent element"
fi

# assert text — trigger long-press then check label text
vg long-press "#long_press_card" $S --json >/dev/null
sleep 0.4
vg refresh $S --json >/dev/null
if vg assert text "#gesture_status" "Long press fired" $S >/dev/null 2>&1; then
  pass "assert text positional expected 'Long press fired' passed"
else
  fail "assert text positional expected 'Long press fired' failed"
fi

# assert count — there should be at least one UILabel (--min alone, no positional needed)
if vg assert count UILabel --min 1 $S >/dev/null 2>&1; then
  pass "assert count UILabel --min 1 passed"
else
  fail "assert count UILabel --min 1 failed"
fi

section "10 - wait appears / wait gone"
# wait appears: element already visible → satisfied on first poll
if vg wait appears "#gesture_status" --timeout 3 $S >/dev/null 2>&1; then
  pass "wait appears immediately satisfied for visible element"
else
  fail "wait appears failed for already-visible element"
fi

# wait gone: element that never exists → immediately satisfied (count == 0 from the start)
if vg wait gone "UIClassThatDoesNotExist999" --timeout 3 $S >/dev/null 2>&1; then
  pass "wait gone immediately satisfied for non-existent class"
else
  fail "wait gone failed for non-existent class — expected immediate success"
fi

# wait appears timeout: non-existent class should exit 1
if vg wait appears "UIClassThatDoesNotExist999" --timeout 1 $S >/dev/null 2>&1; then
  fail "wait appears non-existent class should time out (exit 1) but returned 0"
else
  pass "wait appears correctly times out for non-existent class (exit 1)"
fi

section "11 - hierarchy --filter"
# Full hierarchy vs. filtered hierarchy: filtered must have fewer nodes
FULL_HIER="$(vg hierarchy $S --json)"
FULL_COUNT="$(hierarchy_node_count "$FULL_HIER")"
if [[ "$FULL_COUNT" -gt 0 ]]; then
  pass "full hierarchy returned $FULL_COUNT node(s)"
else
  fail "full hierarchy returned 0 nodes"
fi

FILTERED_HIER="$(vg hierarchy $S --filter UILabel --json)"
FILTERED_COUNT="$(hierarchy_node_count "$FILTERED_HIER")"
if [[ "$FILTERED_COUNT" -gt 0 ]]; then
  pass "hierarchy --filter UILabel returned $FILTERED_COUNT node(s)"
else
  fail "hierarchy --filter UILabel returned 0 nodes — filter may be broken"
fi
if [[ "$FILTERED_COUNT" -lt "$FULL_COUNT" ]]; then
  pass "filtered hierarchy ($FILTERED_COUNT) has fewer nodes than full hierarchy ($FULL_COUNT)"
else
  fail "filtered hierarchy ($FILTERED_COUNT) should be smaller than full ($FULL_COUNT)"
fi
# Filtered JSON must include UILabel class name
if printf '%s' "$FILTERED_HIER" | grep -q '"UILabel"'; then
  pass "filtered hierarchy JSON contains UILabel"
else
  fail "filtered hierarchy JSON does not contain UILabel"
fi

section "12 - assert attr"
# On gestures screen (continued from §9-11): statusLabel.hidden should be false
if vg assert attr "#gesture_status" --key hidden --equals "false" $S >/dev/null 2>&1; then
  pass "assert attr hidden==false passed"
else
  fail "assert attr hidden==false failed"
fi
# Negative: assert hidden==true should fail
if vg assert attr "#gesture_status" --key hidden --equals "true" $S >/dev/null 2>&1; then
  fail "assert attr hidden==true should have exited 1 (label is visible)"
else
  pass "assert attr correctly fails when expected value does not match"
fi

section "13 - wait attr (live polling)"
# Reset the gesture status to a known initial state by relaunching and navigating.
sim_relaunch
vg refresh $S --json >/dev/null
vg tap "#push_gestures_screen" $S --json >/dev/null
sleep 0.6
vg refresh $S --json >/dev/null
# Status should now be "No gesture triggered yet"

# wait attr: condition already met on first poll
if vg wait attr "#gesture_status" --key text --contains "No gesture" --timeout 5 $S >/dev/null 2>&1; then
  pass "wait attr --contains satisfied on first poll"
else
  fail "wait attr --contains failed (expected first-poll pass)"
fi

# wait attr: real polling — trigger a tap ~1s after starting wait
(sleep 0.8 && vg tap "#tappable_label" $S --json >/dev/null) &
BG_TAP_PID=$!
if vg wait attr "#gesture_status" --key text --equals "Tap gesture fired" \
   --timeout 6 --interval-ms 400 $S >/dev/null 2>&1; then
  pass "wait attr polls and detects 'Tap gesture fired' after async tap"
else
  fail "wait attr failed to detect attribute change within timeout"
fi
wait $BG_TAP_PID 2>/dev/null || true

# wait attr: timeout on unachievable condition
if vg wait attr "#gesture_status" --key text --equals "ThisWillNeverHappen" \
   --timeout 1 $S >/dev/null 2>&1; then
  fail "wait attr should time out for unachievable condition (expected exit 1)"
else
  pass "wait attr correctly times out for unachievable condition"
fi

section "14 - UIStackView axis enum name"
# Navigate to home screen (relaunch) to get #home_buttons_stack in view.
sim_relaunch
vg refresh $S --json >/dev/null

STACK_ATTR="$(vg attr get "#home_buttons_stack" $S --json)"
AXIS_VAL="$(attr_val "$STACK_ATTR" "axis")"
if [[ "$AXIS_VAL" == "vertical" ]]; then
  pass "UIStackView axis enum: got 'vertical' instead of raw int 1"
else
  fail "UIStackView axis expected 'vertical', got: '$AXIS_VAL'"
fi

# ── final summary ─────────────────────────────────────────────────────────────
echo
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

[[ "$FAIL_COUNT" -eq 0 ]] || exit 1
