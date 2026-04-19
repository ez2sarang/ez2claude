#!/bin/bash
# infection-scan.sh
# Quick scan for known compromised packages.
# Run manually: bash ~/.claude/hooks/infection-scan.sh
# Or via Claude: "감염 스캔 해줘" / "run infection scan"
#
# Based on: Axios NPM attack (2025), litellm PyPI attack (2026)

echo "============================================"
echo "  Supply Chain Infection Scanner"
echo "  Known compromised package check"
echo "============================================"
echo ""

FOUND=0

# ──────────────────────────────────────────────────────
# 1. LiteLLM check (PyPI - compromised 1.82.7, 1.82.8)
# ──────────────────────────────────────────────────────
echo "[1/5] Checking litellm (global pip)..."
LITELLM=$(pip3 show litellm 2>/dev/null)
if [ -n "$LITELLM" ]; then
  VER=$(echo "$LITELLM" | grep "^Version:" | awk '{print $2}')
  if echo "$VER" | grep -qE '^1\.82\.[78]$'; then
    echo "  *** ALERT: COMPROMISED litellm $VER detected! ***"
    echo "  Action: pip3 uninstall litellm -y"
    FOUND=$((FOUND + 1))
  else
    echo "  litellm $VER installed (not compromised version)"
  fi
else
  echo "  Not installed (OK)"
fi

# Check all venvs
echo "[2/5] Checking litellm in virtual environments..."
for venv in $(find ~/Documents ~/Downloads ~/Projects ~/ -maxdepth 4 \( -name "venv" -o -name ".venv" \) -type d 2>/dev/null); do
  PIP="$venv/bin/pip"
  if [ -x "$PIP" ]; then
    VER=$($PIP show litellm 2>/dev/null | grep "^Version:" | awk '{print $2}')
    if [ -n "$VER" ]; then
      if echo "$VER" | grep -qE '^1\.82\.[78]$'; then
        echo "  *** ALERT: COMPROMISED litellm $VER in $venv ***"
        FOUND=$((FOUND + 1))
      else
        echo "  litellm $VER in $venv (safe)"
      fi
    fi
  fi
done

# Check for malicious .pth file (litellm attack vector)
echo "[3/5] Checking for litellm_init.pth (malicious persistence)..."
PTH_FILES=$(find ~/.cache/uv ~/.local/lib ~/Library 2>/dev/null -name "litellm_init.pth" -type f 2>/dev/null)
if [ -n "$PTH_FILES" ]; then
  echo "  *** ALERT: Malicious .pth file found! ***"
  echo "$PTH_FILES" | while read f; do echo "    $f"; done
  FOUND=$((FOUND + 1))
fi
# Also check site-packages
PTH_SITE=$(python3 -c "import site; print('\n'.join(site.getsitepackages()))" 2>/dev/null | while read dir; do
  find "$dir" -maxdepth 1 -name "litellm_init.pth" -type f 2>/dev/null
done)
if [ -n "$PTH_SITE" ]; then
  echo "  *** ALERT: litellm_init.pth in site-packages! ***"
  echo "$PTH_SITE"
  FOUND=$((FOUND + 1))
fi
[ -z "$PTH_FILES" ] && [ -z "$PTH_SITE" ] && echo "  Not found (OK)"

# ──────────────────────────────────────────────────────
# 2. Axios check (npm - compromised 1.14.1, 0.30.4)
# ──────────────────────────────────────────────────────
echo "[4/5] Checking axios in node_modules..."
for nm in $(find ~/Documents ~/Projects ~/ -maxdepth 4 -name "node_modules" -type d 2>/dev/null | head -30); do
  AXIOS_PKG="$nm/axios/package.json"
  if [ -f "$AXIOS_PKG" ]; then
    VER=$(python3 -c "import json; print(json.load(open('$AXIOS_PKG'))['version'])" 2>/dev/null)
    if echo "$VER" | grep -qE '^(1\.14\.1|0\.30\.4)$'; then
      echo "  *** ALERT: COMPROMISED axios $VER in $(dirname $nm) ***"
      FOUND=$((FOUND + 1))
    fi
  fi
  # Check for plain-crypto-js (malicious transitive dep from axios attack)
  if [ -d "$nm/plain-crypto-js" ]; then
    echo "  *** ALERT: plain-crypto-js (malicious package) in $(dirname $nm) ***"
    FOUND=$((FOUND + 1))
  fi
done
echo "  Scan complete"

# ──────────────────────────────────────────────────────
# 3. Global npm check
# ──────────────────────────────────────────────────────
echo "[5/5] Checking npm global packages..."
npm list -g axios 2>/dev/null | grep -E "1\.14\.1|0\.30\.4" && {
  echo "  *** ALERT: COMPROMISED axios in global npm ***"
  FOUND=$((FOUND + 1))
} || echo "  Not found globally (OK)"

# ──────────────────────────────────────────────────────
# Results
# ──────────────────────────────────────────────────────
echo ""
echo "============================================"
if [ $FOUND -gt 0 ]; then
  echo "  RESULT: $FOUND INFECTION(S) DETECTED!"
  echo ""
  echo "  IMMEDIATE ACTIONS REQUIRED:"
  echo "  1. Remove compromised packages immediately"
  echo "  2. Rotate ALL credentials (API keys, tokens, passwords)"
  echo "  3. Reset CI/CD pipeline secrets"
  echo "  4. Audit access logs and monitor for anomalies"
  echo ""
  echo "  WARNING: All credentials on this system should be"
  echo "  considered compromised and must be rotated NOW."
else
  echo "  RESULT: CLEAN - No known compromised packages found"
fi
echo "============================================"
exit $FOUND
