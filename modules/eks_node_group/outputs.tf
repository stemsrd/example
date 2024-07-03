output "eks_node_group_id" {
  description = "The ID of the EKS node group"
  value       = aws_eks_node_group.general.id
}

output "eks_node_group_role_arn" {
  description = "The ARN of the EKS node group role"
  value       = aws_iam_role.nodes.arn
}
