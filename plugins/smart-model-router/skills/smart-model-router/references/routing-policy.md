# Routing Policy

## Principles

- The active main-task model is fixed for that task. Routing means starting a separate Codex subagent with an explicit model and effort.
- Prefer the smallest capable worker, but do not split work when the startup and handoff cost exceeds the useful boundary.
- The user’s explicit model, no-edit, no-Astra, analysis-only, and scope instructions always win.
- File count, log size, or a single command failure is not evidence of reasoning difficulty.
- Quota-aware routing is reserved and disabled because this package has no reliable percentage/quota API.

## Model roles

### GPT-5.6 Luna

Use low or medium for repository search, file discovery, mechanical edits, deterministic transformations, syntax checks, ordinary tests, lint, fixture inspection, and independent verification of routine features. Use high only when a bounded validation task genuinely needs more care.

### GPT-5.6 Terra

Use medium for normal product development, CRUD, ordinary backend/frontend integration, refactors, API work, and typical debugging. Use high for medium-complex integration or diagnosis. Terra is the recommended main-task default.

### GPT-5.6 Sol

Use high for architecture, production incidents, cross-service behavior, reverse-proxy/deployment design, difficult PostgreSQL semantics, concurrency, transactions, data/session/cache consistency, authentication/authorization architecture, high-risk migrations, and evidence-backed issues that remain after a reasonable Terra attempt. Give Sol condensed evidence rather than mechanical exploration.

### GPT-6 Astra

Use xhigh only when the user explicitly requests Astra or two distinct Sol attempts with evidence remain insufficient for a very high-complexity/high-consequence problem. The coordinator must emit `ESCALATION_REASON` before dispatch.

## Common routes

| Scenario | Required route |
|---|---|
| Change a button label | Luna low |
| Add an ordinary Django CRUD page | Luna explore → Terra medium build → Luna verify |
| Search all deployment files | Luna low |
| Intermittent production Docker+Caddy 502 | Luna collect → Terra high initial diagnosis → conditional Sol high |
| Redesign CI/CD with rollback and migration safety | Luna collect → Sol high architecture → Terra high implementation → Luna verify → conditional Sol review |
| Cross-service consistency bug after two failed Sol hypotheses | Astra xhigh with explicit reason |
| Replace years in 1000 files | Luna low |
| Small but complex race condition | Luna collect → Sol high reason → Terra implement → Luna verify |
| Change CSS margin | Luna low |
| Ordinary Django login-record management page | Luna explore → Terra medium implement → Luna verify |

## Failure classification

Infrastructure failures include missing executables, bad paths, permissions, locks, missing fixtures, malformed commands, dependency absence, timeouts without evidence of a stall, and insufficient context. Correct the cause without model escalation.

Reasoning failures include contradictory evidence after a tested hypothesis, unresolved transaction semantics, cross-worker state inconsistency, production/local divergence after environment evidence is complete, or a high-consequence architecture ambiguity. These may justify Terra→Sol or Sol→Astra.
