# HTTP Examples

## Create organization

```bash
curl -s http://localhost:3000/api/v1/organizations \
  -H "Content-Type: application/json" \
  -d '{"organization":{"name":"Demo Ops"}}'
```

The response includes a one-time `api_key.token`. Store it as an environment variable:

```bash
export FLOWBRIDGE_TOKEN="fbk_returned_once"
```

## Create workflow

```bash
curl -s http://localhost:3000/api/v1/workflows \
  -H "Authorization: Bearer $FLOWBRIDGE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"workflow":{"name":"Lead Intake","description":"Sync leads into CRM"}}'
```

## Publish workflow version

```bash
curl -s http://localhost:3000/api/v1/workflows/1/versions \
  -H "Authorization: Bearer $FLOWBRIDGE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "workflow_version": {
      "retry_policy": { "max_attempts": 3, "base_delay_seconds": 30, "jitter_seconds": 10 },
      "graph": {
        "nodes": [
          { "key": "incoming_webhook", "type": "webhook_trigger", "config": {} },
          { "key": "normalize", "type": "transform", "config": { "mapping": { "email": "$.email" } } },
          { "key": "sync_crm", "type": "http_request", "config": { "method": "POST", "url": "https://crm.internal.example/contacts", "timeout_seconds": 5 } }
        ]
      }
    }
  }'
```

The response returns `trigger_key` and `webhook_secret`. The secret is only returned at publication time.

## Send signed webhook

```bash
BODY='{"email":"buyer@example.com","plan":"scale"}'
SIGNATURE="sha256=$(printf "%s" "$BODY" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -binary | xxd -p -c 256)"

curl -s "http://localhost:3000/api/v1/webhooks/$TRIGGER_KEY" \
  -H "Content-Type: application/json" \
  -H "X-FlowBridge-Event-Id: evt-123" \
  -H "X-FlowBridge-Signature: $SIGNATURE" \
  -H "X-Correlation-Id: corr-evt-123" \
  -d "$BODY"
```

## Send serverless normalized webhook envelope

The serverless edge signs a normalized envelope instead of the provider payload directly:

```bash
SOURCE_BODY='{"id":"evt-edge-123","email":"buyer@example.com"}'
RAW_SHA="$(printf "%s" "$SOURCE_BODY" | openssl dgst -sha256 -binary | xxd -p -c 256)"
ENVELOPE="$(jq -nc \
  --arg sha "$RAW_SHA" \
  --argjson payload "$SOURCE_BODY" \
  '{
    schema_version: 1,
    source: "stripe",
    external_event_id: "evt-edge-123",
    received_at: "2026-07-07T15:20:00Z",
    raw_body_sha256: $sha,
    correlation_id: "corr-edge-123",
    headers: { "stripe-signature": "t=1,v1=masked-by-rails" },
    payload: $payload
  }')"
SERVERLESS_SIGNATURE="sha256=$(printf "%s" "$ENVELOPE" | openssl dgst -sha256 -hmac "$FLOWBRIDGE_SERVERLESS_INGRESS_SECRET" -binary | xxd -p -c 256)"

curl -s "http://localhost:3000/api/v1/serverless/webhooks/$TRIGGER_KEY" \
  -H "Content-Type: application/json" \
  -H "X-FlowBridge-Serverless-Signature: $SERVERLESS_SIGNATURE" \
  -H "X-Correlation-Id: corr-edge-123" \
  -d "$ENVELOPE"
```

## Inspect execution

```bash
curl -s http://localhost:3000/api/v1/executions/1 \
  -H "Authorization: Bearer $FLOWBRIDGE_TOKEN"
```

## Retry dead letter

```bash
curl -s -X POST http://localhost:3000/api/v1/dead_letters/1/retry \
  -H "Authorization: Bearer $FLOWBRIDGE_TOKEN"
```
