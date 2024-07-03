variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "nat_gateway_id" {
  description = "The ID of the NAT gateway"
  type        = string
}

variable "igw_id" {
  description = "The ID of the Internet Gateway"
  type        = string
}

variable "private_subnet_zone1_id" {
  description = "The ID of the private subnet in zone 1"
  type        = string
}

variable "private_subnet_zone2_id" {
  description = "The ID of the private subnet in zone 2"
  type        = string
}

variable "public_subnet_zone1_id" {
  description = "The ID of the public subnet in zone 1"
  type        = string
}

variable "public_subnet_zone2_id" {
  description = "The ID of the public subnet in zone 2"
  type        = string
}

variable "env" {
  description = "The environment name"
  type        = string
}
