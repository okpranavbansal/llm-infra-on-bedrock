# IAM group for CI/CD pipelines and human operators that deploy LLM services
# Includes AmazonBedrockFullAccess for invoking models + managing guardrails

module "llm_cicd_group" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-group-with-policies"
  version = "~> 5.0"

  name = "llm-cicd"

  attach_iam_self_management_policy = false
  enable_mfa_enforcement            = true

  custom_group_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonBedrockFullAccess",
    "arn:aws:iam::aws:policy/AmazonS3FullAccess",
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess",
    "arn:aws:iam::aws:policy/ReadOnlyAccess",
    aws_iam_policy.bedrock_invoke_policy.arn,
  ]

  tags = var.tags
}

# Fine-grained Bedrock invoke policy (least privilege)
# Restrict to specific model IDs to prevent accidental use of expensive models
resource "aws_iam_policy" "bedrock_invoke_policy" {
  name        = "BedrockInvokePolicy-${var.environment}"
  description = "Allow invoking specific Bedrock models for LLM services"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeBedrockModels"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream",
        ]
        Resource = [
          "arn:aws:bedrock:*::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
          "arn:aws:bedrock:*::foundation-model/amazon.titan-embed-text-v1",
          "arn:aws:bedrock:*::foundation-model/amazon.titan-embed-g1-text-02",
        ]
      },
      {
        Sid    = "ListModels"
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel",
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}
