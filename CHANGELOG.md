# Changelog

All notable changes to Smart Model Router are documented here.

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
