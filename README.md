# ez2claude

> Personal Claude Code battle station. Multi-agent orchestration, supply-chain hardened,
> opinionated routing. My personal setup, packaged for reuse across machines.

```
  ___ ____  ____   ____ _        _   _   _ ____  _____
 | __|__  |/ ___| / ___| | __ _ _| |_| | | |  _ \| ____|
 | _|  / /| |    | |   | |/ _` / _` | | | | | | |  _|
 | |__/ / | |___ | |___| | (_| \__,_| |_| |_| | |___
 |____|_/  \____|_\____|_|\__,_|\__,_|\___/|____/|_____|
```

ez2claude is a curated `~/.claude/` configuration: **19 specialized agents** across
Opus/Sonnet/Haiku, **3 supply-chain guard hooks**, strict routing rules, and
opinionated defaults tuned for multi-agent delegation.

Tested on macOS (zsh). Works anywhere Claude Code runs.

---

## Why this exists

Claude Code is powerful but your productivity sits on top of `~/.claude/` config,
custom agents, hooks, and muscle memory. Moving to a new laptop means losing all of it.

This repo is my personal Claude Code cockpit, version-controlled. Clone, run
`bootstrap.sh`, and a fresh machine behaves exactly like mine.

---

## What's inside

| Layer | What it does | Files |
|-------|--------------|-------|
| **CLAUDE.md** | Global orchestration prompt: agent delegation rules, model routing, supply-chain rules, Gemini multimodal integration | `CLAUDE.md` |
| **Agents (19)** | Opus for heavy thinking (architect, planner, critic, analyst, code-reviewer, code-simplifier). Sonnet for code work (executor, debugger, verifier, designer, qa-tester, test-engineer, security-reviewer, tracer, git-master, document-specialist, scientist). Haiku for speed (explore, writer). Model is locked per agent — orchestrator model is irrelevant. | `agents/*.md` |
| **Hooks (3)** | `supply-chain-guard.sh` blocks `curl | bash`, npm publish, pip URL installs, unverified npx. `lockfile-change-alert.sh` reports new dependencies. `infection-scan.sh` detects known malicious packages (Axios 1.14.1 RAT, litellm 1.82.8 stealer). | `hooks/*.sh` |
| **Settings** | `settings.json.example` with experimental agent teams enabled, Haiku as default subagent, denied destructive commands, MCP server registration, HUD status line. Rendered at install time from your `.env`. | `settings.json.example` |
| **Supply-chain config** | `.npmrc.example` + `.bunfig.toml.example` enforce `min-release-age=3 days`, `ignore-scripts=true`, `save-exact=true`. | `.npmrc.example`, `.bunfig.toml.example` |
| **bootstrap.sh** | Idempotent installer: symlinks everything into `~/.claude/`, backs up pre-existing files, renders settings, writes npm/bun hardening. | `bootstrap.sh` |

---

## Install

```bash
git clone https://github.com/ez2sarang/ez2claude.git
cd ez2claude
cp .env.example .env             # fill in GEMINI_API_KEY if you want Gemini MCP
./bootstrap.sh
```

That's it. Restart Claude Code and the setup is live.

Re-running `bootstrap.sh` is safe: existing `~/.claude/CLAUDE.md`, `settings.json`,
`agents/`, and `hooks/` are backed up with a timestamp before being replaced.

---

## Core behaviors

### Model routing is opinionated
Every agent file in `agents/` has a fixed `model:` field. The orchestrator session
model does not matter — the architect always runs on Opus, the executor always runs
on Sonnet, explore always runs on Haiku. Run `/model sonnet` to cut your
orchestration cost; Opus work is delegated anyway.

### Three-tier supply-chain defense
1. **Publish blocked** — `npm/yarn/pnpm/twine/poetry/uv publish` are denied by Claude Code
   permissions. AI cannot accidentally push to a registry.
2. **Install hardened** — `min-release-age=3 days` blocks fresh malicious releases
   (Axios 1.14.1 would have been blocked at day 3). `ignore-scripts=true` neutralizes
   postinstall RATs. `save-exact=true` kills silent version drift.
3. **Pipe installers refused** — `curl | bash` and friends return exit 2.

Known attacks covered:
- Axios 1.14.1 (2025.03) — postinstall RAT from maintainer account takeover
- litellm 1.82.8 (2026.03) — `.pth` credential stealer via CI/CD token theft

Run `hooks/infection-scan.sh` any time to audit your installed packages.

### Delegation is the default
CLAUDE.md tells Claude: multi-file edits, refactors, debugging, reviews, planning,
research, verification → delegate. Trivial ops stay inline. Cost routing: Haiku first,
Sonnet default, Opus only for architectural reasoning or security review.

### Gemini is a co-pilot for design
When `gemini-mcp` is available (optional MCP server), screenshot analysis goes to
Gemini Vision, code review to Gemini, text summarization to Gemini. Claude stays the
orchestrator; Gemini fills the multimodal gap.

---

## File layout

```
ez2claude/
├── CLAUDE.md                   # global orchestration prompt (~/ .claude/CLAUDE.md)
├── agents/                     # 19 agent definitions (~/ .claude/agents/)
│   ├── architect.md            (opus)
│   ├── planner.md              (opus)
│   ├── critic.md               (opus)
│   ├── analyst.md              (opus)
│   ├── code-reviewer.md        (opus)
│   ├── code-simplifier.md      (opus)
│   ├── executor.md             (sonnet)
│   ├── debugger.md             (sonnet)
│   ├── verifier.md             (sonnet)
│   ├── designer.md             (sonnet)
│   ├── qa-tester.md            (sonnet)
│   ├── test-engineer.md        (sonnet)
│   ├── security-reviewer.md    (sonnet)
│   ├── tracer.md               (sonnet)
│   ├── git-master.md           (sonnet)
│   ├── document-specialist.md  (sonnet)
│   ├── scientist.md            (sonnet)
│   ├── explore.md              (haiku)
│   └── writer.md               (haiku)
├── hooks/                      # supply-chain guards (~/ .claude/hooks/)
│   ├── supply-chain-guard.sh
│   ├── lockfile-change-alert.sh
│   └── infection-scan.sh
├── settings.json.example       # rendered into ~/.claude/settings.json at install
├── .env.example                # GEMINI_API_KEY + NPM_MIN_RELEASE_AGE_DAYS
├── .npmrc.example              # min-release-age=3, ignore-scripts, save-exact
├── .bunfig.toml.example        # minimumReleaseAge = 259200 (3 days)
├── bootstrap.sh                # the installer
└── docs/
    ├── ARCHITECTURE.md         # how the pieces fit
    ├── SECURITY.md             # supply-chain threat model
    └── CONTACT.md              # how to get in touch
```

---

## Requirements

- Claude Code CLI (latest)
- bash, node, git
- Optional: `bun` (for `.bunfig.toml` hardening and gemini MCP runtime)
- Optional: `any-buddy` CLI (SessionStart hook is a no-op without it)
- Optional: Gemini API key for multimodal tools

---

## What this is NOT

- Not a fork of [garrytan/gstack](https://github.com/garrytan/gstack). gstack is the
  browser+QA+ship skill framework. ez2claude is about `~/.claude/` itself: agents,
  hooks, and orchestration defaults. The two compose.
- Not a marketplace plugin. Install via `bootstrap.sh`, edit anything freely.
- Not a blog-style essay. Every file has one job.

---

## License

MIT. See [LICENSE](LICENSE).

---

## Contact

Business inquiries, custom integrations, or questions for the author:

**📧 sales@com.dooray.com**

See [docs/CONTACT.md](docs/CONTACT.md) for details.
