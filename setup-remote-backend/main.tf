################################################################################
# REMOTE BACKEND FOR EKS INFRASTRUCTURE
################################################################################
module "eks_backend" {
  source = "../modules/setup-backend"

  table_name  = "prod-eks-cluster"
  bucket_name = "eks-infra-tfstate-${random_integer.this.id}"
}

resource "random_integer" "this" {
  min = 100000000000
  max = 999999999999
}
