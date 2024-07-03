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

variable "subnet_ids" {
  description = "A list of subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "aws_region" {
  description = "The AWS region"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
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
