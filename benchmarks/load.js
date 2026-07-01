import { setupFlowBridge, sendWebhook } from "./lib/flowbridge.js";

export const options = {
  stages: [
    { duration: "30s", target: 10 },
    { duration: "1m", target: 10 },
    { duration: "15s", target: 0 },
  ],
  thresholds: {
    "http_req_failed{stage:ingress}": ["rate<0.01"],
    "http_req_duration{stage:ingress}": ["p(95)<500", "p(99)<900"],
  },
};

export function setup() {
  return setupFlowBridge();
}

export default function (data) {
  sendWebhook(data);
}
