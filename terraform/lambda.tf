data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda/portfolio-cache-invalidation/lambda_function.py"
  output_path = "${path.module}/build/portfolio-cache-invalidation.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "portfolio-cache-invalidation-role-t0awh00r"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

# Note: the Lambda console's "basic execution role" default doesn't attach
# the AWS-owned managed policy directly - it clones it into a customer-
# managed policy in this account first, then attaches that clone.
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::260317865228:policy/service-role/AWSLambdaBasicExecutionRole-bd7fa1f0-10df-431c-a0da-ba3b08b71b81"
}

resource "aws_iam_role_policy" "invalidate" {
  name = "AllowInvalidateThisDistribution"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowInvalidateThisDistribution"
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = "arn:aws:cloudfront::260317865228:distribution/E34T8I1WWAU4N"
      }
    ]
  })
}

resource "aws_lambda_function" "cache_invalidation" {
  function_name    = "portfolio-cache-invalidation"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.14"
  timeout          = 3
  memory_size      = 128
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DISTRIBUTION_ID = "E34T8I1WWAU4N"
    }
  }
}

# Lets S3 invoke the function - this is what shows up under "Add trigger"
# in the console, represented explicitly here.
resource "aws_lambda_permission" "allow_s3" {
  statement_id   = "lambda-744a3e9a-9b53-4853-b3e2-a872a555c1e0"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.cache_invalidation.function_name
  principal      = "s3.amazonaws.com"
  source_account = "260317865228"
  source_arn     = aws_s3_bucket.site.arn
}

resource "aws_s3_bucket_notification" "site" {
  bucket = aws_s3_bucket.site.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.cache_invalidation.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_s3]
}
