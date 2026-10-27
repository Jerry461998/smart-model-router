<!-- SMART-MODEL-ROUTER:BEGIN -->
## Smart Model Router

- For software-development tasks, use the globally installed `smart-model-router` skill automatically unless the user explicitly selects another routing policy.
- Keep the main task as coordinator and delegate bounded work with explicit worker models: GPT-6 Luna low for mechanical exploration/edits and medium for routine verification, GPT-6.1 Terra medium for clearly bounded local fixes, visual/screenshot/UI acceptance and defined computer-use verification, GPT-6.1 Sol medium for ordinary implementation, high for difficult architecture/production/concurrency reasoning, xhigh for evidence-backed serious retry, and Astra only after the skill's escalation gate or an explicit user request.
- Generic Sol means GPT-6.1 Sol. If unavailable, report the limitation before using GPT-6 Sol at the same effort when compatible with user overrides; availability failures never count toward Astra escalation.
- Production/security/architecture/migration/transaction/concurrency reasoning takes Sol precedence over screenshot/UI keywords. Terra visual review is read-only unless mutable paths are explicitly assigned.
- Explicit Terra/6.1 Terra/gpt-6.1-terra and Chinese Terra requests preserve only/analyze-only/no-edit constraints. If Terra is unavailable, disclose before compatible available Sol medium fallback; Terra-only forbids substitution. Availability is never escalation evidence.
- Even when the active main task is Sol, route simple bounded work to GPT-6 Luna when subagents are available.
- User model/no-edit/no-Astra/analysis-only overrides take precedence. Never treat a tool, path, permission, dependency, fixture, or context failure as a model-capability failure.
- Show a concise `Routing:` summary and verify code changes before completion. Use runtime/session metadata, not worker self-report, when proving the model actually used.
<!-- SMART-MODEL-ROUTER:END -->
