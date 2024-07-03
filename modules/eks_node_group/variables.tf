variable "env" {
  description = "The environment name"
  type        = string
}

variable "eks_name" {
  description = "The EKS cluster name"
  type        = string
}

variable "eks_version" {
  description = "The version of EKS to use"
  type        = string
}

variable "cluster_name" {
  description = "The name of the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "A list of subnet IDs for the EKS node group"
  type        = list(string)
}
