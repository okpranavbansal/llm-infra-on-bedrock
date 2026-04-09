# ECS Task Execution Role for LLM services
# Includes Bedrock invoke permissions so tasks can call models directly

module "ecs_task_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role       = true
  role_requires_mfa = false
  role_name         = "llmTaskExecutionRole-${var.environment}"

  trusted_role_services = ["ecs-tasks.amazonaws.com"]

  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    aws_iam_policy.bedrock_invoke_policy.arn,
    aws_iam_policy.llm_task_policy.arn,
  ]

  tags = var.tags
}

resource "aws_iam_policy" "llm_task_policy" {
  name        = "LLMTaskPolicy-${var.environment}"
  description = "Custom permissions for LLM ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAccess"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "*"
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ]
        Resource = "arn:aws:logs:*:${var.account_id}:log-group:/ecs/llm-*:*"
      },
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
        ]
        Resource = "arn:aws:ssm:*:${var.account_id}:parameter/llm/${var.environment}/*"
      }
    ]
  })

  tags = var.tags
}
