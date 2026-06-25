output "zone_id" {
  description = "ID de la hosted zone Route 53 (vacío si enable_custom_domain = false)"
  value       = var.enable_custom_domain ? aws_route53_zone.main[0].zone_id : ""
}

output "name_servers" {
  description = "Name servers de la hosted zone (vacío si enable_custom_domain = false)"
  value       = var.enable_custom_domain ? aws_route53_zone.main[0].name_servers : []
}
