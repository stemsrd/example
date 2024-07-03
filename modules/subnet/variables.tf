variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "zone1" {
  description = "The first availability zone"
  type        = string
}

variable "zone2" {
  description = "The second availability zone"
  type        = string
}

variable "env" {
  description = "The environment name"
  type        = string
}

variable "eks_name" {
  description = "The EKS cluster name"
  type        = string
}
