terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "~> 1.0"
    }
  }
}

resource "confluent_environment" "llm" {
  display_name = "${var.environment}-llm"
}

# Standard cluster on AWS — use Dedicated for higher throughput
resource "confluent_kafka_cluster" "llm" {
  display_name = "${var.environment}-llm-kafka"
  cloud        = "AWS"
  region       = var.aws_region
  availability = var.availability   # "SINGLE_ZONE" for stg, "MULTI_ZONE" for prd

  standard {}

  environment {
    id = confluent_environment.llm.id
  }

  lifecycle {
    prevent_destroy = true
  }
}
