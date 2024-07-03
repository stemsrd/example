variable "aws_region" {
  description = "The AWS region to deploy in"
  type        = string
  default     = "eu-central-1"
}

variable "eks_version" {
  description = "The version of EKS to use"
  type        = string
  default     = "1.30"
}
