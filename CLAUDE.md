<!-- OMC:START -->
<!-- OMC:VERSION:4.9.1 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>
- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
</operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Route code to `executor` with `model=sonnet` by default. Use `model=opus` ONLY for: architecture design, complex debugging with 5+ files, security review. Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
COST OPTIMIZATION: Default to `sonnet` for all subagents. Only use `opus` when explicitly needed.

| Task | Model | When |
|------|-------|------|
| File search, grep, glob | `haiku` | Always |
| Code generation, editing, writing | `sonnet` | Default for all implementation |
| Explore, research, codebase search | `sonnet` | Standard exploration |
| Architecture decisions, deep debugging | `opus` | Only when Sonnet insufficient |
| Security review, complex refactoring | `opus` | High-stakes changes only |
| Plan design, system design | `opus` | Initial design only, iteration in sonnet |

Rule: Start with `sonnet`. Escalate to `opus` only if the task requires multi-file architectural reasoning, deep causal analysis, or security-sensitive review. Never use `opus` for routine code generation, file creation, or search.

Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

<!-- OMC:END -->

## Supply Chain Security (공급망 공격 방어)

패키지 설치 시 반드시 지켜야 할 규칙:

**절대 규칙 (Hook이 강제 차단):**
1. **piped installer 금지**: `curl | bash`, `wget | sh` 절대 사용 금지.
2. **npm/yarn/pnpm install 시 반드시 `--ignore-scripts`**: postinstall 스크립트가 핵심 공격 벡터 (Axios 1.14.1 RAT 사건). Hook이 없으면 차단됨.
3. **pip install <패키지> 직접 설치 금지**: `pip install -r requirements.txt` 또는 `uv sync` 사용. Python .pth 파일은 설치만으로 모든 프로세스에서 자동 실행됨 (litellm 1.82.8 크레덴셜 스틸러 사건).
4. **publish 금지**: AI가 npm/yarn/pnpm/twine/poetry/uv publish 등 레지스트리 배포 절대 실행 금지.
5. **pip URL 설치 금지**: `pip install https://...` 형태의 직접 URL 설치 금지.

**의존성 고정 (Pinning) 규칙:**
6. **정확한 버전만 사용**: package.json에 `^`, `~` 범위 지정 금지. 정확한 버전(예: `"1.2.3"`)만 사용. `npm install --save-exact` 또는 `--save-prefix=""`로 설치.
7. **Lock 파일 커밋 필수**: package-lock.json, uv.lock, pnpm-lock.yaml, bun.lockb는 반드시 git에 커밋. .gitignore에 lock 파일이 들어있으면 제거.
8. **lockfile 우선**: npm은 `npm ci --ignore-scripts`, Python은 `pip install -r requirements.txt --require-hashes` 또는 `uv sync`. `npm install`보다 `npm ci` 우선.
9. **검증 후 업데이트**: 새 릴리스는 보안 검토 후 수동으로 업데이트. 자동 버전 업그레이드 금지.

**AI 코딩 도구 보안 체크리스트:**
10. **패키지 설치 전 출처 확인**: 패키지 저장소, 메인테이너, 최근 업데이트 이력을 확인 후 설치. npmjs.com 또는 pypi.org에서 주간 다운로드 수 체크.
11. **의존성 트리 검토**: 새 패키지 추가 시 `npm ls <패키지>` 또는 `pipdeptree`로 전이 의존성 확인. 의심스러운 패키지 식별.
12. **설치 실패 시 수동 검토 절차**: min-release-age로 인해 설치가 실패하면, "이 패키지는 7일 미만 릴리즈라 차단됩니다. 수동 검토가 필요합니다"라고 사용자에게 안내하고, 절대 min-release-age를 우회하거나 비활성화하지 마라.
13. **자동 승인 금지**: 패키지 설치가 필요한 경우 "패키지를 설치하겠습니다"라고 먼저 제안하고 사용자 승인을 받아라. 사용자 확인 없이 의존성을 추가하지 마라.
14. **Lock 파일 변경 리뷰**: lock 파일(package-lock.json 등)이 변경될 때, 새로 추가된 의존성 목록을 사용자에게 보여주고 검토 기회를 줘라.
15. **npx/bunx 주의**: 알려진 도구(prettier, eslint 등) 외 패키지는 사용자에게 확인.
16. **bun은 기본 안전**: bun은 lifecycle scripts를 기본 비활성화하므로 안전.
17. **Python 가상환경 필수**: pip install은 반드시 venv 안에서. 시스템 Python에 직접 설치 금지.

**글로벌 패키지 매니저 보안 설정 (적용 완료):**
- `~/.npmrc`: `min-release-age=7`, `ignore-scripts=true` (npm + pnpm 공유)
- `~/.bunfig.toml`: `[install] minimumReleaseAge = 604800` (7일, 초 단위)
- yarn v1: min-release-age 미지원 (Yarn Berry v2+만 가능)

**감염 여부 확인 및 대응:**

사용자가 감염 확인을 요청하거나, 공급망 공격 뉴스가 있을 때 즉시 스캔 실행:
```
bash ~/.claude/hooks/infection-scan.sh
```

