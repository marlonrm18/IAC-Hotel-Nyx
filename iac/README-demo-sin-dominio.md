# Demo sin dominio propio (`enable_custom_domain`)

Hotel Nyx puede desplegarse **sin ser dueños de `hotelnyx.com`**, usando solo los
endpoints nativos de AWS. Todo está controlado por una única variable booleana:

```hcl
# terraform.tfvars
enable_custom_domain = false   # demo (por defecto)
# enable_custom_domain = true  # producción, con el dominio ya delegado a Route53
```

| Valor                         | Frontend                         | API                                  | ALB           | SES / correo |
|-------------------------------|----------------------------------|--------------------------------------|---------------|--------------|
| `false` (demo, **default**)   | `https://<id>.cloudfront.net`    | `https://<id>.execute-api.<region>.amazonaws.com` | listener HTTP 80 | desactivado |
| `true` (futuro / producción)  | `https://hotelnyx.com`           | `https://api.hotelnyx.com`           | listener HTTPS 443 (ACM) | activo |

> La variable raíz `var.domain_name` sigue existiendo y se usa como **referencia
> lógica** (env vars de ECS `DOMAIN_NAME`/`MAIL_FROM`/`APP_BASE_URL`, ARNs de IAM
> para SES). Eso no bloquea el `apply`; solo la capa de DNS/cert se desactiva.

---

## Qué se desconecta con `enable_custom_domain = false`

Cambios **mínimos, condicionales y reversibles** (solo capa dominio/DNS/cert).
La VPC, ECS, RDS, security groups, KMS, ECR, Cognito y monitoring **no se tocan**.

| # | Módulo        | Con dominio (`true`)                                   | Demo (`false`)                                              |
|---|---------------|-------------------------------------------------------|------------------------------------------------------------|
| 1 | `route53`     | Crea la hosted zone                                   | No crea zona; `zone_id` output = `""`                       |
| 2 | `alb`         | Cert ACM regional + validación DNS                    | Sin cert ni registros de validación                        |
| 3 | `alb`         | Listener 80 → redirect 443; **HTTPS 443** con las reglas | Listener **HTTP 80** es el principal y aloja las reglas |
| 4 | `frontend`    | Cert ACM us-east-1 + alias `hotelnyx.com`/`www` + records | Dominio `*.cloudfront.net` + `CloudFrontDefaultCertificate`, sin aliases ni records |
| 5 | `api_gateway` | Custom domain `api.hotelnyx.com` + mapping + alias DNS | Endpoint nativo `execute-api`; integración al ALB por **HTTP** |
| 6 | `ses`         | Identidad de dominio + DKIM + MAIL FROM + records      | Todo omitido (sin verificación posible). El **VPC endpoint de SES se mantiene** |

### Notas de diseño

- **ALB en HTTP (demo):** CloudFront y API Gateway ponen HTTPS por delante; el
  tramo API Gateway → ALB viaja por HTTP. El SG del ALB ya permitía el puerto 80.
- **Integración API Gateway → ALB:** `integration_uri` pasa de `https://` a
  `http://<alb_dns>` automáticamente según la variable.
- **CloudFront:** con el cert por defecto **no** se pueden fijar
  `ssl_support_method` ni `minimum_protocol_version` (se ponen a `null`).

---

## Ajustes Tipo 2 (post-apply) — pendientes en la demo

Estos valores dependen de URLs *known-after-apply*; se rellenan **después** del
primer `apply`, igual que `config.js`:

1. **`config.js` del frontend** → usar el output `cloudfront_domain_name`
   (`*.cloudfront.net`) como base de la API: el output `api_gateway_endpoint`
   (`execute-api`).
2. **Cognito** (`cognito_callback_urls` / `cognito_logout_urls`): hoy apuntan a
   `https://hotelnyx.com/...`. Para que la hosted UI funcione en la demo, tras el
   apply hay que actualizarlas a la URL real de CloudFront. Se puede hacer por
   consola o pasando las URLs por `-var` y re-aplicando. No bloquea el `apply`.
3. **`mp_notification_url`** (webhook Mercado Pago): rellenar con
   `<api_gateway_endpoint>/api/pagos/webhook` tras el apply.
4. **ECS env vars** (`APP_BASE_URL`, `MAIL_FROM`): siguen con `hotelnyx.com`. El
   correo SES no funciona en demo (no es bloqueante).

---

## Outputs de URL a usar tras el `apply` (demo)

```bash
terraform output cloudfront_domain_name   # https://<id>.cloudfront.net  → frontend
terraform output api_gateway_endpoint     # https://<id>.execute-api...  → API
```

---

## Cómo reactivar el dominio (futuro)

1. Registrar/poseer el dominio y delegar los NS a la hosted zone de Route53.
2. Poner `enable_custom_domain = true` en `terraform.tfvars`.
3. `terraform apply` — se crean hosted zone, certs ACM (se validan solos por DNS),
   custom domain de API Gateway, aliases de CloudFront, listener HTTPS y SES.
4. Tomar los name servers de `terraform output route53_name_servers` y delegarlos
   en el registrar.
5. Revertir los ajustes Tipo 2 a los dominios reales (`config.js`, Cognito,
   `mp_notification_url`).

No hay que tocar código: todo el comportamiento depende de la variable.
