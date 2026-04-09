# Bedrock vs SageMaker: Why We Chose Bedrock

## Decision Context

We needed managed LLM inference for a B2B sales intelligence product. The two primary AWS options were Bedrock and SageMaker JumpStart.

## Comparison

| Criterion | Bedrock | SageMaker JumpStart |
|-----------|---------|---------------------|
| Model deployment | None (managed by AWS) | Deploy endpoint (~10 min) |
| Model updates | Automatic (AWS manages) | Manual redeployment |
| Cold start | None (serverless) | Can cold-start on auto-scale |
| Pricing model | Per-token | Per-instance-hour |
| Foundation models | Claude, Titan, Llama, Mistral | Same + custom models |
| Custom fine-tuning | Bedrock fine-tuning (limited) | Full SageMaker Training Jobs |
| Guardrails | Native (content filtering) | Manual implementation |
| Latency | <1s first token (streaming) | Comparable |
| IAM | `bedrock:InvokeModel` | `sagemaker:InvokeEndpoint` |
| Operational overhead | Near-zero | Endpoint lifecycle management |

## Our Decision: Bedrock

**Reasons:**

1. **No model deployment management** — we don't have MLOps capacity to manage SageMaker endpoints, handle scaling, or manage endpoint lifecycle. Bedrock is serverless.

2. **Per-token pricing** is predictable for our use case. A B2B search query typically uses 2,000-8,000 tokens. SageMaker's per-instance pricing would mean paying for idle time.

3. **Native guardrails** — Bedrock Guardrails handles PII detection and content filtering without custom implementation.

4. **Claude 3 availability** — At the time of this decision, Claude 3 Sonnet was only available via Bedrock on AWS (not SageMaker).

## Trade-offs Accepted

- **No custom fine-tuning at launch** — We use prompt engineering and RAG instead. Fine-tuning is a future consideration if base model quality is insufficient.
- **Vendor lock-in** — Bedrock model IDs are AWS-specific. Mitigation: abstract behind an LLM client interface so models can be swapped.
- **Region availability** — Bedrock model availability varies by region. We provision in `us-east-1` for broadest model coverage and use VPC endpoints for data residency.

## Architecture Pattern

```python
# Abstract LLM client interface — swap models without changing callers
from abc import ABC, abstractmethod

class LLMClient(ABC):
    @abstractmethod
    def invoke(self, prompt: str, max_tokens: int = 1000) -> str: ...

class BedrockClient(LLMClient):
    def __init__(self, model_id: str, region: str):
        self.client = boto3.client("bedrock-runtime", region_name=region)
        self.model_id = model_id

    def invoke(self, prompt: str, max_tokens: int = 1000) -> str:
        response = self.client.invoke_model(
            modelId=self.model_id,
            body=json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": max_tokens,
                "messages": [{"role": "user", "content": prompt}],
            }),
        )
        return json.loads(response["body"].read())["content"][0]["text"]
```
