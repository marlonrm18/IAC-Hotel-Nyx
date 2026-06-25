output "domain_identity_arn" {
  description = "ARN de la identidad de dominio SES (vacío si enable_custom_domain = false)"
  value       = var.enable_custom_domain ? aws_ses_domain_identity.main[0].arn : ""
}

output "verification_token" {
  description = "Token TXT de verificación SES (vacío si enable_custom_domain = false)"
  value       = var.enable_custom_domain ? aws_ses_domain_identity.main[0].verification_token : ""
}

output "mail_from_domain" {
  description = "Subdominio MAIL FROM configurado para SES (vacío si enable_custom_domain = false)"
  value       = var.enable_custom_domain ? aws_ses_domain_mail_from.main[0].mail_from_domain : ""
}

output "vpc_endpoint_id" {
  description = "ID del VPC Interface Endpoint de SES (vacío si enable_custom_domain = false)"
  value       = var.enable_custom_domain ? aws_vpc_endpoint.ses[0].id : ""
}

output "vpc_endpoint_dns" {
  description = "DNS privado del endpoint SES (vacío si enable_custom_domain = false)"
  value       = var.enable_custom_domain ? aws_vpc_endpoint.ses[0].dns_entry[0]["dns_name"] : ""
}
