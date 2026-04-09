# AWS Cloud Map — private DNS for service-to-service calls within the VPC
# Allows services to call each other via: llm-orchestrator.prd.local:50051

resource "aws_service_discovery_private_dns_namespace" "llm" {
  name        = "${var.environment}.local"
  description = "Private DNS for LLM services"
  vpc         = data.aws_vpc.this.id

  tags = var.tags
}

resource "aws_service_discovery_service" "llm_orchestrator" {
  name = "llm-orchestrator"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.llm.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}

resource "aws_service_discovery_service" "embedding_service" {
  name = "embedding-service"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.llm.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = var.tags
}
