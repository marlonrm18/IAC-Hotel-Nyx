# ─── SES Domain Identity ──────────────────────────────────────────────────────
# La verificación DNS puede tardar hasta 72 h; Terraform solo crea los recursos.
# No se usa aws_ses_domain_identity_verification para no bloquear el apply.

# DEMO (enable_custom_domain = false): toda la identidad de dominio SES y sus
# registros DNS se omiten — sin el dominio propio no se pueden verificar y, además,
# no existe la hosted zone. El envío de correos no funcionará en la demo (no es
# bloqueante para el apply). El VPC endpoint de SES (más abajo) se mantiene.

resource "aws_ses_domain_identity" "main" {
  count  = var.enable_custom_domain ? 1 : 0
  domain = var.domain_name
}

resource "aws_route53_record" "ses_verification" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "_amazonses.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = [aws_ses_domain_identity.main[0].verification_token]
}

# ─── DKIM ─────────────────────────────────────────────────────────────────────
# SES genera 3 tokens; cada uno requiere su propio registro CNAME.

resource "aws_ses_domain_dkim" "main" {
  count  = var.enable_custom_domain ? 1 : 0
  domain = aws_ses_domain_identity.main[0].domain
}

resource "aws_route53_record" "ses_dkim" {
  count   = var.enable_custom_domain ? 3 : 0
  zone_id = var.route53_zone_id
  name    = "${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type    = "CNAME"
  ttl     = 600
  records = ["${aws_ses_domain_dkim.main[0].dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# ─── MAIL FROM personalizado: mail.hotelnyx.com ───────────────────────────────
# Evita que el sobre From muestre amazonses.com, mejora la entregabilidad y
# habilita alineación DMARC (same-domain alignment).

resource "aws_ses_domain_mail_from" "main" {
  count            = var.enable_custom_domain ? 1 : 0
  domain           = aws_ses_domain_identity.main[0].domain
  mail_from_domain = "mail.${var.domain_name}"

  # Si falla el lookup MX del subdominio, SES vuelve al dominio raíz en vez de
  # rechazar el mensaje — comportamiento seguro para no perder correos.
  behavior_on_mx_failure = "UseDefaultValue"
}

resource "aws_route53_record" "ses_mail_from_mx" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "mail.${var.domain_name}"
  type    = "MX"
  ttl     = 600
  records = ["10 feedback-smtp.${var.aws_region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "mail.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=spf1 include:amazonses.com -all"]
}

# ─── DMARC ────────────────────────────────────────────────────────────────────
# Política p=none en dev/staging (solo monitoreo); cambiar a p=quarantine/reject
# en producción tras revisar los reportes en alert_email.

resource "aws_route53_record" "dmarc" {
  count   = var.enable_custom_domain ? 1 : 0
  zone_id = var.route53_zone_id
  name    = "_dmarc.${var.domain_name}"
  type    = "TXT"
  ttl     = 600
  records = ["v=DMARC1; p=none; rua=mailto:${var.alert_email}"]
}

# ─── VPC Interface Endpoint: SES ─────────────────────────────────────────────
# OJO: "com.amazonaws.<region>.ses" NO existe como servicio PrivateLink (el apply
# falla con "service ... does not exist"). SES solo publica el endpoint SMTP
# "com.amazonaws.<region>.email-smtp" (puertos 465/587), que no sirve para el SDK
# de la API SES sobre 443 — ese trafico debe salir por NAT (egress 443 ya
# permitido en el SG de ECS). Por eso el endpoint se omite en demo y queda
# condicionado a enable_custom_domain, igual que el resto del modulo SES.
# Para reactivarlo en el futuro hay que elegir un service_name valido (p. ej.
# email-smtp con sus puertos) o dejar el trafico SES por NAT.

resource "aws_vpc_endpoint" "ses" {
  count = var.enable_custom_domain ? 1 : 0

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.email-smtp"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [var.vpc_endpoints_sg_id]
  private_dns_enabled = true

  tags = { Name = "${var.project}-${var.environment}-vpce-ses" }
}
