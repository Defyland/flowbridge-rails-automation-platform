output "webhook_ingress_base_url" {
  description = "Base URL for provider webhook registration."
  value       = aws_apigatewayv2_stage.webhook_ingress.invoke_url
}

output "provider_webhook_path_pattern" {
  description = "Path pattern that forwards provider traffic to the Lambda normalizer."
  value       = "${aws_apigatewayv2_stage.webhook_ingress.invoke_url}/webhooks/{trigger_key}"
}

output "lambda_function_name" {
  description = "Lambda function that normalizes provider webhooks."
  value       = aws_lambda_function.webhook_ingress.function_name
}
