---
name: smart-model-router
description: Automatically route Codex software-development work across GPT-6 Luna, Sol, and evidence-gated Astra subagents. Use for implementation, debugging, architecture, repository exploration, refactoring, deployment, database, testing, or verification tasks where choosing bounded workers by difficulty avoids manual model selection. Do not use for ordinary conversation or non-development questions.
---

# Smart Model Router

Keep the main task as coordinator. Route bounded software work to real model-specific subagents; never describe a recommendation as an executed worker.

## First decision

Honor explicit user overrides before this policy. “Only use Luna”, “do not use Astra”, “use Sol”, “analyze only”, and “do not edit” constrain every worker and phase. This installation selects GPT-6 models only; a request for an older family requires an explicit policy change.

For a non-trivial or ambiguous request, run:

```powershell
python "$env:USERPROFILE\plugins\smart-model-router\skills\smart-model-router\scripts\router.py" route --text "<task>"
```

If Python is not on PATH, locate a configured Codex bundled Python runtime. For a tiny obvious task, classify directly from the table below.

## Routing policy

| Work | Route |
|---|---|
| Mechanical search, text/CSS change, bulk deterministic edit | GPT-6 Luna low; verify with Luna when behavior can regress |
| Ordinary feature or CRUD | GPT-6 Luna low exploration → GPT-6 Sol medium implementation → GPT-6 Luna medium verification |
| Medium debugging or integration | Luna collect → Sol medium diagnosis/implementation → Luna verify; raise Sol effort to high when evidence requires it |
| Production-only, cross-service, architecture, security, migration, transaction, or concurrency reasoning | Luna collect → Sol high reasoning/implementation → Luna verification; Sol review only when consequential |
| Sol remains blocked after two distinct evidence-backed reasoning attempts | Astra xhigh, with `ESCALATION_REASON` |

Never escalate because a path is wrong, a command is malformed, a package is missing, a tool is unavailable, a fixture is absent, permissions fail, or the worker lacks context. Fix the infrastructure/input problem at the same model tier.

## Dispatch contract

Use Codex native subagents with explicit `model` and `reasoning_effort`. Use `fork_turns="none"` or the smallest recent-turn fork that contains necessary context. Do not send full chat history, raw repository listings, long logs, or unrelated files.

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

An explicit user request for Astra bypasses the two-attempt count but not the user’s other scope or execution constraints. If the user forbids Astra, never select it.

## Observability

Before dispatch, show only a compact summary such as:

```text
Routing:
- Explore → Luna low
- Implement → Sol medium
- Verify → Luna medium
```

For escalation:

```text
Escalation:
- Sol medium → Sol high
- Reason: production-only cross-worker session inconsistency
```

Do not reveal hidden reasoning. At completion, distinguish planned routes, actual worker models, tests, and unresolved limits. Treat runtime/session metadata as the source of truth for actual model and effort; worker self-reports are advisory only.

## Verification

All code changes require proportionate verification. Independent verification should use Luna for ordinary work and Sol for demanding test investigation or consequential architecture/security/consistency review. Do not claim completion after edits alone.

Read [routing policy](references/routing-policy.md) for detailed cases and [worker protocol](references/worker-protocol.md) when composing or reviewing bounded worker prompts.
