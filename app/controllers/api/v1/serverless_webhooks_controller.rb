module Api
  module V1
    class ServerlessWebhooksController < Api::BaseController
      skip_before_action :authenticate_api_key!
      skip_before_action :enforce_rate_limit!

      def create
        raw_envelope = request.raw_post
        return render_error(:service_unavailable, "serverless_ingress_not_configured", "serverless ingress secret is not configured") if serverless_ingress_secret.blank?

        unless FlowBridge::SignatureVerifier.valid?(
          secret: serverless_ingress_secret,
          payload: raw_envelope,
          header: request.headers["X-FlowBridge-Serverless-Signature"]
        )
          return render_error(:unauthorized, "invalid_serverless_signature", "serverless ingress signature did not match")
        end

        envelope = FlowBridge::ServerlessWebhookEnvelope.parse_json!(raw_envelope)
        workflow_version = WorkflowVersion.find_by!(trigger_key: params[:trigger_key])
        Current.organization = workflow_version.organization
        Current.correlation_id = envelope.correlation_id.presence || Current.correlation_id

        result = FlowBridge::WebhookIngestor.call(
          workflow_version: workflow_version,
          payload: envelope.payload,
          headers: envelope.flowbridge_headers,
          idempotency_key: envelope.idempotency_key,
          correlation_id: Current.correlation_id
        )

        render status: :accepted, json: {
          serverless_ingestion: {
            source: envelope.source,
            external_event_id: envelope.external_event_id,
            idempotency_key: envelope.idempotency_key,
            correlation_id: Current.correlation_id
          },
          webhook_event: result.event.to_public_hash,
          workflow_execution: result.execution&.to_public_hash,
          duplicate: result.duplicate
        }
      rescue FlowBridge::ServerlessWebhookEnvelope::InvalidEnvelope => error
        render_error(:bad_request, "invalid_serverless_envelope", error.message)
      end

      private

      def serverless_ingress_secret
        ENV["FLOWBRIDGE_SERVERLESS_INGRESS_SECRET"].presence
      end
    end
  end
end
