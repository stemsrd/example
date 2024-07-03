variable "public_subnet_id" {
  description = "The ID of the public subnet where the NAT gateway will be placed"
  type        = string
}

variable "igw_id" {
  description = "The ID of the Internet Gateway"
  type        = string
}

variable "env" {
  description = "The environment name"
  type        = string
}
