# Authorization Matrix

| Capability | Owner | Operator | Viewer |
| --- | --- | --- | --- |
| Read organization | Yes | Yes | Yes |
| Create workflow | Yes | No | No |
| Read workflows | Yes | Yes | Yes |
| Publish workflow version | Yes | No | No |
| Create credentials | Yes | No | No |
| Read credential metadata | Yes | Yes | No |
| Read executions | Yes | Yes | Yes |
| Retry executions | Yes | Yes | No |
| Read dead letters | Yes | Yes | Yes |
| Retry dead letters | Yes | Yes | No |
| Resolve dead letters | Yes | Yes | No |

Roles are enforced by `ApiKey::ROLE_PERMISSIONS` and controller-level `require_permission!` calls. Tenant isolation is enforced by querying through `Current.organization` for tenant-owned resources.
