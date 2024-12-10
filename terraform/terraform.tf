# create lambda execution role
resource "aws_iam_role" "slack_bot" {
  name = "slack-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "slack_bot" {
  name = "slack-lambda_policy"
  role = aws_iam_role.slack_bot.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "*"
      }
    ]
  })
}

# null_resource to update pip package
resource "null_resource" "slack_bot" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "pip install -r ../src/requirements.txt -t ../src/package && cp ../src/lambda_function.py ../src/package"
  }
}

# lambda source data
data "archive_file" "slack_bot" {
  depends_on  = [null_resource.slack_bot]
  type        = "zip"
  source_dir  = "../src/package"
  output_path = "lambda.zip"
}

# create python lambda function
resource "aws_lambda_function" "slack_bot" {
  depends_on       = [data.archive_file.slack_bot]
  function_name    = "slack-bot"
  role             = aws_iam_role.slack_bot.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.10"
  filename         = data.archive_file.slack_bot.output_path
  source_code_hash = data.archive_file.slack_bot.output_base64sha256
  timeout          = 15
  architectures    = ["arm64"]
  environment {
    variables = {
      SLACK_BOT_TOKEN      = var.slack_bot_token
      SLACK_SIGNING_SECRET = var.slack_signing_secret
    }
  }
}

resource "aws_apigatewayv2_api" "slack_bot" {
  name          = "slack-bot-api"
  protocol_type = "HTTP"
}

resource "aws_lambda_permission" "slack_bot" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_bot.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.slack_bot.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "slack_bot" {
  api_id                 = aws_apigatewayv2_api.slack_bot.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.slack_bot.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "slack_bot" {
  api_id    = aws_apigatewayv2_api.slack_bot.id
  route_key = "POST ${var.end_point_path}"
  target    = "integrations/${aws_apigatewayv2_integration.slack_bot.id}"
}

resource "aws_apigatewayv2_stage" "slack_bot" {
  api_id      = aws_apigatewayv2_api.slack_bot.id
  name        = "$default"
  auto_deploy = true
  default_route_settings {
    throttling_rate_limit  = 1
    throttling_burst_limit = 10
  }
}