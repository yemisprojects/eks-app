data "aws_availability_zones" "available" {}
# data "aws_caller_identity" "current" {}

locals {

  name = "ex-${replace(basename(path.cwd), "_", "-")}"
  azs  = slice(data.aws_availability_zones.available.names, 0, 2)

  tags = {
    environment = var.environment
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0"

  name = var.vpc_name
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 4, k)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 8, k + 48)]

  enable_nat_gateway = var.vpc_enable_nat_gateway
  single_nat_gateway = var.vpc_single_nat_gateway

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "Type"                   = "public-subnets"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # Tags subnets for Karpenter auto-discovery
    "karpenter.sh/discovery" = local.name
    "Type"                   = "private-subnet"

  }

  tags                    = local.tags
  map_public_ip_on_launch = true
}
