variable "deploy_role_arn" {
  description = "ARN of the Terraform execution role"
  type        = string
}

variable "slack_bot_token" {
  description = "Slack bot token"
  type        = string
}

variable "slack_signing_secret" {
  description = "Slack signing secret"
  type        = string
}

variable "end_point_path" {
  description = "Path to the endpoint"
  default = "/slack/events"
  type        = string
}