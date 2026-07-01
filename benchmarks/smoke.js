import { setupFlowBridge, sendWebhook } from "./lib/flowbridge.js";

export const options = {
  vus: 1,
  iterations: 5,
  thresholds: {
    "http_req_failed{stage:ingress}": ["rate<0.01"],
    "http_req_duration{stage:ingress}": ["p(95)<500"],
  },
};

export function setup() {
  return setupFlowBridge();
}

export default function (data) {
  sendWebhook(data);
}
