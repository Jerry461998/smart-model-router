# Smart Model Router

[![Version](https://img.shields.io/badge/version-v0.1.0-blue)](https://github.com/Jerry461998/smart-model-router/releases/tag/v0.1.0)
[![CI](https://github.com/Jerry461998/smart-model-router/actions/workflows/test.yml/badge.svg)](https://github.com/Jerry461998/smart-model-router/actions/workflows/test.yml)
[![License](https://img.shields.io/badge/license-MIT-green)](./plugins/smart-model-router/LICENSE)
[![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)](#requirements)

Smart Model Router is a Codex plugin and global routing layer for people who want **different models to handle different parts of a coding task** instead of running everything through the most expensive model.

It keeps the main Codex task as the coordinator, classifies bounded phases, launches model-specific workers with explicit `model` and `reasoning_effort`, verifies their output, and only escalates when the evidence justifies it.

## What it does

| Phase | Typical worker | Purpose |
|---|---|---|
| Exploration / search / mechanical edits | GPT-5.6 Luna | Fast, low-cost discovery and routine work |
| Normal implementation / medium debugging | GPT-5.6 Terra | Main coding and integration work |
| Architecture / production / security / consistency | GPT-5.6 Sol | High-reasoning expert analysis |
| Final escalation | GPT-6 Astra | Gated fallback after evidence-backed Sol attempts or explicit user request |

The router does **not** pretend to switch the model of an already-running main task. It dispatches separate subagents and reports the actual route used.

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

Tested against Codex CLI `0.153.4`, Codex desktop `26.901.6511.0`, Windows NT `10.0.26200.0`, and PowerShell `7.6.5`.

## What the installer changes

The installer is idempotent and creates timestamped backups before configuration writes. It manages:

- plugin source under `%USERPROFILE%\plugins\smart-model-router`
- personal marketplace registration
- six Codex custom-agent profiles under `%USERPROFILE%\.codex\agents`
- a managed global routing block in `%USERPROFILE%\.codex\AGENTS.md`
- root Codex defaults in `%USERPROFILE%\.codex\config.toml`
- install state and backups under `%USERPROFILE%\.codex\smart-model-router`

The default root model is set to `gpt-5.6-terra` with `medium` reasoning. Uninstall restores the pre-install root/agent settings recorded in install state and preserves owned files that were modified after installation.

## Routing overview

| Work | Default route |
|---|---|
| Text/CSS, search, deterministic bulk edit | Luna low |
| Ordinary CRUD / website feature | Luna explore → Terra implement → Luna verify |
| Medium integration / debugging | Luna collect → Terra high diagnose/build → Luna verify |
| Production-only / cross-service incident | Luna collect → Terra initial diagnosis → conditional Sol high |
| Architecture / CI-CD / DB consistency / concurrency | Luna collect → Sol high reason → Terra implement → Luna verify |
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
        +--> Terra builder / diagnostician
        +--> Sol expert
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
```

GitHub Actions runs the same Python test suite and router simulation on `windows-latest` for pushes and pull requests targeting `main`.

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

Current plugin version: **v0.1.0**.

See [CHANGELOG.md](./CHANGELOG.md) and [RELEASE_NOTES_v0.1.0.md](./RELEASE_NOTES_v0.1.0.md).

## License

MIT. See [`plugins/smart-model-router/LICENSE`](./plugins/smart-model-router/LICENSE).

Third-party notices are documented in [`THIRD_PARTY_NOTICES.md`](./plugins/smart-model-router/THIRD_PARTY_NOTICES.md).
