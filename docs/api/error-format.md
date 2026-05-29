# API Error Format

All API errors use the same envelope:

```json
{
  "error": {
    "code": "validation_failed",
    "message": "Name can't be blank",
    "details": {},
    "request_id": "88c95fbd-8a3c-4e9a-9c3d-7d74c56b8b73",
    "correlation_id": "corr-user-supplied"
  }
}
```

## Common codes

- `unauthorized`: missing, invalid, or revoked API key.
- `forbidden`: API key role does not allow the action.
- `not_found`: resource does not exist in the current tenant boundary.
- `validation_failed`: model or request validation failed.
- `invalid_webhook_signature`: webhook HMAC verification failed.
- `invalid_json`: webhook body was not valid JSON.
- `rate_limited`: API key exceeded the tenant rate limit.
- `conflict`: current resource state does not allow the requested action.
