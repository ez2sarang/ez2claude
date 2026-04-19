#!/bin/bash
# supply-chain-guard.sh
# Blocks or warns on dangerous package installation patterns.
# Based on: Axios NPM supply chain attack (2025), litellm PyPI attack (2026)
# HN item 47582632
#
# Exit 0 = allow, Exit 2 = block (stderr sent to Claude as feedback)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# ──────────────────────────────────────────────────────
# 0. Allow --help, --version, and info/audit/list commands
# ──────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qEi '\-\-help|\-\-version|\-h\b'; then
  exit 0
fi
if echo "$COMMAND" | grep -qEi '(npm|yarn|pnpm|bun|pip|uv)\s+(audit|list|ls|info|show|outdated|why|doctor)\b'; then
  exit 0
fi
# Allow config read commands (list, get) but NOT config set/delete
if echo "$COMMAND" | grep -qEi '(npm|yarn|pnpm)\s+config\s+(list|get|ls)\b'; then
  exit 0
fi

# ──────────────────────────────────────────────────────
# 1. Block piped installers: curl|bash, wget|sh, etc.
# ──────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qEi '(curl|wget)\s.*\|\s*(ba)?sh|install\.sh|setup\.sh'; then
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: piped installer detected." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Risk: Arbitrary code execution from remote source." >&2
  echo "  Fix: Download the script first, review it, then execute." >&2
  exit 2
fi

# ──────────────────────────────────────────────────────
# 2. Enforce --ignore-scripts on package installs
#    Axios attack (2025): postinstall in transitive dep
#    plain-crypto-js dropped a RAT via node setup.js.
#    This is the #1 supply chain attack vector.
# ──────────────────────────────────────────────────────

# 2a. Always allow: npm ci, --frozen-lockfile, --ignore-scripts
#     These are safe patterns that don't run arbitrary scripts
#     or only install exact lockfile versions.
if echo "$COMMAND" | grep -qEi 'npm\s+ci\b'; then
  # npm ci from frozen lockfile is safe (pins exact versions)
  # Still warn if --ignore-scripts is missing
  if ! echo "$COMMAND" | grep -qEi '\-\-ignore-scripts'; then
    echo "[SUPPLY-CHAIN-GUARD] TIP: Consider adding --ignore-scripts to npm ci for maximum safety." >&2
    echo "  Even lockfile installs run postinstall scripts (see: Axios attack 2025)." >&2
  fi
  exit 0
fi

if echo "$COMMAND" | grep -qEi '(pnpm|yarn)\s+install.*\-\-frozen-lockfile'; then
  exit 0
fi

# 2b. Block: npm/yarn/pnpm install WITHOUT --ignore-scripts
#     This is the exact vector used in the Axios attack.
if echo "$COMMAND" | grep -qEi '(npm|yarn|pnpm)\s+(install|add|i)\b'; then
  if echo "$COMMAND" | grep -qEi '\-\-ignore-scripts'; then
    # --ignore-scripts present = safe, allow through
    exit 0
  fi
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: Package install without --ignore-scripts." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Risk: Lifecycle scripts (preinstall/postinstall) execute arbitrary code." >&2
  echo "  Case study: Axios 1.14.1 (2025) ran a RAT dropper via postinstall." >&2
  echo "  Fix options:" >&2
  echo "    1. Add --ignore-scripts flag: npm install --ignore-scripts" >&2
  echo "    2. Use npm ci (frozen lockfile): npm ci --ignore-scripts" >&2
  echo "    3. Use npm ci without flag (lockfile-only, lower risk)" >&2
  exit 2
fi

# 2c. bun install: bun disables lifecycle scripts by default, allow
if echo "$COMMAND" | grep -qEi 'bun\s+(install|add|i)\b'; then
  echo "[SUPPLY-CHAIN-GUARD] NOTE: bun disables lifecycle scripts by default (safe)." >&2
  exit 0
fi

