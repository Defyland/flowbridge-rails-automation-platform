require_relative "lib/flowbridge_serverless_ingress"

def handler(event:, context:)
  FlowBridgeServerlessIngress.handle(event: event, context: context)
end
