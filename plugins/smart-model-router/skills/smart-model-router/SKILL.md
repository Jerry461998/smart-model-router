---
name: smart-model-router
description: Automatically route Codex software-development work across GPT-6 Luna, GPT-6.1 Sol, and evidence-gated Astra subagents. Use for implementation, debugging, architecture, repository exploration, refactoring, deployment, database, testing, or verification tasks where choosing bounded workers by difficulty avoids manual model selection. Do not use for ordinary conversation or non-development questions.
---

# Smart Model Router

Keep the main task as coordinator. Route bounded software work to real model-specific subagents; never describe a recommendation as an executed worker.

## First decision

Honor explicit user overrides before this policy. “Only use Luna”, “do not use Astra”, “use Sol”, “analyze only”, and “do not edit” constrain every worker and phase. Generic “Sol” means `gpt-6.1-sol`; explicit `gpt-6.1-sol`, “6.1 Sol”, and Chinese “6.1sol” requests select it too. An explicit `gpt-6-sol` request retains that older Sol model. Preserve every other user constraint.

For a non-trivial or ambiguous request, run:

```powershell
python "$env:USERPROFILE\plugins\smart-model-router\skills\smart-model-router\scripts\router.py" route --text "<task>"
```

If Python is not on PATH, locate a configured Codex bundled Python runtime. For a tiny obvious task, classify directly from the table below.

## Routing policy

| Work | Route |
|---|---|
| Mechanical search, text/CSS change, bulk deterministic edit | GPT-6 Luna low; verify with Luna when behavior can regress |
| Clearly bounded nonmechanical local fix | GPT-6.1 Sol low → Luna medium verification |
| Ordinary feature or CRUD | GPT-6 Luna low exploration → GPT-6.1 Sol medium implementation → GPT-6 Luna medium verification |
| Medium debugging or integration | Luna collect → Sol medium diagnosis/implementation → Luna verify; raise Sol effort to high when evidence requires it |
| Production-only, cross-service, architecture, security, migration, transaction, or concurrency reasoning | Luna collect → Sol high reasoning/implementation → Luna verification; Sol review only when consequential |
| Complex Sol reasoning remains unresolved after one evidence-backed attempt | GPT-6.1 Sol xhigh serious retry; preserve conditional phases and analysis-only scope |
| Sol remains blocked after two distinct evidence-backed reasoning attempts on a high-consequence problem | Astra xhigh, with `ESCALATION_REASON` |

Never escalate because a path is wrong, a command is malformed, a package is missing, a tool is unavailable, a fixture is absent, permissions fail, or the worker lacks context. Fix the infrastructure/input problem at the same model tier.

## Sol availability and effort

The default root and all default Sol phases use `gpt-6.1-sol`, root effort `medium`. Use `low` for a clearly bounded nonmechanical fix, `medium` for ordinary development/debugging, `high` for complex reasoning, and `xhigh` for an evidence-backed serious retry. Do not select `none` or `minimal`. See the [official GPT-6.1 Sol model documentation](https://developers.openai.com/api/docs/models/gpt-6.1-sol).

Use available runtime/session metadata or an actual dispatch result to check availability. If GPT-6.1 Sol is absent, report that limitation and transparently use `gpt-6-sol` at the same requested effort when available and compatible with user overrides. Never silently substitute a model or advance to Astra because a runtime model is unavailable. If the user requires only GPT-6.1 Sol, report the blocker instead. No CLI catalog detection or external model API is required by this policy.

## Dispatch contract

Use Codex native subagents with explicit `model` and `reasoning_effort`. Use `fork_turns="none"` or the smallest recent-turn fork that contains necessary context. Do not send full chat history, raw repository listings, long logs, or unrelated files.

Keep stable profile IDs `smart_router_sol_builder`, `smart_router_sol_diagnostician`, and `smart_router_sol_expert`; their defaults are GPT-6.1 Sol medium/high/high. Some native profile roles lock model and effort. When the phase needs low/xhigh or an explicit older Sol/fallback, use the native default worker with explicit model and effort rather than a role whose locked settings differ. The router's `worker` field identifies the responsibility; it does not override runtime role settings.

Each worker prompt must contain only:

- `GOAL`
- `RELEVANT_FILES`
- `KNOWN_FACTS`
- `CONSTRAINTS`
- `EXPECTED_OUTPUT`
- `CAN_MODIFY_FILES`
- `CAN_RUN_COMMANDS`

Use these result shapes:

- Exploration: `TASK_RESULT`, status, files, findings, risks, recommended_next_step, needs_escalation, escalation_reason.
- Implementation: `TASK_RESULT`, status, changed_files, implementation, tests_added, known_risks, needs_review.
- Verification: `TASK_RESULT`, status, tests_run, passed, failed, regressions, remaining_risks.
- Expert: `TASK_RESULT`, status, root_cause, evidence, recommendation, risk, implementation_guidance, needs_astra, astra_reason.

Run write-dependent phases serially. Parallelize only independent read-heavy work or disjoint writes with explicit paths. The coordinator owns integration, diff inspection, and the final answer.

## Astra gate

Automatic Astra dispatch requires all of the following:

1. Sol completed two distinct serious reasoning attempts.
2. Each attempt returned concrete evidence and a different tested hypothesis.
3. The unresolved issue is architecture-level, cross-system, concurrency/consistency-critical, or similarly high consequence.
4. `ESCALATION_REASON` states why Sol evidence is insufficient.

After the first completed evidence-backed complex Sol reasoning failure, prefer a GPT-6.1 Sol xhigh serious retry before automatic Astra. `--sol-failures=1` raises appropriate complex Sol phases to xhigh while preserving their modes and user scope. `--sol-failures` counts distinct completed reasoning attempts with evidence and different tested hypotheses, never infrastructure failures. The advisor accepts the coordinator's attestation; it cannot inspect or prove those attempts from a numeric flag. The coordinator must check the full gate before dispatch.

An explicit user request for Astra bypasses the two-attempt count but not the user’s other scope or execution constraints. If the user forbids Astra, never select it.

## Observability

Before dispatch, show only a compact summary such as:

```text
Routing:
- Explore → Luna low
- Implement → GPT-6.1 Sol medium
- Verify → Luna medium
```

For escalation:

```text
Escalation:
- GPT-6.1 Sol high → GPT-6.1 Sol xhigh
- Reason: production-only cross-worker session inconsistency
```

Do not reveal hidden reasoning. At completion, distinguish planned routes, actual worker models, tests, and unresolved limits. Treat runtime/session metadata as the source of truth for actual model and effort; worker self-reports are advisory only.

## Verification

All code changes require proportionate verification. Independent verification should use Luna for ordinary work and Sol for demanding test investigation or consequential architecture/security/consistency review. Do not claim completion after edits alone.

Read [routing policy](references/routing-policy.md) for detailed cases and [worker protocol](references/worker-protocol.md) when composing or reviewing bounded worker prompts.
