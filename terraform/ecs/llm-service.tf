module "llm_orchestrator_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 5.0"

  name        = "llm-orchestrator"
  cluster_arn = module.llm_ecs_cluster.arn

  cpu    = 1024   # 1 vCPU — LLM calls are I/O-bound, not CPU-bound
  memory = 4096   # 4GB — large context windows need headroom

  container_definitions = {
    "llm-orchestrator" = {
      # module.ecr has count=0 for uat (uses a shared image from prd ECR).
      # Use try() to fall back to a var for uat deployments.
      image     = "${try(module.ecr[0].repository_url, var.ecr_repository_url)}:${var.image_tag}"
      essential = true

      port_mappings = [
        {
          name          = "grpc"
          containerPort = 50051
          protocol      = "tcp"
        },
        {
          name          = "http"
          containerPort = 8080
          protocol      = "tcp"
        }
      ]

      health_check = {
        # gRPC health check — standard protocol
        command     = ["CMD-SHELL", "grpc_health_probe -addr=:50051 || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60   # Bedrock SDK init takes time on cold start
      }

      environment = [
        { name = "APP_ENV",           value = var.environment },
        { name = "BEDROCK_REGION",    value = var.bedrock_region },
        { name = "BEDROCK_MODEL_ID",  value = "anthropic.claude-3-sonnet-20240229-v1:0" },
        { name = "KAFKA_TOPIC_IN",    value = "${var.environment}.prompt.ingestion" },
        { name = "KAFKA_TOPIC_OUT",   value = "${var.environment}.llm.response.events" },
      ]

      secrets = [
        {
          name      = "KAFKA_API_KEY"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.environment}/llm/KAFKA_API_KEY"
        },
        {
          name      = "KAFKA_API_SECRET"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.environment}/llm/KAFKA_API_SECRET"
        },
        {
          name      = "KAFKA_BOOTSTRAP_SERVERS"
          valueFrom = "arn:aws:ssm:${var.aws_region}:${var.account_id}:parameter/${var.environment}/llm/KAFKA_BOOTSTRAP_SERVERS"
        }
      ]

      log_configuration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.environment}-llm-orchestrator"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  }

  load_balancer = {
    service = {
      # Target group is owned by terraform/networking/alb.tf (module.alb).
      # Reference it via the ALB module's output rather than creating a duplicate resource here.
      target_group_arn = module.alb.target_groups["llm-grpc"].arn
      container_name   = "llm-orchestrator"
      container_port   = 50051
    }
  }

  subnet_ids         = data.aws_subnets.private.ids
  security_group_ids = [aws_security_group.llm_service.id]

  # module.ecs_task_role is defined in terraform/iam/ecs-task-role.tf.
  # In a real multi-root setup this ARN would come from remote state:
  #   data "terraform_remote_state" "iam" { ... }
  #   task_exec_iam_role_arn = data.terraform_remote_state.iam.outputs.ecs_task_role_arn
  task_exec_iam_role_arn = module.ecs_task_role.iam_role_arn

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  tags = var.tags
}

# The gRPC target group is managed by module.alb in terraform/networking/alb.tf.
# Removed standalone aws_lb_target_group resource to avoid duplication.
