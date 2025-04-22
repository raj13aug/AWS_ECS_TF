# Store state file in an s3 bucket
terraform {
  backend "s3" {
    bucket  = "my-terraform-state-ecs-demo"
    region  = "us-east-1"
    key     = "ecs-fargate/terraform.tfstate"
    encrypt = true
  }
  required_version = ">=0.13.0"
  required_providers {
    aws = {
      version = "~> 5.0"
      source  = "hashicorp/aws"
    }
  }
}
