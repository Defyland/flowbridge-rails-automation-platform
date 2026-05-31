import http from "k6/http";
import { check } from "k6";
import { hmac } from "k6/crypto";

export const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";
export const CONNECTOR_URL = __ENV.CONNECTOR_URL || `${BASE_URL}/up`;

export function setupFlowBridge() {
  const org = http.post(
    `${BASE_URL}/api/v1/organizations`,
    JSON.stringify({ organization: { name: `k6-${Date.now()}` } }),
    { headers: { "Content-Type": "application/json" } },
  );
  check(org, { "organization created": (res) => res.status === 201 });

  const token = org.json("api_key.token");
  const authHeaders = {
    Authorization: `Bearer ${token}`,
    "Content-Type": "application/json",
  };

  const workflow = http.post(
    `${BASE_URL}/api/v1/workflows`,
    JSON.stringify({ workflow: { name: "Benchmark Lead Intake" } }),
    { headers: authHeaders },
  );
  check(workflow, { "workflow created": (res) => res.status === 201 });

  const version = http.post(
    `${BASE_URL}/api/v1/workflows/${workflow.json("workflow.id")}/versions`,
    JSON.stringify({
      workflow_version: {
        retry_policy: { max_attempts: 2, base_delay_seconds: 0, jitter_seconds: 0 },
        graph: {
          nodes: [
            { key: "incoming_webhook", type: "webhook_trigger", config: {} },
            { key: "normalize", type: "transform", config: { mapping: { email: "$.email" } } },
            { key: "sync_crm", type: "http_request", config: { method: "GET", url: CONNECTOR_URL, timeout_seconds: 5 } },
          ],
        },
      },
    }),
    { headers: authHeaders },
  );
  check(version, { "workflow version published": (res) => res.status === 201 });

  return {
    triggerKey: version.json("workflow_version.trigger_key"),
    webhookSecret: version.json("webhook_secret"),
  };
}

export function sendWebhook(data) {
  const body = JSON.stringify({
    email: `buyer-${__VU}-${__ITER}-${Date.now()}@example.com`,
    plan: "scale",
  });
  const signature = `sha256=${hmac("sha256", data.webhookSecret, body, "hex")}`;

  const response = http.post(`${BASE_URL}/api/v1/webhooks/${data.triggerKey}`, body, {
    headers: {
      "Content-Type": "application/json",
      "X-FlowBridge-Event-Id": `evt-${__VU}-${__ITER}-${Date.now()}`,
      "X-FlowBridge-Signature": signature,
      "X-Correlation-Id": `bench-${__VU}-${__ITER}`,
    },
  });

  check(response, {
    "webhook accepted": (res) => res.status === 202,
    "execution id returned": (res) => Boolean(res.json("workflow_execution.id")),
  });
}
