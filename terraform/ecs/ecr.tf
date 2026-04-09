# ECR repo is only created for non-uat environments.
# For uat, set var.ecr_repository_url to point at the prd ECR repo.
module "ecr" {
  count  = var.environment == "uat" ? 0 : 1
  source  = "terraform-aws-modules/ecr/aws"
  version = "~> 2.0"

  repository_name = "llm-orchestrator"

  repository_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Delete untagged images after 7 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 7
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only 10 most recent tagged images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v", "sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      }
    ]
  })

  repository_image_tag_mutability = "MUTABLE"
  manage_registry_scanning_configuration = true
  registry_scan_type                     = "BASIC"

  tags = var.tags
}
