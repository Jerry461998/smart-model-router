# Changelog

All notable changes to Smart Model Router are documented here.

## [0.2.0] - 2026-09-30

- Make GPT-6.1 Sol the default root and every default Sol phase/profile; retain stable Sol profile IDs and raise policy version to 2.1.0.
- Add low effort for bounded behavioral fixes and xhigh for a serious retry after one evidence-backed complex Sol failure, preserving conditional phases and analysis-only constraints.
- Preserve Astra's two distinct evidence-backed attempts, explicit reason, high-consequence gate, and explicit user bypass; require coordinator evidence checks and prefer the serious Sol retry before automatic escalation.
- Recognize GPT-6.1 Sol identifiers, generic Sol, and Chinese 6.1sol overrides; preserve explicit older GPT-6 Sol requests and display full model names correctly.
- Document transparent same-effort GPT-6 Sol fallback only when GPT-6.1 Sol is unavailable and user constraints permit it. Treat runtime availability as infrastructure.
- Preserve installer ownership/hash protections and original settings, allow empty backup text, and propagate child failures through root PowerShell wrappers.
- Extend routing and isolated install/reinstall/uninstall regressions, including empty/new configuration and wrapper exit codes; run PowerShell installation tests in CI.
- Update active English/Chinese documentation with the official GPT-6.1 Sol model source; preserve historical release notes and notices.

## [0.1.0+codex.20260923020300] - 2026-09-23

### GPT-6 routing update

- Route all active root and worker phases through GPT-6 Luna, Sol, and gated Astra.
- Set GPT-6 Sol Medium as the default root and GPT-6 Luna as the default subagent.
- Replace Terra-named worker profiles with Sol builder and diagnostician profiles; safely remove unchanged legacy profiles during upgrade.
- Keep Luna for mechanical exploration and independent verification, Sol Medium for ordinary implementation, Sol High for complex reasoning, and Astra for evidence-gated escalation.
- Update policy, documentation, installer status, and 17 deterministic routing tests.
- Preserve v0.1.0 release notes as historical documentation.

## [0.1.0] - 2026-09-17

### Added

- Initial public release of Smart Model Router.
- Codex plugin manifest and marketplace metadata.
- Deterministic routing policy for Luna, Terra, Sol and gated Astra workers.
- Six custom Codex worker profiles.
- Global routing rule management for `AGENTS.md`.
- Idempotent Windows installer with timestamped backups.
- Enable, disable, status and uninstall scripts.
- Router simulation and deterministic unit tests.
- Public GitHub quick-start installation flow.

### Safety and behavior

- Main tasks do not silently switch models.
- Worker model and reasoning effort are explicit at dispatch time.
- Astra escalation is gated by evidence or explicit user instruction.
- Uninstall preserves owned files that were modified after installation.
