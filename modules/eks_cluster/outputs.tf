output "eks_cluster_id" {
  description = "The ID of the EKS cluster"
  value       = aws_eks_cluster.eks.id
}

output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = aws_eks_cluster.eks.endpoint
}

output "eks_cluster_role_arn" {
  description = "The ARN of the EKS cluster role"
  value       = aws_iam_role.eks.arn
}

output "myapp_secrets_role_arn" {
  description = "The ARN of the IAM role for myapp secrets"
  value       = aws_iam_role.myapp_secrets.arn
}
