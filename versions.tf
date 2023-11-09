terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.65"
    }
    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = ">= 2.10"
    # }
  }

  #   backend "s3" {
  #     bucket = "terraform-on-aws-eks"
  #     key    = "dev/eks-cluster/terraform.tfstate"
  #     region = "us-east-1" 

  #     dynamodb_table = "dev-ekscluster"    
  #   }  
}

provider "aws" {
  region = var.aws_region
}
