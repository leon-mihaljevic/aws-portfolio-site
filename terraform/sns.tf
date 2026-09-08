resource "aws_sns_topic" "alerts_eu" {
  name         = "portfolio-alerts-eu"
  display_name = "Alerts for EU"
}

resource "aws_sns_topic" "alerts_us" {
  provider     = aws.us_east_1
  name         = "portfolio-alerts-us"
  display_name = "Alerts for US"
}

resource "aws_sns_topic_subscription" "alerts_eu_email" {
  topic_arn = aws_sns_topic.alerts_eu.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_sns_topic_subscription" "alerts_us_email" {
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.alerts_us.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
