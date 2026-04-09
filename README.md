# llm-infra-on-bedrock
> Production-grade infrastructure for deploying LLM-powered microservices on AWS Bedrock, ECS Fargate, and Confluent Cloud Kafka.

![AWS Bedrock](https://img.shields.io/badge/AWS%20Bedrock-232F3E?style=flat&logo=amazonaws&logoColor=white) ![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white) ![Kafka](https://img.shields.io/badge/Apache%20Kafka-231F20?style=flat&logo=apachekafka&logoColor=white) ![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)

Production-grade infrastructure for deploying LLM-powered microservices on **AWS Bedrock**, orchestrated with **ECS Fargate** and **Confluent Cloud Kafka** for async inference pipelines.

---

## Architecture

```mermaid
flowchart TD
    subgraph clients [Clients]
        WebApp[Web App]
        API[External API]
    end

    subgraph edge [Edge]
        ALB[Application LB\ngRPC + HTTP/2]
        CF[CloudFront\nStatic Assets]
    end

    subgraph compute [ECS Fargate - LLM Services]
        Gateway[API Gateway Service\nHTTP → gRPC]
        LLMSvc[LLM Orchestrator\nPrompt + Context Assembly]
        RAGSvc[RAG Service\nVector Search + Retrieval]
        StreamSvc[Streaming Response\nSSE Handler]
    end

    subgraph bedrock [AWS Bedrock]
        Claude[Claude 3 Sonnet]
        Titan[Amazon Titan\nEmbeddings]
    end

    subgraph kafka [Confluent Cloud Kafka]
        PromptTopic[prompt-ingestion\ntopic]
        ResponseTopic[llm-response-events\ntopic]
        AuditTopic[llm-audit-log\ntopic]
    end

    subgraph storage [Storage]
        S3[S3\nPrompt templates\nAudit logs]
        RDS[(RDS MySQL\nConversation history)]
    end

    clients --> ALB --> Gateway
    Gateway --> LLMSvc
    LLMSvc --> RAGSvc
    LLMSvc --> bedrock
    LLMSvc --> PromptTopic
    PromptTopic --> StreamSvc
    StreamSvc --> ResponseTopic
    LLMSvc --> S3
    LLMSvc --> RDS
    Titan --> RAGSvc
```

---

## Stack

| Component | Technology |
|-----------|-----------|
| Inference | AWS Bedrock (Claude 3 Sonnet, Titan Embeddings) |
| Serving | ECS Fargate + Fargate Spot |
| Async pipeline | Confluent Cloud Kafka (AWS-hosted) |
| Container registry | ECR with lifecycle policies |
| IAM | ecsTaskExecutionRole + Bedrock invoke policy |
| Service discovery | AWS Cloud Map (private DNS) |
| Observability | CloudWatch Container Insights + ECS Exec |

---

## Repository Structure

```
llm-infra-on-bedrock/
├── README.md
├── terraform/
│   ├── iam/
│   │   ├── bedrock-access.tf        # IAM group + policy for Bedrock
│   │   └── ecs-task-role.tf          # ECS task execution role
│   ├── ecs/
│   │   ├── cluster.tf               # Fargate cluster with Container Insights
│   │   ├── llm-service.tf           # LLM orchestrator ECS service
│   │   └── ecr.tf                   # ECR with lifecycle
│   ├── kafka/
│   │   ├── confluent-cluster.tf     # Confluent Cloud cluster on AWS
│   │   └── topics.tf                # LLM topics (prompt, response, audit)
│   └── networking/
│       ├── alb.tf                   # ALB with gRPC target group
│       └── service-discovery.tf     # Cloud Map DNS
├── kubernetes/
│   ├── deployment.yaml              # GKE equivalent (for hybrid deployments)
│   ├── service.yaml
│   └── hpa.yaml
└── docs/
    ├── architecture.md              # Detailed architecture + decision log
    └── bedrock-vs-sagemaker.md      # Why Bedrock over SageMaker
```

---

## Quick Start

```bash
# 1. Bootstrap IAM
cd terraform/iam
terraform init && terraform apply

# 2. Deploy ECS cluster + services
cd ../ecs
terraform init && terraform apply -var="environment=prd"

# 3. Create Confluent Kafka cluster + topics
cd ../kafka
terraform init && terraform apply

# 4. Deploy ALB
cd ../networking
terraform init && terraform apply
```

---

## Key Design Decisions

- **Bedrock over SageMaker:** Bedrock provides managed inference with no model deployment overhead. See [bedrock-vs-sagemaker.md](docs/bedrock-vs-sagemaker.md).
- **Kafka for async inference:** Long-running LLM calls (5-30s) are decoupled via Kafka so the API gateway can return a request ID immediately, with the response delivered via SSE or webhook.
- **Fargate Spot for non-streaming services:** Background processing services (audit log writers, embedding indexers) run on Spot. Streaming response services run On-Demand.

## Author

**Pranav Bansal** — AI Infrastructure & SRE Engineer

[![LinkedIn](https://img.shields.io/badge/LinkedIn-0077B5?style=flat&logo=linkedin&logoColor=white)](https://linkedin.com/in/okpranavbansal)
[![GitHub](https://img.shields.io/badge/GitHub-181717?style=flat&logo=github&logoColor=white)](https://github.com/okpranavbansal)