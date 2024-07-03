# Subnet module to create subnets in the VPC
module "subnet" {
  source  = "../../modules/subnet"
  vpc_id  = var.vpc_id
  zone1   = var.zone1
  zone2   = var.zone2
  env     = var.env
  eks_name = var.eks_name
}

# Configure the AWS provider
provider "aws" {
  region = var.aws_region
}

# IAM Role for the EKS Cluster
resource "aws_iam_role" "eks" {
  name = "${var.env}-${var.eks_name}-eks-cluster"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "eks.amazonaws.com"
      }
    }
  ]
}
POLICY
}

# Attach EKS Cluster Policy to the IAM Role
resource "aws_iam_role_policy_attachment" "eks" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks.name
}

# Create the EKS Cluster
resource "aws_eks_cluster" "eks" {
  name     = "${var.env}-${var.eks_name}"
  version  = var.eks_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true

    subnet_ids = var.subnet_ids
  }

  depends_on = [aws_iam_role_policy_attachment.eks]
}

# Retrieve the OIDC issuer URL for the EKS Cluster
data "tls_certificate" "eks" {
  url = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# Create an OIDC provider for the EKS Cluster
resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.eks.identity[0].oidc[0].issuer
}

# Create an EKS addon for pod identity
resource "aws_eks_addon" "pod_identity" {
  cluster_name  = aws_eks_cluster.eks.name
  addon_name    = "eks-pod-identity-agent"
  addon_version = "v1.2.0-eksbuild.1"
}

# IAM Role for the Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${aws_eks_cluster.eks.name}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ],
        Principal = {
          Service = "pods.eks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for the Cluster Autoscaler
resource "aws_iam_policy" "cluster_autoscaler" {
  name = "${aws_eks_cluster.eks.name}-cluster-autoscaler"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "autoscaling:DescribeTags",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements",
          "eks:DescribeNodegroup"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach IAM Policy to the IAM Role for Cluster Autoscaler
resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

# Associate the IAM Role with the EKS Pod Identity
resource "aws_eks_pod_identity_association" "cluster_autoscaler" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "cluster-autoscaler"
  role_arn        = aws_iam_role.cluster_autoscaler.arn
}

# Retrieve data for the EKS Cluster
data "aws_eks_cluster" "eks" {
  name = aws_eks_cluster.eks.name
}

# Retrieve authentication token for the EKS Cluster
data "aws_eks_cluster_auth" "eks" {
  name = aws_eks_cluster.eks.name
}

# Configure the Helm provider to interact with the Kubernetes cluster
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.eks.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

# Helm release for Metrics Server
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = "3.12.1"

  values = [file("${path.module}/values/metrics-server.yaml")]

  depends_on = [aws_eks_cluster.eks]
}

# Helm release for Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name = "autoscaler"

  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = "9.37.0"

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "autoDiscovery.clusterName"
    value = aws_eks_cluster.eks.name
  }
 
  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  depends_on = [helm_release.metrics_server]
}

# IAM Policy Document for AWS Load Balancer Controller
data "aws_iam_policy_document" "aws_lbc" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole",
      "sts:TagSession"
    ]
  }
}

# IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "aws_lbc" {
  name               = "${aws_eks_cluster.eks.name}-aws-lbc"
  assume_role_policy = data.aws_iam_policy_document.aws_lbc.json
}

# IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "aws_lbc" {
  policy = file("${path.module}/iam/AWSLoadBalancerController.json")
  name   = "AWSLoadBalancerController"
}

# Attach IAM Policy to the IAM Role for AWS Load Balancer Controller
resource "aws_iam_role_policy_attachment" "aws_lbc" {
  policy_arn = aws_iam_policy.aws_lbc.arn
  role       = aws_iam_role.aws_lbc.name
}

# Associate the IAM Role with the EKS Pod Identity for AWS Load Balancer Controller
resource "aws_eks_pod_identity_association" "aws_lbc" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.aws_lbc.arn
}

# Helm release for AWS Load Balancer Controller
resource "helm_release" "aws_lbc" {
  name = "aws-load-balancer-controller"

  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.eks.name
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [helm_release.cluster_autoscaler]
}

# Helm release for external NGINX Ingress Controller
resource "helm_release" "external_nginx" {
  name = "external"

  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  version          = "4.10.1"

  values = [file("${path.module}/values/nginx-ingress.yaml")]

  depends_on = [helm_release.aws_lbc]
}

# Helm release for cert-manager
resource "helm_release" "cert_manager" {
  name = "cert-manager"

  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.15.0"

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [helm_release.external_nginx]
}

# IAM Policy Document for EBS CSI Driver
data "aws_iam_policy_document" "ebs_csi_driver" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

# IAM Role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  name               = "${aws_eks_cluster.eks.name}-ebs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_driver.json
}

