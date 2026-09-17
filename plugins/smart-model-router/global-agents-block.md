<!-- SMART-MODEL-ROUTER:BEGIN -->
## Smart Model Router

- For software-development tasks, use the globally installed `smart-model-router` skill automatically unless the user explicitly selects another routing policy.
- Keep the main task as coordinator and delegate bounded work with explicit worker models: Luna for mechanical exploration/verification, Terra for ordinary implementation, Sol for difficult architecture/production/concurrency reasoning, and Astra only after the skill's escalation gate or an explicit user request.
- Even when the active main task is Sol, route simple bounded work to Luna when subagents are available.
- User model/no-edit/no-Astra/analysis-only overrides take precedence. Never treat a tool, path, permission, dependency, fixture, or context failure as a model-capability failure.
- Show a concise `Routing:` summary and verify code changes before completion. Use runtime/session metadata, not worker self-report, when proving the model actually used.
<!-- SMART-MODEL-ROUTER:END -->
