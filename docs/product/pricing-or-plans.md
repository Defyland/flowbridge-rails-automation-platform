# Pricing or Plans

FlowBridge does not implement billing in the MVP. The domain still includes an organization `plan` field because rate limits, quotas, and operational support tiers are realistic product boundaries.

## Planned plan model

| Plan | Target user | Operational limit |
| --- | --- | --- |
| Launch | Small internal automation teams | Lower rate limit and manual support. |
| Growth | SaaS teams with customer-facing integrations | Higher webhook volume and longer execution retention. |
| Enterprise | Fintech or regulated teams | Dedicated retention, audit export, and deployment controls. |

## MVP behavior

- `Organization#plan` is metadata.
- Rate limiting uses `rate_limit_per_minute`.
- Billing, invoices, and entitlements are intentionally deferred.

## Why document plans now?

Plans influence future scalability and retention decisions. They should not leak into execution correctness, but they are useful when deciding benchmark budgets, storage retention, and operator workflows.
