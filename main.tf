// This module is responsible for creating a lambda function that checks the retention policy of log groups and updates them if necessary.
// inspired by https://renaghan.com/posts/lambda-cloudwatch-log-retain-manager/

variable "name" {
  type = string
}

variable "retention_in_days" {
  type        = number
  description = "The number of days to retain the log events in the log group. For example, 3"
  default     = 3
}

variable "loggroup_name_match" {
  type        = string
  description = "The prefix of the loggroups, for example '/aws/lambda/us-east-1.my-lambda-function'"
}

variable "schedule_expression" {
  type        = string
  description = "The schedule expression how often the loggroups should be checked. For example, rate(7 days)"
  default     = "rate(7 days)"
}

variable "lambda_zip_output_path" {
  type        = string
  description = "The path to the output zip file"
  default     = "dist/dist.zip"
}

data "archive_file" "lambda" {
  source_file = "${path.module}/loggroup_check.py"
  output_path = var.lambda_zip_output_path
  type        = "zip"
}

data "aws_iam_policy_document" "lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "role" {
  name               = "${var.name}-loggroups"
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_lambda_function" "loggroups_retention_check" {
  function_name    = "${var.name}-loggroups"
  description      = "Check and update the retention policy of log groups created by Lambda@Edge functions"
  handler          = "loggroup_check.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.role.arn
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30
  environment {
    variables = {
      RETAIN_DAYS         = var.retention_in_days
      LOGGROUP_NAME_MATCH = var.loggroup_name_match
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.loggroups_retention_check.function_name}"
  retention_in_days = var.retention_in_days
}

resource "aws_iam_policy" "policy" {
  name   = "${var.name}-loggroups"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "logs:DescribeLogGroups",
            "Resource": "*",
            "Effect": "Allow"
        },
        {
            "Action": "logs:PutRetentionPolicy",
            "Resource": "arn:aws:logs:*:*:${var.loggroup_name_match}*",
            "Effect": "Allow"
        },
        {
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:/aws/lambda/${aws_lambda_function.loggroups_retention_check.function_name}*",
            "Effect": "Allow"
        },
        {
            "Action": "ec2:DescribeRegions",
            "Resource": "*",
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "aws_iam_role" "eventbridge_scheduler" {
  name               = "${var.name}-loggroups-scheduler"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "scheduler.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_policy" "lambda_invoke" {
  name        = "${var.name}-loggroups-scheduler"
  description = "Policy for EventBridge Scheduler to invoke the Lambda function"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "lambda:InvokeFunction",
            "Resource": "${aws_lambda_function.loggroups_retention_check.arn}"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eventbridge_scheduler" {
  role       = aws_iam_role.eventbridge_scheduler.name
  policy_arn = aws_iam_policy.lambda_invoke.arn
}


resource "aws_scheduler_schedule" "loggroups_retention_check" {
  name = "${var.name}-loggroups"

  flexible_time_window {
    mode                      = "FLEXIBLE"
    maximum_window_in_minutes = 240
  }

  schedule_expression = var.schedule_expression

  target {
    arn      = aws_lambda_function.loggroups_retention_check.arn
    role_arn = aws_iam_role.eventbridge_scheduler.arn

    retry_policy {
      maximum_retry_attempts = 0
    }

    input = "{}"
  }
}
