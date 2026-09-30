# Smart Model Router

[![Model family](https://img.shields.io/badge/models-GPT--6-blue)](./plugins/smart-model-router/.codex-plugin/plugin.json)
[![CI](https://github.com/Jerry461998/smart-model-router/actions/workflows/test.yml/badge.svg)](https://github.com/Jerry461998/smart-model-router/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-green)](./plugins/smart-model-router/LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)](#requirements)

Smart Model Router is a Codex plugin and global routing layer for people who want **different models to handle different parts of a coding task** instead of running everything through the most expensive model.

It keeps the main Codex task as the coordinator, classifies bounded phases, launches model-specific workers with explicit `model` and `reasoning_effort`, verifies their output, and only escalates when the evidence justifies it.

## What it does

| Phase | Typical worker | Purpose |
|---|---|---|
| Exploration / search / mechanical edits | GPT-6 Luna Low | Fast, low-cost discovery and routine work |
| Normal implementation / medium debugging | GPT-6.1 Sol Medium | Main coding and integration work |
| Architecture / production / security / consistency | GPT-6.1 Sol High | High-reasoning expert analysis |
| Final escalation | GPT-6 Astra | Gated fallback after evidence-backed Sol attempts or explicit user request |

The router does **not** pretend to switch the model of an already-running main task. It dispatches separate subagents and reports the actual route used.

## GPT-6.1 Sol policy (0.2.0)

Generic Sol and all default Sol profiles/phases use `gpt-6.1-sol`; the root defaults to medium. Use low for clearly bounded nonmechanical fixes, medium for ordinary features/debugging, high for complex/security/concurrency work, and xhigh for an evidence-backed serious retry after one complex Sol failure. Mechanical work stays on Luna low; independent routine verification uses Luna medium. The stable Sol profile IDs retain medium/high/high defaults; native roles with locked effort require a default worker with explicit model/effort for low or xhigh.

Automatic Astra still requires two distinct evidence-backed tested Sol hypotheses, an unresolved high-consequence issue, and `ESCALATION_REASON`; prefer the serious GPT-6.1 Sol xhigh retry first. A numeric failure count attests to those attempts and does not prove them. Explicit Astra requests bypass the attempt count while preserving other user constraints.

If GPT-6.1 Sol is unavailable in the runtime, disclose that limitation before using available `gpt-6-sol` at the same effort when compatible with user instructions. Do not silently substitute models or count availability/tool failures toward Astra. Requests requiring only GPT-6.1 Sol must receive the blocker. Explicit `gpt-6-sol` requests retain that model; “use gpt-6.1-sol”, “6.1 Sol”, and Chinese “6.1sol” select GPT-6.1 Sol. See [official GPT-6.1 Sol documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol).

## When to use it

Use Smart Model Router when you regularly give Codex multi-step software tasks and want a more deliberate split between fast workers, implementation workers, expert reasoning, and rare escalation. It is especially useful for repository work that mixes search, implementation, verification, debugging, architecture, production incidents, CI/CD, migrations, concurrency, or security review.

It is less suitable if you do not want any global Codex configuration changes, your account/workspace does not expose the configured models, or you expect a plugin to change the model of the already-running parent task in place.

## Quick start

### 1. Clone

```powershell
git clone https://github.com/Jerry461998/smart-model-router.git
cd smart-model-router
```

### 2. Install

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\INSTALL.ps1
```

### 3. Start a new Codex task

Plugin and skill discovery are refreshed when a new Codex task/session starts.

### 4. Check status

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\STATUS.ps1
```

### 5. Uninstall

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\UNINSTALL.ps1
```

## Requirements

- Windows
- PowerShell
- Git
- Python 3
- Codex CLI / Codex desktop with plugin and subagent support
- Access to the models used by the configured workers

The earlier GPT-6 update was tested against Codex CLI `0.154.0` on Windows. Version 0.2.0 adds isolated installer and routing regression coverage. Model availability depends on account rollout and workspace settings.

## What the installer changes

The installer is idempotent and creates timestamped backups before configuration writes. It manages:

- plugin source under `%USERPROFILE%\plugins\smart-model-router`
- personal marketplace registration
- six Codex custom-agent profiles under `%USERPROFILE%\.codex\agents`
- a managed global routing block in `%USERPROFILE%\.codex\AGENTS.md`
- root Codex defaults in `%USERPROFILE%\.codex\config.toml`
- install state and backups under `%USERPROFILE%\.codex\smart-model-router`

The default root model is set to `gpt-6.1-sol` with `medium` reasoning. Uninstall restores the pre-install root/agent settings recorded in install state and preserves owned files that were modified after installation. Existing, unchanged Terra-named profiles from v0.1.0 are removed during upgrade.

## Routing overview

| Work | Default route |
|---|---|
| Text/CSS, search, deterministic bulk edit | Luna low |
| Ordinary CRUD / website feature | Luna explore → Sol medium implement → Luna verify |
| Medium integration / debugging | Luna collect → Sol medium diagnose/build → Luna verify; Sol high when needed |
| Production-only / cross-service incident | Luna collect → Sol medium initial diagnosis → conditional Sol high |
| Architecture / CI-CD / DB consistency / concurrency | Luna collect → Sol high reason/implement → Luna verify |
| Consequential architecture / security review | Optional Sol high review |
| Two distinct Sol failures on an extreme problem | Astra xhigh with `ESCALATION_REASON` |

## Architecture

```text
Natural-language coding task
        |
        v
Global AGENTS.md managed rule + smart-model-router skill
        |
        v
Deterministic phase classification (router.py)
        |
        +--> Luna explorer / verifier
        +--> Sol builder / diagnostician / expert
        `--> Astra escalation (gated)
        |
        v
Coordinator integrates, verifies, and reports
```

## User overrides

Explicit user instructions always take priority. Examples:

```text
这次只使用 Luna
不要使用 Astra
这个问题用 Sol
先别改代码
只分析不要执行
```

Destructive actions remain subject to the active Codex permission and confirmation policy.

## Verification

From the plugin package directory:

```powershell
cd .\plugins\smart-model-router
python -m unittest discover -s .\tests -v
python .\skills\smart-model-router\scripts\router.py simulate
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\test_installation.ps1
```

GitHub Actions runs the same Python test suite, PowerShell install/reinstall/uninstall tests, and router simulation on `windows-latest` for pushes and pull requests targeting `main`.

## Repository layout

```text
.
├─ .agents/plugins/marketplace.json
├─ .github/workflows/test.yml
├─ INSTALL.ps1
├─ STATUS.ps1
├─ UNINSTALL.ps1
├─ CHANGELOG.md
├─ RELEASE_NOTES_v0.1.0.md
└─ plugins/
   └─ smart-model-router/
      ├─ .codex-plugin/plugin.json
      ├─ codex-agents/
      ├─ scripts/
      ├─ skills/
      ├─ tests/
      ├─ LICENSE
      └─ THIRD_PARTY_NOTICES.md
```

## Current limitations

- A plugin does not change the model of an already-running main task; routing creates separate workers.
- Implicit skill selection is model-driven; the global managed rule strengthens activation but cannot override higher-priority product policy.
- Custom agent TOML profiles are currently installed separately because plugin packaging does not bundle them as a first-class component.
- Runtime model availability can vary by account/workspace policy.
- Quota-aware percentage routing is intentionally disabled because there is no reliable quota API used by this project.

## Version

Current plugin build: **`0.2.0`** (GPT-6.1 Sol-first release). The original v0.1.0 release remains available as historical reference.

See [CHANGELOG.md](./CHANGELOG.md) for the current changes and [RELEASE_NOTES_v0.1.0.md](./RELEASE_NOTES_v0.1.0.md) for the original release.

## License

MIT. See [`plugins/smart-model-router/LICENSE`](./plugins/smart-model-router/LICENSE).

Third-party notices are documented in [`THIRD_PARTY_NOTICES.md`](./plugins/smart-model-router/THIRD_PARTY_NOTICES.md).
