data "aws_availability_zones" "available" {}

locals {
  cluster_name = "${var.cluster_name}-${var.environment}"
  azs          = slice(data.aws_availability_zones.available.names, 0, 2)
  tags = {
    environment = var.environment
  }
}

################################################################################
# EKS VPC
################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0"

  name = "${var.vpc_name}-${var.environment}"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = var.vpc_private_subnets
  public_subnets  = var.vpc_public_subnets

  map_public_ip_on_launch = true
  enable_nat_gateway      = var.vpc_enable_nat_gateway
  single_nat_gateway      = var.vpc_single_nat_gateway

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
    "Type"                   = "public-subnet"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"              = 1
    "karpenter.sh/discovery/${local.cluster_name}" = local.cluster_name
    "kubernetes.io/cluster/${local.cluster_name}"  = local.cluster_name
    "Type"                                         = "private-subnet"
  }

  tags = local.tags
}

################################################################################
# EKS CLUSTER
################################################################################
module "eks" {
  source  = "registry.terraform.io/terraform-aws-modules/eks/aws"
  version = "19.17.4"

  cluster_name                         = local.cluster_name
  cluster_version                      = var.cluster_version
  cluster_enabled_log_types            = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  vpc_id                               = module.vpc.vpc_id
  subnet_ids                           = [module.vpc.private_subnets]
  control_plane_subnet_ids             = [module.vpc.public_subnets]
  enable_irsa                          = true
  cluster_endpoint_private_access      = var.cluster_endpoint_private_access
  cluster_endpoint_public_access       = var.cluster_endpoint_public_access
  cluster_ip_family                    = "ipv4"
  cluster_service_ipv4_cidr            = var.cluster_service_ipv4_cidr
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  kms_key_deletion_window_in_days        = 7
  cloudwatch_log_group_retention_in_days = 1
  manage_aws_auth_configmap              = true
  create_iam_role                        = true
  iam_role_name                          = "eks-cluster-role"
  create_cluster_security_group          = true


  cluster_addons = {
    coredns = {
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts_on_update = "OVERWRITE"
    }
    aws-ebs-csi-driver = {
      resolve_conflicts_on_update = "OVERWRITE"
    }
  }

  # cluster_security_group_additional_rules = {
  #   egress_nodes_ephemeral_ports_tcp = {
  #     description                = "Egress Allowed 1025-65535"
  #     protocol                   = "tcp"
  #     from_port                  = 1025
  #     to_port                    = 65535
  #     type                       = "egress"
  #     source_node_security_group = true
  #   }
  #   ingress_nodes_karpenter_ports_tcp = {
  #     description                = "Karpenter required port"
  #     protocol                   = "tcp"
  #     from_port                  = 8443
  #     to_port                    = 8443
  #     type                       = "ingress"
  #     source_node_security_group = true
  #   }
  # }

  # node_security_group_additional_rules = {

  #   ingress_self_all = {
  #     description = "Self allow all ingress"
  #     protocol    = "-1"
  #     from_port   = 0
  #     to_port     = 0
  #     type        = "ingress"
  #     self        = true
  #   }

  #   egress_all = {
  #     description      = "Egress allow all"
  #     protocol         = "-1"
  #     from_port        = 0
  #     to_port          = 0
  #     type             = "egress"
  #     cidr_blocks      = ["0.0.0.0/0"]
  #     ipv6_cidr_blocks = ["::/0"]
  #   }

  # }

  cluster_timeouts = {
    create = "60m"
    delete = "30m"
  }

  tags = {
    "karpenter.sh/discovery/${local.cluster_name}" = local.cluster_name
  }

}

################################################################################
# EKS PRIVATE MANAGED NODE GROUP
################################################################################
module "eks_managed_node_group" {
  source = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"

  name                              = "eks-ng-private"
  cluster_name                      = local.cluster_name
  cluster_version                   = var.cluster_version
  ami_type                          = "AL2_x86_64"
  disk_size                         = 20
  min_size                          = 1
  max_size                          = 1
  desired_size                      = 1
  instance_types                    = ["t3.medium"]
  capacity_type                     = "ON_DEMAND"
  iam_role_name                     = "eks-nodegroup-role"
  subnet_ids                        = module.vpc.private_subnets
  vpc_security_group_ids            = [module.eks.node_security_group_id]
  cluster_primary_security_group_id = module.eks.cluster_primary_security_group_id
  iam_role_additional_policies = {
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
    AmazonSSMManagedInstanceCore   = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    AmazonEBSCSIDriverPolicy       = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  }

  tags = {
    Environment                                    = "dev"
    Name                                           = "Private-Node-Group"
    "karpenter.sh/discovery/${local.cluster_name}" = local.cluster_name
  }

}

################################################################################
# EKS CLUSTER ADD-ONS
################################################################################
/*module "kubernetes_addons" {
  source = "github.com/aws-ia/terraform-aws-eks-blueprints//modules/kubernetes-addons?ref=v4.32.1"
  eks_cluster_id               = module.eks.cluster_name
  eks_cluster_endpoint         = module.eks.cluster_endpoint
  eks_oidc_provider            = module.eks.oidc_provider
  eks_cluster_version          = local.cluster_version
  eks_worker_security_group_id = module.eks.node_security_group_id

  enable_aws_load_balancer_controller = true
  enable_metrics_server               = true
  enable_cluster_autoscaler           = false

  enable_karpenter = true
  karpenter_helm_config = {
    name       = "karpenter"
    chart      = "karpenter"
    repository = "oci://public.ecr.aws/karpenter"
    version    = "v0.30.0"
    namespace  = "karpenter"
  }
}*/
