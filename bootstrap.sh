#!/usr/bin/env bash
# ez2claude bootstrap — symlink config into ~/.claude and set up npm/bun guards.
# Safe to re-run: existing files are backed up with a timestamp.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
STAMP="$(date +%Y%m%d-%H%M%S)"

say()  { printf "\033[1;36m[ez2claude]\033[0m %s\n" "$1"; }
warn() { printf "\033[1;33m[ez2claude]\033[0m %s\n" "$1"; }
die()  { printf "\033[1;31m[ez2claude]\033[0m %s\n" "$1" >&2; exit 1; }

backup_if_real() {
  local target="$1"
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    warn "Backing up $target -> ${target}.bak.${STAMP}"
    mv "$target" "${target}.bak.${STAMP}"
  elif [ -L "$target" ]; then
    rm "$target"
  fi
}

link() {
  local src="$1" dst="$2"
  backup_if_real "$dst"
  mkdir -p "$(dirname "$dst")"
  ln -s "$src" "$dst"
  say "Linked $dst -> $src"
}

# --------------------------------------------------
# 1. Preflight
# --------------------------------------------------
[ -d "$CLAUDE_HOME" ] || die "$CLAUDE_HOME does not exist. Run Claude Code once first."
command -v claude >/dev/null 2>&1 || warn "\`claude\` CLI not on PATH. Continuing."

# --------------------------------------------------
# 2. Link CLAUDE.md + agents + hooks
# --------------------------------------------------
link "$REPO_DIR/CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"

mkdir -p "$CLAUDE_HOME/agents"
for f in "$REPO_DIR/agents/"*.md; do
  link "$f" "$CLAUDE_HOME/agents/$(basename "$f")"
done

mkdir -p "$CLAUDE_HOME/hooks"
for f in "$REPO_DIR/hooks/"*.sh; do
  link "$f" "$CLAUDE_HOME/hooks/$(basename "$f")"
  chmod +x "$f"
done

# --------------------------------------------------
# 3. Render settings.json from example (with env vars)
# --------------------------------------------------
if [ -f "$REPO_DIR/.env" ]; then
  set -a; . "$REPO_DIR/.env"; set +a
fi
: "${GEMINI_API_KEY:=}"

backup_if_real "$CLAUDE_HOME/settings.json"
if [ -n "$GEMINI_API_KEY" ]; then
  sed "s|\${GEMINI_API_KEY}|$GEMINI_API_KEY|g" "$REPO_DIR/settings.json.example" > "$CLAUDE_HOME/settings.json"
  say "Rendered settings.json with your Gemini API key."
else
  # Drop the gemini mcpServers block so Claude Code does not fail.
  node -e "
    const fs=require('fs');
    const j=JSON.parse(fs.readFileSync('$REPO_DIR/settings.json.example','utf8'));
    if (j.mcpServers) delete j.mcpServers.gemini;
    fs.writeFileSync('$CLAUDE_HOME/settings.json', JSON.stringify(j, null, 2));
  " 2>/dev/null || cp "$REPO_DIR/settings.json.example" "$CLAUDE_HOME/settings.json"
  warn "GEMINI_API_KEY empty. Gemini MCP disabled. Set it in .env and re-run to enable."
fi

# --------------------------------------------------
# 4. Install npm / bun supply-chain guards
# --------------------------------------------------
MIN_AGE_DAYS="${NPM_MIN_RELEASE_AGE_DAYS:-3}"
MIN_AGE_SEC=$((MIN_AGE_DAYS * 86400))

if [ ! -f "$HOME/.npmrc" ] || ! grep -q "min-release-age" "$HOME/.npmrc"; then
  {
    echo ""
    echo "# ez2claude supply-chain hardening"
    echo "min-release-age=$MIN_AGE_DAYS"
    echo "ignore-scripts=true"
    echo "save-exact=true"
  } >> "$HOME/.npmrc"
  say "Added ~/.npmrc hardening (min-release-age=$MIN_AGE_DAYS days)."
else
  say "~/.npmrc already has min-release-age. Skipped."
fi

if command -v bun >/dev/null 2>&1; then
  if [ ! -f "$HOME/.bunfig.toml" ] || ! grep -q "minimumReleaseAge" "$HOME/.bunfig.toml"; then
    {
      echo ""
      echo "[install]"
      echo "minimumReleaseAge = $MIN_AGE_SEC"
    } >> "$HOME/.bunfig.toml"
    say "Added ~/.bunfig.toml hardening (minimumReleaseAge=${MIN_AGE_SEC}s)."
  else
    say "~/.bunfig.toml already has minimumReleaseAge. Skipped."
  fi
fi

# --------------------------------------------------
# 5. Optional: any-buddy (SessionStart hook uses it)
# --------------------------------------------------
if ! command -v any-buddy >/dev/null 2>&1; then
  warn "any-buddy CLI not found. SessionStart hook will no-op."
  warn "Install with: npm i -g any-buddy   (optional, --ignore-scripts will apply)"
fi

say "Done. Restart Claude Code to apply."
say "Next: edit .env with your Gemini API key (optional), then run \`claude\`."
