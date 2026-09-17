# Smart Model Router v0.1.0

First public release of Smart Model Router for Codex on Windows.

## Highlights

- Routes bounded software-development phases across GPT-5.6 Luna, GPT-5.6 Terra, GPT-5.6 Sol and gated GPT-6 Astra workers.
- Uses explicit worker model and reasoning-effort settings rather than pretending to switch the active main-task model.
- Includes six model-specific Codex agent profiles.
- Adds deterministic routing logic, verification flow and evidence-gated escalation.
- Ships with Windows install, status and uninstall entry points.
- Creates timestamped backups before modifying global Codex configuration.
- Includes deterministic tests and route simulation.

## Install

```powershell
git clone https://github.com/Jerry461998/smart-model-router.git
cd smart-model-router
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\INSTALL.ps1
```

Start a new Codex task after installation.

## Check status

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\STATUS.ps1
```

## Uninstall

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\UNINSTALL.ps1
```

## Notes

- Default root model: `gpt-5.6-terra` with `medium` reasoning.
- Runtime model availability depends on account/workspace policy.
- Astra is not selected automatically unless the configured escalation gate is satisfied.
- MIT licensed.
