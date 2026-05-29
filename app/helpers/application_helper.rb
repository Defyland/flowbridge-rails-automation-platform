module ApplicationHelper
  STATUS_LABELS = {
    "queued" => "Queued",
    "running" => "Running",
    "retrying" => "Retrying",
    "succeeded" => "Succeeded",
    "failed" => "Failed",
    "canceled" => "Canceled",
    "open" => "Open",
    "retried" => "Retried",
    "resolved" => "Resolved",
    "active" => "Active",
    "draft" => "Draft",
    "archived" => "Archived"
  }.freeze

  def status_badge(status)
    tag.span STATUS_LABELS.fetch(status, status.to_s.humanize), class: "status status--#{status}"
  end

  def compact_time(value)
    return "-" unless value

    tag.time value.utc.strftime("%Y-%m-%d %H:%M:%S UTC"), datetime: value.iso8601
  end
end
