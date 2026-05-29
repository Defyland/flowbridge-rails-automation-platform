module Api
  module V1
    class WebhookEventsController < Api::BaseController
      skip_before_action :authenticate_api_key!
      skip_before_action :enforce_rate_limit!

      def create
        workflow_version = WorkflowVersion.find_by!(trigger_key: params[:trigger_key])
        Current.organization = workflow_version.organization

        raw_payload = request.raw_post.presence || "{}"
        unless FlowBridge::SignatureVerifier.valid?(
          secret: workflow_version.webhook_secret,
          payload: raw_payload,
          header: request.headers["X-FlowBridge-Signature"]
        )
          return render_error(:unauthorized, "invalid_webhook_signature", "webhook signature did not match")
        end

        payload = JSON.parse(raw_payload)
        result = FlowBridge::WebhookIngestor.call(
          workflow_version: workflow_version,
          payload: payload,
          headers: flowbridge_headers,
          idempotency_key: idempotency_key(raw_payload),
          correlation_id: Current.correlation_id
        )

        render status: :accepted, json: {
          webhook_event: result.event.to_public_hash,
          workflow_execution: result.execution&.to_public_hash,
          duplicate: result.duplicate
        }
      rescue JSON::ParserError
        render_error(:bad_request, "invalid_json", "request body must be valid JSON")
      end

      private

      def idempotency_key(raw_payload)
        request.headers["X-FlowBridge-Event-Id"].presence ||
          OpenSSL::Digest::SHA256.hexdigest(raw_payload)
      end

      def flowbridge_headers
        request.headers.env.each_with_object({}) do |(key, value), headers|
          next unless key.start_with?("HTTP_X_FLOWBRIDGE")

          headers[key.delete_prefix("HTTP_").downcase.tr("_", "-")] = value
        end
      end
    end
  end
end
