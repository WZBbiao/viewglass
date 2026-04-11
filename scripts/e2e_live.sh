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

# Get the count of nodes from a query/locate JSON array
node_count() {
  printf '%s' "$1" | python3 -c "import json,sys; print(len(json.loads(sys.stdin.read())))"
}

# ── session detection ─────────────────────────────────────────────────────────
if [[ -n "$SESSION_OVERRIDE" ]]; then
  SESSION="$SESSION_OVERRIDE"
else
  # Try to auto-discover via apps list; fall back to known default
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

echo "Using session: $SESSION"
S="--session $SESSION"

# Verify the binary exists
[[ -x "$BIN" ]] || { echo "Binary not found: $BIN. Run: swift build --disable-sandbox" >&2; exit 1; }

# ── test suite ────────────────────────────────────────────────────────────────

section "0 - Session & hierarchy"
# Ensure a clean launch so we start from the Home screen.
xcrun simctl terminate booted "$DEMO_BUNDLE" >/dev/null 2>&1 || true
xcrun simctl launch booted "$DEMO_BUNDLE" >/dev/null 2>&1 || true
sleep 1.5

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
xcrun simctl terminate booted "$DEMO_BUNDLE" >/dev/null 2>&1 || true
xcrun simctl launch booted "$DEMO_BUNDLE" >/dev/null 2>&1 || true
sleep 1.5
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
echo
echo "========================================"
echo "Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "========================================"

[[ "$FAIL_COUNT" -eq 0 ]] || exit 1
