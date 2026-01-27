############################################
# Step Functions Orchestration
# - Runs both Glue jobs sequentially
# - Invokes Lambda notification after completion
############################################

locals {
  state_machine_name = "amazon-capstone-orchestrator"
}
resource "aws_iam_role" "sfn_role" {
  name = "amazon-capstone-sfn-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "sfn_policy" {
  name = "amazon-capstone-sfn-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [

      # Glue permissions
      {
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:GetJob",
          "glue:BatchStopJobRun",
          "glue:StartCrawler",
          "glue:GetCrawler",
          "glue:GetCrawlerMetrics"
        ]
        Resource = "*"
      },

      # Lambda invoke
      # {
      #   Effect = "Allow"
      #   Action = "lambda:InvokeFunction"
      #   Resource = var.lambda_function_arn
      # },

      # CloudWatch Logs
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sfn_attach" {
  role       = aws_iam_role.sfn_role.name
  policy_arn = aws_iam_policy.sfn_policy.arn
}



resource "aws_sfn_state_machine" "orchestrator" {
  name     = local.state_machine_name
  role_arn = aws_iam_role.sfn_role.arn

  definition = jsonencode({
    Comment = "Capstone Amazon Review Pipeline (Download → Flatten → Notify)",
    StartAt = "RunDownloadJob",
    States = {
      RunDownloadJob = {
        Type = "Task",
        Resource = "arn:aws:states:::glue:startJobRun.sync",
        Parameters = {
          JobName = var.download_job_name
          Arguments = {
            "--raw_bucket" = var.raw_bucket
          }
        },
        Next = "RunFlattenJob",
      },

      RunFlattenJob = {
        Type     = "Task"
        Resource = "arn:aws:states:::glue:startJobRun.sync"

        Parameters = {
          JobName = var.flatten_job_name
          Arguments = {
            "--script_bucket"            = var.script_bucket
          }
        },
        Next = "RunCrawler",

      },
      RunCrawler = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:startCrawler"
        Parameters = {
          Name = "${var.crawler_name}"
        }
        Next = "WaitForCrawler"
      },

      WaitForCrawler = {
        Type = "Wait"
        Seconds = 30
        Next = "CheckCrawlerStatus"
      },

      CheckCrawlerStatus = {
        Type     = "Task"
        Resource = "arn:aws:states:::aws-sdk:glue:getCrawler"
        Parameters = {
          Name = "${var.crawler_name}"
        }
        Next = "CrawlerFinished"
      },

      CrawlerFinished = {
        Type = "Choice"
        Choices = [
          {
            Variable = "$.Crawler.State"
            StringEquals = "READY"
            Next = "Done"
          }
        ]
        Default = "WaitForCrawler"
      },

      Done = {
        Type = "Succeed"
      }
    }
  })
}