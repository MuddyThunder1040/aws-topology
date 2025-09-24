# Terraform version and provider requirements for DynamoDB cluster

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: Configure remote state backend
  # Uncomment and configure for team environments
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "dynamodb-cluster/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-locking"
  # }
}