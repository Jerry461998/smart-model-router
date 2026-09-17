# Smart Model Router

`smart-model-router` is a personal Codex plugin and global configuration layer that routes bounded software-development phases to real model-specific subagents:

- GPT-5.6 Luna: fast exploration, mechanical work, and routine verification.
- GPT-5.6 Terra: normal implementation and medium-complex debugging.
- GPT-5.6 Sol: architecture, production, concurrency, transaction, security, and consistency reasoning.
- GPT-6 Astra: final escalation after two evidence-backed Sol attempts, or when the user explicitly requests Astra.

The active main task does not change models. The coordinator starts separate workers with explicit `model` and `reasoning_effort`, receives compact results, checks the actual diff/tests, and reports the actual worker route.

## Architecture

```text
Natural-language coding task
        |
        v
Global AGENTS.md managed rule + implicit smart-model-router skill
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

The plugin contains the skill and deterministic advisor. The installer also places six Codex custom-agent profiles under the user Codex directory and applies a small managed global instruction block. Native Codex collaboration tools perform the actual dispatch; the Python advisor never pretends to switch the current task model.

## Installation paths

Default Windows paths:

- Plugin source: `%USERPROFILE%\plugins\smart-model-router`
- Installed plugin cache: managed by `codex plugin add smart-model-router@personal`
- Custom agents: `%USERPROFILE%\.codex\agents\smart_router_*.toml`
- Global configuration: `%USERPROFILE%\.codex\config.toml`
- Global instructions: `%USERPROFILE%\.codex\AGENTS.md`
- State and backups: `%USERPROFILE%\.codex\smart-model-router`
- Personal marketplace: `%USERPROFILE%\.agents\plugins\marketplace.json`

## Install

Run from the package source:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

The installer is idempotent. It creates timestamped backups before each configuration write, preserves unrelated plugin/marketplace/config/AGENTS entries, and records owned agent-file hashes for safe uninstall. Start a new Codex task after installation so plugin and skill discovery reload.

## Enable and disable

Disable automatic routing while keeping the source, profiles, backups, and Terra default:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\smart-model-router\scripts\disable.ps1"
```

Re-enable it:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\smart-model-router\scripts\enable.ps1"
```

Both operations require a new Codex task to refresh discovery.

## Uninstall

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\smart-model-router\scripts\uninstall.ps1"
```

Uninstall removes only the plugin entry/source, managed global blocks, and unchanged owned agent profiles. It restores the pre-install root/agent settings recorded in install state. If an owned agent file was modified after installation, the uninstaller preserves it and reports the path. Timestamped backups remain under `%USERPROFILE%\.codex\smart-model-router\backups` for recovery.

## Routing table

| Work | Default route |
|---|---|
| Text/CSS change, search, deterministic bulk edit | Luna low |
| Ordinary CRUD or website feature | Luna low explore → Terra medium implement → Luna medium verify |
| Medium integration/debugging | Luna collect → Terra high diagnose/build → Luna verify |
| Production-only or cross-service incident | Luna collect → Terra initial diagnosis → conditional Sol high |
| Architecture, CI/CD safety, database consistency, concurrency | Luna collect → Sol high reason → Terra implement → Luna verify |
| Consequential architecture/security review | Optional Sol high review |
| Two distinct Sol failures on an extreme problem | Astra xhigh with `ESCALATION_REASON` |

## Reasoning effort

- Luna: low for exploration/mechanical work; medium for verification; high only for unusually demanding bounded validation.
- Terra: medium for normal development; high for integration/debugging.
- Sol: high for expert reasoning; xhigh only when evidence justifies a deeper Sol pass.
- Astra: xhigh for the gated final escalation. Ultra is never selected automatically by this package.

## User overrides

Explicit user instructions have priority. Examples:

- `这次只使用 Luna`
- `不要使用 Astra`
- `这个问题用 Sol`
- `先别改代码`
- `只分析不要执行`

The router applies overrides to every phase. Destructive operations remain subject to the active Codex permission and confirmation policy.

## Context hygiene

Workers receive bounded prompts with goal, relevant files, known facts, constraints, expected result, and execution permissions. Raw searches, long logs, directory listings, and temporary investigation stay in worker tasks. The coordinator retains only decisions, compact findings, changed files, verification results, and unresolved issues.

## Verification

Every code change requires proportionate checks. Routine verification is independent Luna work. Terra investigates moderately complex test failures. Sol reviews only consequential architecture, security, production, migration, or consistency changes. A tool/path/dependency/permission failure does not trigger model escalation.

Run the deterministic suite:

```powershell
python -m unittest discover -s .\tests -v
```

Run the standard E2E route simulation:

```powershell
python .\skills\smart-model-router\scripts\router.py simulate
```

## Status and actual model evidence

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\plugins\smart-model-router\scripts\status.ps1"
```

Codex surfaces subagent cards/tasks in supported clients. For exact audit proof, inspect the child rollout/session metadata: the model and effort fields are authoritative. A worker's prose about its own model is not proof and can be inaccurate.

## Default root model

The installer sets the personal default root to `gpt-5.6-terra` with `medium` reasoning. This is the recommended long-term normal setting. A root task already started with Sol remains Sol, but the global rule still instructs it to dispatch simple bounded phases to Luna.

## Windows notes

- Tested against Codex CLI `0.153.4`, Codex desktop `26.901.6511.0`, Windows NT `10.0.26200.0`, and PowerShell `7.6.5`.
- Use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...` for installer scripts.
- The installer uses literal resolved paths and never calls the Unix-only `codex app-server daemon` lifecycle.
- Newly installed or updated plugins and skills are loaded in a new Codex task/session.

## Current Codex limitations

- A skill or plugin does not change the model of an already-running main task. Routing creates separate model-specific workers.
- Implicit skill selection is model-driven. The global `AGENTS.md` managed rule strengthens automatic activation, but a user's explicit instruction or higher-priority product policy can override it.
- Plugin packaging does not currently bundle personal custom-agent TOML profiles as a first-class plugin component, so the installer manages those profiles separately.
- There is no reliable percentage-based Plus quota API used by this package. `quota-aware-routing` remains disabled; routing is capability- and evidence-based.
- Runtime availability can change with account/workspace policy. `codex debug models` and a real child-session probe are the reliable local checks.

## Updating

Update the source package, bump the plugin version, run its tests and validators, then rerun `install.ps1`. The installer refreshes owned files and calls `codex plugin add smart-model-router@personal`. Start a new task after updating.

## Troubleshooting

- Plugin missing: run `codex plugin list` and confirm `smart-model-router@personal` is installed and enabled.
- Skill not visible in an existing task: start a new task.
- Worker uses the parent model: make sure the dispatch supplied explicit `model` and `reasoning_effort`, and inspect session metadata.
- Astra not selected: confirm the user did not forbid it and that two distinct Sol failures plus `ESCALATION_REASON` were supplied.
- Installation state issue: inspect `%USERPROFILE%\.codex\smart-model-router\install-state.json` and the timestamped backups.

## Open-source references

The design considered `orange-the-weak/codex-auto-model-router` and `capitalparser/codex-model-router`, both MIT-licensed. This implementation borrows architectural ideas such as deterministic classification, bounded worker prompts, fail-open handling, evidence-gated escalation, and actual-execution reporting. It is an original implementation adapted for a global Windows installation, Terra Medium root default, explicit Astra gate, this machine's current Codex schema, and the requested routing cases. See `THIRD_PARTY_NOTICES.md`.