감염 확인 명령어 (수동):
- LiteLLM: `pip show litellm` + `find ~/.cache/uv -name "litellm_init.pth"`
- Axios: `npm ls axios | grep -E "1\.14\.1|0\.30\.4"`

**감염 확인 시 즉시 조치 (4단계):**
1. 해당 패키지 즉시 제거 (`npm uninstall`, `pip uninstall`)
2. 모든 자격 증명 회전 (rotate): API 키, 토큰, 비밀번호 전부 교체
3. CI/CD 파이프라인 시크릿 재설정: GitHub Actions secrets, 환경변수 등
4. 접근 로그 감사 및 모니터링: 비정상 접근 패턴 확인

**중요: 감염된 시스템에 존재했던 모든 자격 증명은 이미 유출된 것으로 간주하고 즉시 교체해야 한다.**

**알려진 공급망 공격 사례:**
- Axios 1.14.1 (2025.03): 메인테이너 계정 탈취 → postinstall RAT. 방어: --ignore-scripts
- litellm 1.82.8 (2026.03): CI/CD 토큰 탈취 → .pth 파일 크레덴셜 스틸러. 방어: lockfile + hash 검증

이 규칙들은 `~/.claude/hooks/supply-chain-guard.sh` Hook으로 강제된다.
감염 스캔은 `~/.claude/hooks/infection-scan.sh`로 실행한다.

## Gemini Multimodal Integration

When the gemini-mcp MCP server is available, use Gemini for:

- **Screenshot analysis**: Use `gemini_vision` for UI QA and design review
- **Large codebase analysis**: Use `gemini_code` for reviewing large files or directories
- **Long text summarization**: Use `gemini_summarize` for long-form content

Available MCP tools:
- `gemini_prompt` - Text queries
- `gemini_vision` - Image analysis (multimodal)
- `gemini_code` - Code review and analysis
- `gemini_summarize` - Text summarization

## Design Task Routing (Gemini Pro)

For design-related tasks, prefer Gemini's multimodal capabilities:

- **UI/UX review, visual QA, screenshot analysis** → use `gemini_vision` (MCP) if available
- **Design system, brand identity, visual audit** → invoke `/design-review` or `/design-consultation`
- **Design plan review** → invoke `/plan-design-review`
- When gemini-mcp tools are available AND the task involves images/screenshots → always prefer `gemini_vision` over text-only analysis

### Design Code Writing with Gemini

When writing design-related code (CSS, styling, UI components, layouts, animations, responsive design), actively use Gemini as a co-pilot:

1. **Before writing**: Use `gemini_prompt` to ask Gemini for the best approach to the UI/layout problem. Include context about the framework (React, Vue, Tailwind, etc.) and the desired result.
2. **During writing**: Use `gemini_code` to review your design code for best practices, accessibility, responsive issues, and cross-browser compatibility.
3. **After writing**: Take a screenshot and use `gemini_vision` to evaluate the visual result against the intended design.

**Triggers** (when gemini-mcp is available):
- Writing or modifying CSS, SCSS, Tailwind classes, styled-components, or any styling code → consult `gemini_prompt` first for approach
- Creating UI components (buttons, cards, modals, forms, navigation) → use `gemini_code` to review the component code
- Implementing layouts (grid, flexbox, responsive breakpoints) → ask `gemini_prompt` for optimal layout strategy
- Adding animations or transitions → consult `gemini_prompt` for performance-aware animation patterns
- Fixing visual bugs or alignment issues → screenshot with browse, then `gemini_vision` to diagnose

## Anthropic API Tool Use

When building apps with the Claude API (code imports `anthropic` or `@anthropic-ai/sdk`), use the `/claude-api` skill or follow these patterns.

### Tool Registration Flow

```
User code → [tools + messages] → Claude
Claude → [tool_use block] → User code
User code → [executes tool locally] → result
User code → [tool_result] → Claude
Claude → [final answer] → User code
```

### Tool Definition Structure

```python
{
    "name": "tool_name",           # Claude uses this to call it
    "description": "When exactly to use this tool, in what situation",  # most important
    "input_schema": {
        "type": "object",
        "properties": {
            "param": {"type": "string", "description": "..."}
        },
        "required": ["param"]
    }
}
```

### Agent Loop Pattern

```python
messages = [{"role": "user", "content": user_input}]
while True:
    response = client.messages.create(model=..., tools=tools, messages=messages)
    if response.stop_reason != "tool_use":
        break
    # execute all tool_use blocks
    tool_results = []
    for block in response.content:
        if block.type == "tool_use":
            result = execute_tool(block.name, block.input)
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": result
            })
    messages.append({"role": "assistant", "content": response.content})
    messages.append({"role": "user", "content": tool_results})
```

### Design Rules

- One tool = one atomic action. Never bundle multiple actions in one tool.
- `description` determines when Claude calls the tool. Be specific: "Use when user asks X" > "Does X".
- Tools can be anything: file I/O, DB queries, web requests, shell commands, external APIs.
- `advisor_20260301` type available for sub-model invocation (e.g., opus as advisor within sonnet executor).
