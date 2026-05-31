module FlowBridge
  class Metrics
    def self.prometheus
      lines = []
      lines << "# HELP flowbridge_workflow_executions_total Workflow executions grouped by status."
      lines << "# TYPE flowbridge_workflow_executions_total counter"
      WorkflowExecution.group(:status).count.each do |status, count|
        lines << %(flowbridge_workflow_executions_total{status="#{label(status)}"} #{count})
      end

      lines << "# HELP flowbridge_dead_letters_open Open dead-letter records."
      lines << "# TYPE flowbridge_dead_letters_open gauge"
      lines << "flowbridge_dead_letters_open #{DeadLetter.where(status: "open").count}"

      lines << "# HELP flowbridge_webhook_events_total Webhook events grouped by status."
      lines << "# TYPE flowbridge_webhook_events_total counter"
      WebhookEvent.group(:status).count.each do |status, count|
        lines << %(flowbridge_webhook_events_total{status="#{label(status)}"} #{count})
      end

      lines << "# HELP flowbridge_node_executions_total Node executions grouped by type and status."
      lines << "# TYPE flowbridge_node_executions_total counter"
      NodeExecution.group(:node_type, :status).count.each do |(node_type, status), count|
        lines << %(flowbridge_node_executions_total{node_type="#{label(node_type)}",status="#{label(status)}"} #{count})
      end

      lines << "# HELP flowbridge_node_execution_duration_ms_avg Average completed node execution duration in milliseconds."
      lines << "# TYPE flowbridge_node_execution_duration_ms_avg gauge"
      NodeExecution.where.not(duration_ms: nil).group(:node_type).average(:duration_ms).each do |node_type, duration|
        lines << %(flowbridge_node_execution_duration_ms_avg{node_type="#{label(node_type)}"} #{duration.to_f.round(2)})
      end

      lines << "# HELP flowbridge_workflow_retries_total Workflow executions that required more than one attempt."
      lines << "# TYPE flowbridge_workflow_retries_total counter"
      lines << "flowbridge_workflow_retries_total #{WorkflowExecution.where("attempt_count > 1").count}"

      lines << "# HELP flowbridge_dead_letters_total Dead letters grouped by status and reason."
      lines << "# TYPE flowbridge_dead_letters_total counter"
      DeadLetter.group(:status, :reason).count.each do |(status, reason), count|
        lines << %(flowbridge_dead_letters_total{status="#{label(status)}",reason="#{label(reason)}"} #{count})
      end

      lines.join("\n") + "\n"
    end

    def self.label(value)
      value.to_s.gsub("\\", "\\\\\\").gsub('"', "\\\"").gsub("\n", "\\n")
    end
    private_class_method :label
  end
end