# Attach EBS CSI Driver Policy to IAM Role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# IAM Policy for EBS CSI Driver encryption
resource "aws_iam_policy" "ebs_csi_driver_encryption" {
  name = "${aws_eks_cluster.eks.name}-ebs-csi-driver-encryption"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:CreateGrant"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach EBS CSI Driver encryption policy to IAM Role
resource "aws_iam_role_policy_attachment" "ebs_csi_driver_encryption" {
  policy_arn = aws_iam_policy.ebs_csi_driver_encryption.arn
  role       = aws_iam_role.ebs_csi_driver.name
}

# Associate the IAM Role with the EKS Pod Identity for EBS CSI Driver
resource "aws_eks_pod_identity_association" "ebs_csi_driver" {
  cluster_name    = aws_eks_cluster.eks.name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi_driver.arn
}

# EKS addon for EBS CSI Driver
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.eks.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.31.0-eksbuild.1"
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
}

# Create an EFS file system for the EKS cluster
resource "aws_efs_file_system" "eks" {
  creation_token = "eks"

  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = true
}

# Create EFS mount target in zone A
resource "aws_efs_mount_target" "zone_a" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = module.subnet.private_subnet_zone1_id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
}

# Create EFS mount target in zone B
resource "aws_efs_mount_target" "zone_b" {
  file_system_id  = aws_efs_file_system.eks.id
  subnet_id       = module.subnet.private_subnet_zone2_id
  security_groups = [aws_eks_cluster.eks.vpc_config[0].cluster_security_group_id]
}

# IAM Policy Document for EFS CSI Driver
data "aws_iam_policy_document" "efs_csi_driver" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

# IAM Role for EFS CSI Driver
resource "aws_iam_role" "efs_csi_driver" {
  name               = "${aws_eks_cluster.eks.name}-efs-csi-driver"
  assume_role_policy = data.aws_iam_policy_document.efs_csi_driver.json
}

# Attach EFS CSI Driver Policy to IAM Role
resource "aws_iam_role_policy_attachment" "efs_csi_driver" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy"
  role       = aws_iam_role.efs_csi_driver.name
}

# Helm release for EFS CSI Driver
resource "helm_release" "efs_csi_driver" {
  name = "aws-efs-csi-driver"

  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  namespace  = "kube-system"
  version    = "3.0.5"

  set {
    name  = "controller.serviceAccount.name"
    value = "efs-csi-controller-sa"
  }

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.efs_csi_driver.arn
  }

  depends_on = [
    aws_efs_mount_target.zone_a,
    aws_efs_mount_target.zone_b
  ]
}

# Helm release for Secrets CSI Driver
resource "helm_release" "secrets_csi_driver" {
  name = "secrets-store-csi-driver"

  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.3"
 
  set {
    name  = "syncSecret.enabled"
    value = true
  }

  depends_on = [helm_release.efs_csi_driver]
}

# Helm release for AWS Provider for Secrets CSI Driver
resource "helm_release" "secrets_csi_driver_aws_provider" {
  name = "secrets-store-csi-driver-provider-aws"

  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.9"

  depends_on = [helm_release.secrets_csi_driver]
}

# IAM Policy Document for application secrets
data "aws_iam_policy_document" "myapp_secrets" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:12-example:myapp"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
      type        = "Federated"
    }
  }
}

# IAM Role for application secrets
resource "aws_iam_role" "myapp_secrets" {
  name               = "${aws_eks_cluster.eks.name}-myapp-secrets"
  assume_role_policy = data.aws_iam_policy_document.myapp_secrets.json
}

# IAM Policy for application secrets
resource "aws_iam_policy" "myapp_secrets" {
  name = "${aws_eks_cluster.eks.name}-myapp-secrets"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach IAM Policy to the IAM Role for application secrets
resource "aws_iam_role_policy_attachment" "myapp_secrets" {
  policy_arn = aws_iam_policy.myapp_secrets.arn
  role       = aws_iam_role.myapp_secrets.name
}

# Retrieve data for the EKS Cluster (version 2)
data "aws_eks_cluster" "eks_v2" {
  name = aws_eks_cluster.eks.name
}

# Retrieve authentication token for the EKS Cluster (version 2)
data "aws_eks_cluster_auth" "eks_v2" {
  name = aws_eks_cluster.eks.name
}

# Configure the Kubernetes provider to interact with the EKS cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_v2.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_v2.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_v2.token
}

# Create a Kubernetes StorageClass for EFS
resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"

  parameters = {
    provisioningMode = "efs-ap"
    fileSystemId     = aws_efs_file_system.eks.id
    directoryPerms   = "700"
  }

  mount_options = ["iam"]

  depends_on = [helm_release.efs_csi_driver]
}
