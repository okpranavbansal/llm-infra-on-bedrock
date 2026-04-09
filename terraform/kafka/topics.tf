# LLM async inference pipeline topics
# prompt-ingestion → LLM orchestrator consumes, calls Bedrock, publishes to llm-response-events
# llm-response-events → downstream services (streaming handler, analytics, audit)
# llm-audit-log → immutable audit trail of all prompts + responses

locals {
  llm_topics = {
    "prompt-ingestion" = {
      topic_name       = "${var.environment}.prompt.ingestion"
      partitions_count = var.environment == "prd" ? 12 : 3
    }
    "llm-response-events" = {
      topic_name       = "${var.environment}.llm.response.events"
      partitions_count = var.environment == "prd" ? 12 : 3
    }
    "llm-audit-log" = {
      topic_name       = "${var.environment}.llm.audit.log"
      partitions_count = var.environment == "prd" ? 6 : 1
    }
    "embedding-requests" = {
      topic_name       = "${var.environment}.embedding.requests"
      partitions_count = var.environment == "prd" ? 6 : 1
    }
  }
}

resource "confluent_kafka_topic" "llm_topics" {
  for_each = local.llm_topics

  kafka_cluster {
    id = confluent_kafka_cluster.llm.id
  }

  topic_name       = each.value.topic_name
  partitions_count = each.value.partitions_count

  config = {
    "cleanup.policy"         = "delete"
    "delete.retention.ms"    = "86400000"      # 1 day tombstone retention
    "max.message.bytes"      = "2097164"        # 2MB max (LLM responses can be large)
    "min.insync.replicas"    = "2"
    "retention.bytes"        = "-1"
    "retention.ms"           = "604800000"      # 7 days
    "segment.bytes"          = "104857600"      # 100MB segments
    "message.timestamp.type" = "CreateTime"
  }

  lifecycle {
    prevent_destroy = true
  }
}
