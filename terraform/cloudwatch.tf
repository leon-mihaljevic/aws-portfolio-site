resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "portfolio-lambda-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alerts_eu.arn]

  dimensions = {
    FunctionName = aws_lambda_function.cache_invalidation.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  provider            = aws.us_east_1
  alarm_name          = "portfolio-cloudfront-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = 5
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.alerts_us.arn]

  dimensions = {
    Region         = "Global"
    DistributionId = aws_cloudfront_distribution.site.id
  }
}
