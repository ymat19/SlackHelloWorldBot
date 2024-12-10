output "slack_bot_url" {
  value = "${aws_apigatewayv2_api.slack_bot.api_endpoint}${var.end_point_path}"
}