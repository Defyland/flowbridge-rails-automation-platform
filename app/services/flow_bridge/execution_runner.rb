module FlowBridge
  class ExecutionRunner
    def initialize(execution)
      @execution = execution
      @workflow_version = execution.workflow_version
      @organization = execution.organization
    end

    def call
      return execution if execution.status == "succeeded" || execution.status == "canceled"

      Current.organization = organization
      Current.correlation_id = execution.correlation_id

      attempt = start_attempt!
      previous_outputs = successful_outputs

      workflow_version.nodes.each do |node|
        key = node.fetch("key")
        next if previous_outputs.key?(key)

        node_execution = execution.node_executions.create!(
          node_key: key,
          node_type: node.fetch("type"),
          attempt: attempt,
          input_json: FlowBridge::SecretMasker.mask_hash(node_input(previous_outputs)),
          started_at: Time.current
        )

        result = NodeExecutor.new(
          organization: organization,
          node: node,
          input: node_input(previous_outputs)
        ).call

        node_execution.complete!(result)
        previous_outputs[key] = result
      rescue NodeExecutor::ExecutionError => error
        handle_failure(error: error, node: node, node_execution: node_execution, attempt: attempt)
        return execution.reload
      end

      execution.update!(status: "succeeded", completed_at: Time.current, error_json: {})
      AuditLog.record!(
        organization: organization,
        action: "workflow_execution.succeeded",
        subject: execution,
        metadata: { attempt: attempt, node_count: workflow_version.nodes.count }
      )
      execution
    ensure
      Current.reset
    end

    private

    attr_reader :execution, :workflow_version, :organization

    def start_attempt!
      execution.with_lock do
        execution.reload
        execution.update!(
          status: "running",
          started_at: execution.started_at || Time.current,
          attempt_count: execution.attempt_count + 1
        )
        execution.attempt_count
      end
    end

    def node_input(previous_outputs)
      {
        "event" => execution.input_json,
        "previous_outputs" => previous_outputs
      }
    end

    def successful_outputs
      execution.node_executions
        .where(status: "succeeded")
        .order(:attempt, :created_at)
        .each_with_object({}) { |node_execution, outputs| outputs[node_execution.node_key] = node_execution.output_json }
    end

    def handle_failure(error:, node:, node_execution:, attempt:)
      node_execution.fail!(error.to_h)
      execution.update!(status: failure_status(error, attempt), error_json: error.to_h)

      if retry?(error, attempt)
        WorkflowExecutionJob.set(wait: RetryPolicy.delay(attempt: attempt, policy: workflow_version.retry_policy)).perform_later(execution.id)
        AuditLog.record!(
          organization: organization,
          action: "workflow_execution.retry_scheduled",
          subject: execution,
          metadata: { attempt: attempt, node_key: node.fetch("key"), error: error.to_h }
        )
      else
        execution.update!(completed_at: Time.current)
        dead_letter = organization.dead_letters.create!(
          workflow_execution: execution,
          node_execution: node_execution,
          reason: error.code,
          payload_json: {
            node: node,
            input: node_execution.input_json,
            error: error.to_h
          }
        )
        AuditLog.record!(
          organization: organization,
          action: "dead_letter.created",
          subject: dead_letter,
          metadata: { workflow_execution_id: execution.id, node_key: node.fetch("key") }
        )
      end
    end

    def retry?(error, attempt)
      error.retriable? && !RetryPolicy.exhausted?(attempt: attempt, policy: workflow_version.retry_policy)
    end

    def failure_status(error, attempt)
      retry?(error, attempt) ? "retrying" : "failed"
    end
  end
end
