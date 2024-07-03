# Define local variables for environment settings
locals {
  env         = "staging"
  region      = "eu-central-1"
  zone1       = "eu-central-1a"
  zone2       = "eu-central-1b"
  eks_name    = "example"
  eks_version = "1.30"
}

# Configure the AWS provider
provider "aws" {
  region = local.region
}

# Specify Terraform settings and provider requirements
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.53"
    }
  }
}

# VPC module to create a Virtual Private Cloud
module "vpc" {
  source      = "../../modules/vpc"
  cidr_block  = "10.0.0.0/16"
  env         = local.env
}

# Internet Gateway module for enabling internet access
module "internet_gateway" {
  source = "../../modules/internet_gateway"
  vpc_id = module.vpc.vpc_id
  env    = local.env
}

# Subnet module to create subnets in the VPC
module "subnet" {
  source   = "../../modules/subnet"
  vpc_id   = module.vpc.vpc_id
  zone1    = local.zone1
  zone2    = local.zone2
  env      = local.env
  eks_name = local.eks_name
}

# NAT Gateway module for outbound internet traffic
module "nat_gateway" {
  source           = "../../modules/nat_gateway"
  public_subnet_id = module.subnet.public_subnet_zone1_id
  igw_id           = module.internet_gateway.igw_id
  env              = local.env
}

# Route Table module for routing traffic
module "route_table" {
  source                   = "../../modules/route_table"
  vpc_id                   = module.vpc.vpc_id
  nat_gateway_id           = module.nat_gateway.nat_gateway_id
  igw_id                   = module.internet_gateway.igw_id
  private_subnet_zone1_id  = module.subnet.private_subnet_zone1_id
  private_subnet_zone2_id  = module.subnet.private_subnet_zone2_id
  public_subnet_zone1_id   = module.subnet.public_subnet_zone1_id
  public_subnet_zone2_id   = module.subnet.public_subnet_zone2_id
  env                      = local.env
}

# EKS Cluster module to create an Amazon EKS cluster
module "eks_cluster" {
  source      = "../../modules/eks_cluster"
  env         = local.env
  eks_name    = local.eks_name
  eks_version = local.eks_version
  subnet_ids  = [
    module.subnet.private_subnet_zone1_id,
    module.subnet.private_subnet_zone2_id
  ]
  aws_region  = local.region
  vpc_id      = module.vpc.vpc_id
  zone1       = local.zone1
  zone2       = local.zone2
}

# EKS Node Group module to create node groups in the EKS cluster
module "eks_node_group" {
  source       = "../../modules/eks_node_group"
  env          = local.env
  eks_name     = local.eks_name
  eks_version  = local.eks_version
  cluster_name = module.eks_cluster.eks_cluster_id
  subnet_ids   = [
    module.subnet.private_subnet_zone1_id,
    module.subnet.private_subnet_zone2_id
  ]
}
