# Public hosted zone. external-dns and cert-manager (installed via GitOps) manage
# records within this zone using their scoped IRSA roles.
resource "aws_route53_zone" "public" {
  name = var.domain_name
  tags = var.tags
}
