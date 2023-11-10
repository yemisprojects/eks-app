
################################################################################
# OUTPUTS eks_backend
################################################################################
output "main_s3_bucket_id" {
  description = "Name of the bucket for S3 backend (ami-pipeline)"
  value       = module.eks_backend.s3_bucket_id
}

output "main_table_id" {
  description = "Name of dynamodb table for remote state (ami-pipeline)"
  value       = module.eks_backend.table_id
}
