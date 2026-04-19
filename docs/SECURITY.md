# Security

## Threat model

AI coding tools happily run `npm install <whatever>`. The attack surface is huge:

1. **Typosquat** — `lodash` vs `l0dash`. AI invents package names sometimes.
2. **Maintainer takeover** — a legitimate package ships a malicious version
   (Axios 1.14.1, 2025.03).
3. **Postinstall RAT** — `npm install` executes `scripts.postinstall` from the package.
4. **Credential stealer via `.pth`** — Python's `site-packages/*.pth` files run on every
   import (litellm 1.82.8, 2026.03).
5. **Supply-chain-of-supply-chain** — a transitive dep you did not ask for.
6. **Accidental `publish`** — AI auto-publishes your private code to npm/PyPI.

ez2claude layers multiple controls so that **any single miss still fails safe**.

## Controls

### Hard blocks (Claude Code permissions.deny)

```
Bash(curl * | bash)      Bash(npm publish*)      Bash(twine upload*)
Bash(curl * | sh)        Bash(yarn publish*)     Bash(poetry publish*)
Bash(wget * | bash)      Bash(pnpm publish*)     Bash(uv publish*)
Bash(wget * | sh)
```

These never prompt. They are blocked by Claude Code itself before the shell sees them.

### Regex blocks (PreToolUse hook: supply-chain-guard.sh)

Catches variants the permission list misses:

- Piped installers: `curl ...install.sh | bash`
- Publish attempts in wrapper scripts
- Package installs without `--ignore-scripts`
- `pip install https://...` (direct URL install)
- `pip install <pkg>` without lockfile or hash verification
- `gem install --source https://...`
- `npx <unknown-pkg>` / `bunx <unknown-pkg>` — only a whitelist of known tools passes

### Package manager config (~/.npmrc, ~/.bunfig.toml)

- `min-release-age=3` — npm refuses packages published less than 3 days ago.
  Most malicious releases are detected and yanked within 72 hours.
  Set `NPM_MIN_RELEASE_AGE_DAYS=7` in `.env` and re-run `bootstrap.sh` for stricter.
- `ignore-scripts=true` — lifecycle scripts disabled globally. Use `--foreground-scripts`
  if you truly need them.
- `save-exact=true` — exact versions only. No ^ / ~ drift.
- Bun's lifecycle scripts are disabled by default; `minimumReleaseAge` adds release-age protection.

### Runtime audits (hooks/infection-scan.sh)

Run on demand. Detects:

- Axios 1.14.1 / 0.30.4 in `npm ls` tree
- litellm 1.82.8 via `pip show litellm`
- `litellm_init.pth` in `~/.cache/uv`

If infected: uninstall, rotate all credentials (API keys, tokens, passwords, CI/CD secrets),
audit access logs.

## What to do if a secret leaked

ez2claude will never intentionally publish secrets. The `bootstrap.sh` installer reads
`.env` locally and renders `settings.json` into `~/.claude/settings.json`. The real
settings file is `.gitignore`d.

If you accidentally committed a secret:

1. **Rotate it immediately.** Assume the leaked secret is compromised.
2. Remove from git history: `git filter-repo --path settings.json --invert-paths` (preferred
   over `filter-branch`), then force-push.
3. GitHub caches: if the repo was public for more than a few seconds, assume indexed.
   Rotate regardless.
4. Enable GitHub secret scanning on the repo for future protection.

## Reporting a vulnerability

Email **sales@com.dooray.com**. We respond within 48 hours. Do not open a public issue.
