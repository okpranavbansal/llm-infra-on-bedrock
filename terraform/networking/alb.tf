module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name    = "${var.environment}-llm-alb"
  vpc_id  = data.aws_vpc.this.id
  subnets = data.aws_subnets.public.ids

  security_groups = [aws_security_group.alb.id]

  # HTTP → HTTPS redirect
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      redirect = {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    https = {
      port            = 443
      protocol        = "HTTPS"
      certificate_arn = data.aws_acm_certificate.this.arn

      forward = {
        target_group_key = "llm-grpc"
      }
    }
  }

  target_groups = {
    "llm-grpc" = {
      name             = "${var.environment}-llm-grpc"
      protocol         = "HTTP"
      protocol_version = "GRPC"
      target_type      = "ip"
      port             = 50051

      health_check = {
        enabled             = true
        path                = "/llm.v1.HealthService/Check"
        matcher             = "0"
        healthy_threshold   = 2
        unhealthy_threshold = 3
        timeout             = 10
        interval            = 30
      }

      deregistration_delay = 30
    }
  }

  tags = var.tags
}

resource "aws_security_group" "alb" {
  name        = "${var.environment}-llm-alb-sg"
  description = "LLM ALB security group"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
