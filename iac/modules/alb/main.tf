# ─── ACM Certificate (regional, us-east-2) ───────────────────────────────────
# Cubre hotelnyx.com y *.hotelnyx.com → sirve al ALB y al API Gateway Regional.
# El cert de CloudFront (us-east-1) va en el módulo frontend con el provider alias
# y reutiliza los mismos registros CNAME de validación (output cert_validation_fqdns).
#
# DEMO (enable_custom_domain = false): no se crea el certificado ni sus registros
# de validación — sin dominio propio no se puede validar contra Route53 y el apply
# se colgaría. El listener pasa a HTTP (ver más abajo).

resource "aws_acm_certificate" "main" {
  count = var.enable_custom_domain ? 1 : 0

  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project}-${var.environment}-cert-main"
  }
}

# Registros CNAME de validación DNS — uno por entrada única en domain_validation_options.
resource "aws_route53_record" "cert_validation" {
  for_each = var.enable_custom_domain ? {
    for dvo in aws_acm_certificate.main[0].domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

resource "aws_acm_certificate_validation" "main" {
  count = var.enable_custom_domain ? 1 : 0

  certificate_arn         = aws_acm_certificate.main[0].arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ─── Application Load Balancer ────────────────────────────────────────────────

# checkov:skip=CKV2_AWS_20:En modo demo sin dominio el ALB solo expone HTTP; sin certificado ACM no hay listener HTTPS 443 al cual redirigir. La redireccion HTTP->HTTPS se habilita con enable_custom_domain=true (produccion).
resource "aws_lb" "main" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  # Solucion al fallo de checkov "CKV_AWS_150"
  # Nota adicional: cuando destruyamos cambiar a false si no, no destruira el ALB
  enable_deletion_protection = false
  # Solucion al fallo CKV_AWS_131 : revisara tdos los headers y eliminara los que no sean validos, si no se pone a true, el ALB puede rechazar peticiones con headers invalidos(caracteres o espacios invalidos)
  drop_invalid_header_fields = true

  dynamic "access_logs" {
    for_each = var.alb_access_logs_bucket != "" ? [1] : []
    content {
      bucket  = var.alb_access_logs_bucket
      prefix  = "${var.project}/${var.environment}/alb"
      enabled = true
    }
  }

  tags = {
    Name = "${var.project}-${var.environment}-alb"
  }
}

# ─── Target Group: svc-reservas ───────────────────────────────────────────────

resource "aws_lb_target_group" "reservas" {
  name        = "${var.project}-${var.environment}-tg-reservas"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "${var.project}-${var.environment}-tg-reservas"
    Service = "svc-reservas"
  }
}

# ─── Target Group: svc-pagos ──────────────────────────────────────────────────

resource "aws_lb_target_group" "pagos" {
  name        = "${var.project}-${var.environment}-tg-pagos"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = var.alb_health_check_path
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-299"
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name    = "${var.project}-${var.environment}-tg-pagos"
    Service = "svc-pagos"
  }
}

# ─── Listener: HTTP 80 ────────────────────────────────────────────────────────
# Con dominio (enable_custom_domain = true): redirect permanente 80 → 443.
# En demo (false): este listener es el principal — responde 404 por defecto y
# alberga las reglas de path-based routing. CloudFront / API Gateway ponen el
# HTTPS por delante; el tramo API Gateway → ALB viaja por HTTP en la demo.

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  dynamic "default_action" {
    for_each = var.enable_custom_domain ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }

  dynamic "default_action" {
    for_each = var.enable_custom_domain ? [] : [1]
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "application/json"
        message_body = jsonencode({ error = "not found" })
        status_code  = "404"
      }
    }
  }
}

# ─── Listener: HTTPS 443 ──────────────────────────────────────────────────────
# Política TLS: soporta TLS 1.2 y TLS 1.3, elimina cifrados débiles.
# Solo existe cuando hay certificado ACM (enable_custom_domain = true).

resource "aws_lb_listener" "https" {
  count = var.enable_custom_domain ? 1 : 0

  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.main[0].certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "application/json"
      message_body = jsonencode({ error = "not found" })
      status_code  = "404"
    }
  }
}

# Listener activo donde cuelgan las reglas: HTTPS si hay dominio, HTTP en demo.
locals {
  routing_listener_arn = var.enable_custom_domain ? aws_lb_listener.https[0].arn : aws_lb_listener.http.arn
}

# ─── Reglas de ruteo por path ─────────────────────────────────────────────────

resource "aws_lb_listener_rule" "reservas" {
  listener_arn = local.routing_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.reservas.arn
  }

  condition {
    path_pattern {
      values = var.alb_reservas_path_patterns
    }
  }
}

resource "aws_lb_listener_rule" "pagos" {
  listener_arn = local.routing_listener_arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pagos.arn
  }

  condition {
    path_pattern {
      values = var.alb_pagos_path_patterns
    }
  }
}
