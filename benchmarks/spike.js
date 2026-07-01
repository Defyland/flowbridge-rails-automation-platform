import { setupFlowBridge, sendWebhook } from "./lib/flowbridge.js";

export const options = {
  stages: [
    { duration: "10s", target: 5 },
    { duration: "10s", target: 60 },
    { duration: "20s", target: 60 },
    { duration: "10s", target: 0 },
  ],
  thresholds: {
    "http_req_failed{stage:ingress}": ["rate<0.05"],
    "http_req_duration{stage:ingress}": ["p(95)<1200", "p(99)<1800"],
  },
};

export function setup() {
  return setupFlowBridge();
}

export default function (data) {
  sendWebhook(data);
}
