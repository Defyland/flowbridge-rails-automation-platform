variable "aws_region" {
  description = "AWS region for the serverless ingress edge."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project prefix used for named AWS resources."
  type        = string
  default     = "flowbridge"
}

variable "environment" {
  description = "Deployment environment name."
  type        = string
  default     = "staging"
}

variable "provider_source" {
  description = "Stable source identifier recorded in serverless webhook envelopes."
  type        = string
}

variable "rails_ingress_url" {
  description = "Base HTTPS URL of the Rails FlowBridge service."
  type        = string
}

variable "serverless_ingress_secret_arn" {
  description = "Secrets Manager ARN containing the HMAC secret shared with the Rails serverless ingress endpoint."
  type        = string
}

variable "event_id_header" {
  description = "Provider header used as external event id before falling back to payload id."
  type        = string
  default     = "x-flowbridge-event-id"
}

variable "lambda_runtime" {
  description = "Managed AWS Lambda Ruby runtime."
  type        = string
  default     = "ruby3.4"
}

variable "lambda_architecture" {
  description = "Lambda CPU architecture."
  type        = string
  default     = "arm64"
}

variable "lambda_timeout_seconds" {
  description = "Lambda timeout for synchronous relay to Rails."
  type        = number
  default     = 8
}

variable "lambda_memory_mb" {
  description = "Lambda memory allocation."
  type        = number
  default     = 256
}

variable "relay_open_timeout_seconds" {
  description = "Open timeout for the Lambda to Rails relay."
  type        = number
  default     = 2
}

variable "relay_read_timeout_seconds" {
  description = "Read timeout for the Lambda to Rails relay."
  type        = number
  default     = 5
}

variable "api_stage_name" {
  description = "HTTP API stage name."
  type        = string
  default     = "$default"
}

variable "throttle_burst_limit" {
  description = "API Gateway burst throttle for provider ingress."
  type        = number
  default     = 100
}

variable "throttle_rate_limit" {
  description = "API Gateway steady-state requests per second for provider ingress."
  type        = number
  default     = 50
}

variable "log_retention_days" {
  description = "CloudWatch retention for Lambda and API Gateway logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Extra resource tags."
  type        = map(string)
  default     = {}
}
