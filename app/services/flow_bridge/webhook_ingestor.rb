module FlowBridge
  class WebhookIngestor
    Result = Struct.new(:event, :execution, :duplicate, keyword_init: true)

    def self.call(workflow_version:, payload:, headers:, idempotency_key:, correlation_id:)
      existing = workflow_version.webhook_events.find_by(idempotency_key: idempotency_key)
      return Result.new(event: existing, execution: existing.workflow_execution, duplicate: true) if existing

      event = nil
      execution = nil

      ActiveRecord::Base.transaction do
        event = workflow_version.webhook_events.create!(
          organization: workflow_version.organization,
          idempotency_key: idempotency_key,
          source_event_id: headers["x-flowbridge-event-id"],
          payload_json: payload,
          headers_json: SecretMasker.mask_hash(headers),
          correlation_id: correlation_id,
          received_at: Time.current
        )

        execution = workflow_version.workflow_executions.create!(
          organization: workflow_version.organization,
          workflow: workflow_version.workflow,
          webhook_event: event,
          idempotency_key: idempotency_key,
          correlation_id: correlation_id,
          input_json: payload
        )

        AuditLog.record!(
          organization: workflow_version.organization,
          action: "webhook_event.accepted",
          subject: event,
          metadata: { workflow_execution_id: execution.id }
        )
      end

      WorkflowExecutionJob.perform_later(execution.id)
      Result.new(event: event, execution: execution, duplicate: false)
    rescue ActiveRecord::RecordNotUnique
      duplicate = workflow_version.webhook_events.find_by!(idempotency_key: idempotency_key)
      Result.new(event: duplicate, execution: duplicate.workflow_execution, duplicate: true)
    end
  end
end