# ──────────────────────────────────────────────────────
# 3. Block npm publish / package registry mutations
# ──────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qEi '(npm|yarn|pnpm|bun)\s+publish'; then
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: Package publish detected." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Risk: Publishing should be a deliberate human action, not AI-initiated." >&2
  exit 2
fi

# ──────────────────────────────────────────────────────
# 4. Python package security (pip, uv, poetry)
#    litellm attack (2026): .pth file auto-executes on
#    every Python startup. No --ignore-scripts equivalent.
#    TeamPCP stole PyPI token via compromised CI action.
# ──────────────────────────────────────────────────────

# 4a. Block pip install from arbitrary URLs
if echo "$COMMAND" | grep -qEi 'pip3?\s+install\s+.*https?://'; then
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: pip install from direct URL." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Risk: Arbitrary URLs bypass PyPI security scanning." >&2
  echo "  Fix: Install from PyPI by package name, or add to requirements.txt for review." >&2
  exit 2
fi

# 4b. Allow: pip install -r requirements.txt (lockfile pattern)
#     Also allow: pip install -e . (editable local install)
if echo "$COMMAND" | grep -qEi 'pip3?\s+install\s+(-r\s|--requirement\s|-e\s+\.)'; then
  echo "[SUPPLY-CHAIN-GUARD] NOTE: Installing from requirements file or local editable." >&2
  echo "  TIP: Use --require-hashes for maximum safety (verifies package integrity)." >&2
  exit 0
fi

# 4c. Allow: uv sync / uv pip install -r (lockfile patterns)
if echo "$COMMAND" | grep -qEi 'uv\s+sync\b|uv\s+pip\s+install\s+-r\b|uv\s+pip\s+install\s+--requirement'; then
  echo "[SUPPLY-CHAIN-GUARD] NOTE: uv lockfile-based install (good practice)." >&2
  exit 0
fi

# 4d. Block: pip install <package> (direct package install without lockfile)
#     Python has no --ignore-scripts. A .pth file in the package
#     will auto-execute on every Python process startup.
if echo "$COMMAND" | grep -qEi 'pip3?\s+install\s+[a-zA-Z@]'; then
  # Allow if --require-hashes is present (integrity verified)
  if echo "$COMMAND" | grep -qEi '\-\-require-hashes'; then
    echo "[SUPPLY-CHAIN-GUARD] NOTE: pip install with --require-hashes (integrity verified)." >&2
    exit 0
  fi
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: pip install without lockfile or hash verification." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Risk: Python packages can include .pth files that auto-execute on every" >&2
  echo "  Python process startup. No --ignore-scripts equivalent exists for pip." >&2
  echo "  Case study: litellm 1.82.8 (2026) used .pth to steal cloud credentials." >&2
  echo "  Fix options:" >&2
  echo "    1. Use requirements.txt: pip install -r requirements.txt" >&2
  echo "    2. Use hash verification: pip install --require-hashes -r requirements.txt" >&2
  echo "    3. Use uv with lockfile: uv sync" >&2
  echo "    4. Use virtual environment + pin exact versions" >&2
  exit 2
fi

# 4e. Block: uv add / uv pip install <package> (direct, no lockfile)
if echo "$COMMAND" | grep -qEi 'uv\s+(add|pip\s+install)\s+[a-zA-Z@]'; then
  # Allow uv add if --frozen or --locked
  if echo "$COMMAND" | grep -qEi '\-\-(frozen|locked)'; then
    exit 0
  fi
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: uv package install without lockfile." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Risk: Same as pip. Python .pth files auto-execute on startup." >&2
  echo "  Fix: Use uv sync (lockfile-based) or uv add --frozen." >&2
  exit 2
fi

# 4f. Block: poetry add (direct package, no lock)
if echo "$COMMAND" | grep -qEi 'poetry\s+add\s+[a-zA-Z@]'; then
  echo "[SUPPLY-CHAIN-GUARD] WARNING: Adding new Python dependency via poetry." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Verify the package name carefully (typosquatting)." >&2
  echo "  Run 'poetry lock' first, review changes, then 'poetry install'." >&2
  exit 0
