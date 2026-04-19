# Architecture

How ez2claude slots into Claude Code.

## Runtime shape

```
┌─────────────────────────────────────────────┐
│               Claude Code session            │
│                                              │
│   orchestrator model ── reads ───▶ CLAUDE.md │
│         │                                    │
│         ├── delegates ──▶ agents/*.md        │
│         │                   (fixed model)    │
│         │                                    │
│         ├── Bash call ──┐                    │
│         │               ▼                    │
│         │         PreToolUse hook            │
│         │      supply-chain-guard.sh         │
│         │                                    │
│         └── Bash done ──┐                    │
│                         ▼                    │
│                   PostToolUse hook           │
│                lockfile-change-alert.sh      │
└─────────────────────────────────────────────┘
            │                      │
            ▼                      ▼
    ~/.npmrc            ~/.claude/plugins/...
    ~/.bunfig.toml           (MCP servers)
```

Everything lives under `~/.claude/`. `bootstrap.sh` creates symlinks from the cloned
repo into `~/.claude/`, so a `git pull` plus a Claude Code restart is the whole
update flow.

## CLAUDE.md: the orchestration prompt

Every Claude Code session reads `~/.claude/CLAUDE.md` as user-wide instructions.
ez2claude's CLAUDE.md is opinionated:

- **Delegation rules** — when to spawn agents vs. work inline.
- **Model routing table** — what model each task class uses.
- **Supply-chain rules** — which commands are hard-denied (publish, piped installers).
- **Gemini MCP integration** — which tasks prefer `gemini_vision` / `gemini_code`.
- **Tool-use patterns for the Anthropic API** — agent loop template for builds
  that run Claude as a library.

CLAUDE.md is the contract. Agents and hooks are the mechanism.

## Agents: fixed-model specialists

```
analyst        opus     requirements analysis
architect      opus     system design
planner        opus     execution plans
critic         opus     multi-perspective review
code-reviewer  opus     severity-rated code review
code-simplifier opus    behavior-preserving simplification

executor       sonnet   implementation work
debugger       sonnet   root-cause tracing
verifier       sonnet   evidence-based completion checks
designer       sonnet   UI/UX
qa-tester      sonnet   interactive CLI testing
test-engineer  sonnet   test strategy
security-reviewer sonnet secrets/OWASP detection
tracer         sonnet   causal tracing
git-master     sonnet   atomic commits
document-specialist sonnet docs + MCP lookup
scientist      sonnet   data analysis

explore        haiku    codebase search
writer         haiku    light docs
```

Each agent file's YAML frontmatter has `model:`, so the agent always runs on that
model regardless of what the orchestrator is using. You can `/model sonnet` the
main session for cheaper orchestration; the Opus agents still spawn on Opus.

## Hooks: supply-chain checkpoints

```
PreToolUse (Bash)      ── supply-chain-guard.sh
  ├─ block curl|bash, wget|sh
  ├─ block install.sh / setup.sh style piped installers
  ├─ block npm/yarn/pnpm/twine/poetry/uv publish
  ├─ block pip install <url> and pip install without lockfile
  ├─ block gem install from non-default sources
  ├─ warn on new npm/bun dependency adds (with checklist)
  ├─ block `npm config set ignore-scripts` / `min-release-age`
  └─ block npx/bunx of unknown packages (allow known tools)

PostToolUse (Bash)     ── lockfile-change-alert.sh
  └─ report package-lock.json / pnpm-lock.yaml / bun.lockb diffs

SessionStart           ── any-buddy apply --silent
  └─ optional; no-op if any-buddy is not installed

On-demand              ── hooks/infection-scan.sh
  ├─ scan for litellm_init.pth and related .pth stealers
  └─ scan npm tree for Axios 1.14.1 / 0.30.4 and similar known-bad versions
```

Hooks run as shell scripts. They are text; read them, modify them, sign-off on them.
Anyone auditing the setup can see every block rule in ~300 lines of bash.

## Settings: runtime toggles

`settings.json.example` exposes:

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` — multi-agent orchestration features
- `MAX_THINKING_TOKENS=10000` — extended thinking budget for Opus reasoning
- `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1` — deterministic thinking allocation
- `CLAUDE_CODE_SUBAGENT_MODEL=haiku` — subagents default to Haiku when no frontmatter model
- `permissions.deny` — destructive/publish commands always blocked
- `model: sonnet[1m]` — orchestrator default

At install time, `bootstrap.sh` substitutes `${GEMINI_API_KEY}` from your `.env` and
writes the final file to `~/.claude/settings.json`. The settings file is listed in
`.gitignore` so the real one never lands in git.

## NPM / Bun hardening

`bootstrap.sh` appends three lines to `~/.npmrc`:

```
min-release-age=3
ignore-scripts=true
save-exact=true
```

and, if `bun` is installed, to `~/.bunfig.toml`:

```toml
[install]
minimumReleaseAge = 259200
```

These settings are defense in depth. The PreToolUse hook catches commands; `.npmrc`
catches whatever the hook missed (or future variants).

## What ez2claude does NOT own

- MCP servers (`~/.claude/plugins/local/*`) — those are separate projects.
- Claude Code binary install — install the CLI first.
- Project-specific `CLAUDE.md` files — those live per-repo.
- Skills / plugins from other frameworks (gstack, OMC, ECC) — install alongside as needed.
