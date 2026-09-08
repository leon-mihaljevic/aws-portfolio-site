variable "alert_email" {
  description = "Email address for CloudWatch/SNS alert notifications. Set in a local terraform.tfvars file (gitignored) - never hardcode or commit this."
  type        = string
  sensitive   = true
}
