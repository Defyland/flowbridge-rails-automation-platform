import http from "k6/http";
import { check } from "k6";
import { hmac } from "k6/crypto";

export const BASE_URL = __ENV.BASE_URL || "http://localhost:3000";
export const CONNECTOR_URL = __ENV.CONNECTOR_URL || `${BASE_URL}/up`;
const SETUP_TAGS = { stage: "setup" };
const INGRESS_TAGS = { stage: "ingress" };

function failWithResponse(label, response) {
  throw new Error(`${label} failed with status ${response.status}: ${response.body}`);
}

function expectStatus(response, status, label) {
  const ok = check(response, { [label]: (res) => res.status === status });
  if (!ok) {
    failWithResponse(label, response);
  }
}

function expectJsonValue(response, path, label) {
  const value = response.json(path);

  if (value === undefined || value === null || value === "") {
    throw new Error(`${label} missing in response body: ${response.body}`);
  }

  return value;
}

function postWebhook(data, body, tags, eventId, correlationId) {
  const signature = `sha256=${hmac("sha256", data.webhookSecret, body, "hex")}`;

  return http.post(`${BASE_URL}/api/v1/webhooks/${data.triggerKey}`, body, {
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-FlowBridge-Event-Id": eventId,
      "X-FlowBridge-Signature": signature,
      "X-Correlation-Id": correlationId,
    },
    tags,
  });
}

export function setupFlowBridge() {
  const seed = `${Date.now()}-${Math.random().toString(16).slice(2, 8)}`;
  const org = http.post(
    `${BASE_URL}/api/v1/organizations`,
    JSON.stringify({ organization: { name: `K6 ${seed}`, slug: `k6-${seed}` } }),
    { headers: { Accept: "application/json", "Content-Type": "application/json" }, tags: SETUP_TAGS },
  );
  expectStatus(org, 201, "organization created");

  const token = expectJsonValue(org, "api_key.token", "api_key.token");
  const authHeaders = {
    Authorization: `Bearer ${token}`,
    Accept: "application/json",
    "Content-Type": "application/json",
  };

  const workflow = http.post(
    `${BASE_URL}/api/v1/workflows`,
    JSON.stringify({ workflow: { name: "Benchmark Lead Intake" } }),
    { headers: authHeaders, tags: SETUP_TAGS },
  );
  expectStatus(workflow, 201, "workflow created");

  const version = http.post(
    `${BASE_URL}/api/v1/workflows/${expectJsonValue(workflow, "workflow.id", "workflow.id")}/versions`,
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
    { headers: authHeaders, tags: SETUP_TAGS },
  );
  expectStatus(version, 201, "workflow version published");

  const data = {
    triggerKey: expectJsonValue(version, "workflow_version.trigger_key", "workflow_version.trigger_key"),
    webhookSecret: expectJsonValue(version, "webhook_secret", "webhook_secret"),
  };

  const warmupBody = JSON.stringify({
    email: `warmup-${seed}@example.com`,
    plan: "scale",
  });
  const warmupResponse = postWebhook(data, warmupBody, SETUP_TAGS, `warmup-${seed}`, `warmup-${seed}`);

  expectStatus(warmupResponse, 202, "warmup webhook accepted");
  expectJsonValue(warmupResponse, "workflow_execution.id", "warmup workflow_execution.id");

  return data;
}

export function sendWebhook(data) {
  const body = JSON.stringify({
    email: `buyer-${__VU}-${__ITER}-${Date.now()}@example.com`,
    plan: "scale",
  });
  const response = postWebhook(
    data,
    body,
    INGRESS_TAGS,
    `evt-${__VU}-${__ITER}-${Date.now()}`,
    `bench-${__VU}-${__ITER}`,
  );

  check(response, {
    "webhook accepted": (res) => res.status === 202,
    "execution id returned": (res) => Boolean(res.json("workflow_execution.id")),
  });
}
