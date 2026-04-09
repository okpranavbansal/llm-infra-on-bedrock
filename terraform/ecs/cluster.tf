module "llm_ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 5.0"

  name = "${var.environment}-llm"

  configuration = {
    execute_command_configuration = {
      logging = "OVERRIDE"
      log_configuration = {
        cloud_watch_log_group_name = "/aws/ecs/${var.environment}-llm"
      }
    }
  }

  cloudwatch_log_group_retention_in_days = 7   # keep LLM exec logs longer than default

  default_capacity_provider_strategy = {
    # Streaming services run On-Demand (Spot interruption would break SSE connections)
    FARGATE = {
      weight = 80
    }
    # Background processing (audit log writers, embedding indexers) can use Spot
    FARGATE_SPOT = {
      weight = 20
    }
  }

  setting = [
    {
      name  = "containerInsights"
      value = var.environment == "prd" ? "enabled" : "disabled"
    }
  ]

  tags = var.tags
}