fi

# 4g. Block: twine upload / poetry publish (PyPI publish)
if echo "$COMMAND" | grep -qEi '(twine\s+upload|poetry\s+publish|uv\s+publish)'; then
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: PyPI publish detected." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Risk: Publishing should be a deliberate human action." >&2
  exit 2
fi

# ──────────────────────────────────────────────────────
# 5. Block gem install from arbitrary sources
# ──────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qEi 'gem\s+install\s+.*--source\s+https?://'; then
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: gem install from non-default source." >&2
  echo "  Command: $COMMAND" >&2
  exit 2
fi

# ──────────────────────────────────────────────────────
# 6. Warn on adding NEW dependencies (not from lockfile)
#    Per defense strategy: verify source, check deps tree,
#    use --save-exact, review lock file changes.
# ──────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qEi '(npm|yarn|pnpm|bun)\s+add\b|npm\s+install\s+[a-z@]'; then
  echo "[SUPPLY-CHAIN-GUARD] NOTE: Adding new dependency." >&2
  echo "  Command: $COMMAND" >&2
  echo "  Security checklist:" >&2
  echo "    1. Verify package name (typosquatting is common)" >&2
  echo "    2. Check npmjs.com: weekly downloads, maintainer, last publish date" >&2
  echo "    3. Use --save-exact to pin exact version (no ^/~ ranges)" >&2
  echo "    4. After install, review lock file changes for unexpected transitive deps" >&2
  echo "    5. Run 'npm ls <package>' to inspect the full dependency tree" >&2
  MIN_AGE="${NPM_MIN_RELEASE_AGE_DAYS:-3}"
  echo "  NOTE: min-release-age=${MIN_AGE} is active. Packages <${MIN_AGE} days old will be rejected." >&2
  exit 0
fi

# ──────────────────────────────────────────────────────
# 6b. Warn when npm/pnpm config is being modified
#     (prevent disabling security settings)
# ──────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qEi '(npm|pnpm)\s+config\s+set\s+(ignore-scripts|min-release-age)'; then
  echo "[SUPPLY-CHAIN-GUARD] BLOCKED: Modifying security-critical config." >&2
  echo "  Command: $COMMAND" >&2
  echo "  These settings protect against supply chain attacks." >&2
  echo "  Do not disable ignore-scripts or change min-release-age." >&2
  exit 2
fi

# ──────────────────────────────────────────────────────
# 7. Block npx/bunx of unknown packages (potential typosquat)
# ──────────────────────────────────────────────────────
if echo "$COMMAND" | grep -qEi '(npx|bunx|pnpm\s+dlx)\s+[a-z]'; then
  # Allow known safe tools
  SAFE_TOOLS="prettier|eslint|tsc|typescript|create-next-app|create-react-app|create-vite|vitest|jest|tsx|ts-node|tailwindcss|drizzle-kit|prisma|turbo|next|nuxi|wrangler|svelte-kit|astro|degit|serve|http-server|json-server|nodemon|concurrently|rimraf|cross-env|dotenv"
  PKG=$(echo "$COMMAND" | grep -oEi '(npx|bunx|pnpm\s+dlx)\s+(@?[a-z0-9_-]+(/[a-z0-9_-]+)?)' | awk '{print $NF}')
  if [ -n "$PKG" ] && ! echo "$PKG" | grep -qEi "^($SAFE_TOOLS)$"; then
    echo "[SUPPLY-CHAIN-GUARD] WARNING: npx/bunx executing remote package '$PKG'." >&2
    echo "  Command: $COMMAND" >&2
    echo "  Risk: npx downloads and executes packages on the fly." >&2
    echo "  Verify this is the correct package name (typosquatting risk)." >&2
    exit 0
  fi
fi

exit 0
