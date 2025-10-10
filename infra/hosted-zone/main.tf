variable "domain_name" {}
variable "aws_lb_dns_name" {}
variable "aws_lb_zone_id" {}

data "aws_route53_zone" "dc_llc_dv_site" {
  name         = "devops-portfolio.site"
  private_zone = false
}

# Creating an A record
resource "aws_route53_record" "lb_record" {
  zone_id = data.aws_route53_zone.dc_llc_dv_site.id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.aws_lb_dns_name
    zone_id                = var.aws_lb_zone_id
    evaluate_target_health = true
  }
}

output "hosted_zone_id" {
  value = data.aws_route53_zone.dc_llc_dv_site.zone_id
}
