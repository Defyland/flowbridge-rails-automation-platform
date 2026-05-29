module FlowBridge
  class Metrics
    def self.prometheus
      lines = []
      lines << "# HELP flowbridge_workflow_executions_total Workflow executions grouped by status."
      lines << "# TYPE flowbridge_workflow_executions_total counter"
      WorkflowExecution.group(:status).count.each do |status, count|
        lines << %(flowbridge_workflow_executions_total{status="#{status}"} #{count})
      end

      lines << "# HELP flowbridge_dead_letters_open Open dead-letter records."
      lines << "# TYPE flowbridge_dead_letters_open gauge"
      lines << "flowbridge_dead_letters_open #{DeadLetter.where(status: "open").count}"

      lines << "# HELP flowbridge_webhook_events_total Webhook events grouped by status."
      lines << "# TYPE flowbridge_webhook_events_total counter"
      WebhookEvent.group(:status).count.each do |status, count|
        lines << %(flowbridge_webhook_events_total{status="#{status}"} #{count})
      end

      lines.join("\n") + "\n"
    end
  end
end
