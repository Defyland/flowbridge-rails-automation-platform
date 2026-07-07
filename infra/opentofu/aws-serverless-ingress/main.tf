locals {
  name_prefix       = "${var.project_name}-${var.environment}"
  lambda_source_dir = abspath("${path.module}/../../../services/serverless/webhook_ingress")
  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "opentofu"
      Component   = "serverless-webhook-ingress"
    },
    var.tags
  )
}

data "archive_file" "lambda_package" {
  type        = "zip"
  source_dir  = local.lambda_source_dir
  output_path = "${path.module}/.terraform/${local.name_prefix}-webhook-ingress.zip"

  excludes = [
    "test/*",
    "test/**"
  ]
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_prefix}-webhook-ingress"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name_prefix}-webhook-ingress"
  retention_in_days = var.log_retention_days
  tags              = local.tags
}

resource "aws_iam_role" "lambda" {
  name = "${local.name_prefix}-webhook-ingress-lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
  tags = local.tags
}

resource "aws_iam_role_policy" "lambda_logs" {
  name = "${local.name_prefix}-webhook-ingress-logs"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "${aws_cloudwatch_log_group.lambda.arn}:*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_secrets" {
  name = "${local.name_prefix}-webhook-ingress-secrets"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "secretsmanager:GetSecretValue"
        Resource = var.serverless_ingress_secret_arn
      }
    ]
  })
}

resource "aws_lambda_function" "webhook_ingress" {
  function_name    = "${local.name_prefix}-webhook-ingress"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.lambda_package.output_path
  source_code_hash = data.archive_file.lambda_package.output_base64sha256
  handler          = "handler.handler"
  runtime          = var.lambda_runtime
  architectures    = [var.lambda_architecture]
  timeout          = var.lambda_timeout_seconds
  memory_size      = var.lambda_memory_mb

  environment {
    variables = {
      FLOWBRIDGE_SOURCE                        = var.provider_source
      FLOWBRIDGE_RAILS_INGRESS_URL             = var.rails_ingress_url
      FLOWBRIDGE_SERVERLESS_INGRESS_SECRET_ARN = var.serverless_ingress_secret_arn
      FLOWBRIDGE_EVENT_ID_HEADER               = var.event_id_header
      FLOWBRIDGE_RELAY_OPEN_TIMEOUT_SECONDS    = tostring(var.relay_open_timeout_seconds)
      FLOWBRIDGE_RELAY_READ_TIMEOUT_SECONDS    = tostring(var.relay_read_timeout_seconds)
    }
  }

  tracing_config {
    mode = "Active"
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda_logs,
    aws_iam_role_policy.lambda_secrets
  ]

  tags = local.tags
}

resource "aws_apigatewayv2_api" "webhook_ingress" {
  name          = "${local.name_prefix}-webhook-ingress"
  protocol_type = "HTTP"
  tags          = local.tags
}

resource "aws_apigatewayv2_integration" "lambda_proxy" {
  api_id                 = aws_apigatewayv2_api.webhook_ingress.id
  integration_type       = "AWS_PROXY"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.webhook_ingress.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "webhook" {
  api_id    = aws_apigatewayv2_api.webhook_ingress.id
  route_key = "POST /webhooks/{trigger_key}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_proxy.id}"
}

resource "aws_apigatewayv2_stage" "webhook_ingress" {
  api_id      = aws_apigatewayv2_api.webhook_ingress.id
  name        = var.api_stage_name
  auto_deploy = true
  tags        = local.tags

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.throttle_burst_limit
    throttling_rate_limit  = var.throttle_rate_limit
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_ingress.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.webhook_ingress.execution_arn}/*/*"
}
