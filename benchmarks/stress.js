import { setupFlowBridge, sendWebhook } from "./lib/flowbridge.js";

export const options = {
  stages: [
    { duration: "30s", target: 10 },
    { duration: "30s", target: 25 },
    { duration: "30s", target: 50 },
    { duration: "30s", target: 0 },
  ],
  thresholds: {
    "http_req_failed{stage:ingress}": ["rate<0.05"],
    "http_req_duration{stage:ingress}": ["p(95)<1000", "p(99)<1500"],
  },
};

export function setup() {
  return setupFlowBridge();
}

export default function (data) {
  sendWebhook(data);
}
