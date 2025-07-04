
# Load Balancer Kubernetes Controller
resource "helm_release" "aws-load-balancer-controller" {
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  name       = "aws-load-balancer-controller"
  version    = "1.12.0"

  namespace = "kube-system"

  wait = true

  set {
    name  = "clusterName"
    value = var.cluster_name
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = aws_subnet.dss[0].vpc_id
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.AWSLoadBalancerControllerRole.arn

  }

  depends_on = [
    aws_eks_cluster.kubernetes_cluster,
    aws_iam_role_policy_attachment.AWSLoadBalancerControllerRole,
    aws_eks_node_group.eks_node_group
  ]
}

# SSL Certificate
resource "aws_acm_certificate" "app_hostname" {
  domain_name       = var.app_hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "app_hostname_cert" {
  count                   = var.aws_route53_zone_id == "" ? 0 : 1
  certificate_arn         = aws_acm_certificate.app_hostname.arn
  validation_record_fqdns = [for name in aws_acm_certificate.app_hostname.domain_validation_options.*.resource_record_name : trimsuffix(name, ".")]
}

output "app_hostname_cert_arn" {
  value = aws_acm_certificate.app_hostname.arn
}

# Public Elastic IP for the gateway (1 per subnet)
# At the moment, worker nodes will be deployed in the same subnet, so only one elastic ip is required.
resource "aws_eip" "gateway" {
  vpc   = true
  count = 1

  tags = {
    Name = format("%s-ip-gateway", var.cluster_name)
    # Preserve mapping between ips and hostnames
    ExpectedDNS = var.app_hostname
  }
}

# Public Elastic IPs for the crdb instances
resource "aws_eip" "ip_crdb" {
  count = var.datastore_type == "cockroachdb" ? var.node_count : 0
  vpc   = true

  tags = {
    Name = format("%s-ip-crdb%v", var.cluster_name, count.index)
    # Preserve mapping between ips and hostnames
    ExpectedDNS = format("%s.%s", count.index, var.db_hostname_suffix)
  }
}

# Public Elastic IPs for the yubagybte master instances
resource "aws_eip" "ip_yugabyte_masters" {
  count = var.datastore_type == "yugabyte" ? var.node_count : 0
  vpc   = true

  tags = {
    Name = format("%s-ip-yugabyte-master%v", var.cluster_name, count.index)
    # Preserve mapping between ips and hostnames
    ExpectedDNS = format("%s.master.%s", count.index, var.db_hostname_suffix)
  }
}

# Public Elastic IPs for the yubagybte tserver instances
resource "aws_eip" "ip_yugabyte_tservers" {
  count = var.datastore_type == "yugabyte" ? var.node_count : 0
  vpc   = true

  tags = {
    Name = format("%s-ip-yugabyte-tserver%v", var.cluster_name, count.index)
    # Preserve mapping between ips and hostnames
    ExpectedDNS = format("%s.tserver.%s", count.index, var.db_hostname_suffix)
  }
}
