# Hotel Nyx — Sistema de Reservas de Habitaciones

UPAO · Ingeniería de Sistemas e Inteligencia Artificial
- Curso: Infraestructura como Código 
- Docente: Walter Ivan Leturia Rodriguez
#### Grupo 5
- Rivas Machuca, Marlon Sebastian
- Toribio Flores, Joe Alexis

Sistema de reservas hoteleras desplegado en AWS con Terraform, incluyendo frontend estático servido por CloudFront y backend con ECS, API Gateway, RDS PostgreSQL, Cognito y SES. Región: us-east-2.

---

## Requisitos previos

- AWS CLI configurado con credenciales válidas y región `us-east-2`
- Terraform >= 1.x instalado

---

## Paso 1 — Bootstrap

Solo se ejecuta una vez. Crea el bucket S3 de estado remoto y la tabla DynamoDB de locks.

```bash
cd iac/bootstrap
copy terraform.tfvars.example terraform.tfvars
# name_suffix = "hotelnyx-marlon-joe-2026"
terraform init
terraform plan
terraform apply
```

Recursos creados:
- S3 bucket `hotel-nyx-tfstate-hotelnyx-marlon-joe-2026` — versionado, cifrado AES256, bloqueado al público
- DynamoDB table `hotel-nyx-tflocks` — PAY_PER_REQUEST, clave LockID

---

## Paso 2 — Infraestructura principal

```bash
cd iac
copy backend.hcl.example backend.hcl
terraform init -backend-config backend.hcl
terraform plan
terraform apply
```

---

## Paso 3 — Desplegar el frontend

```bash
aws s3 sync app/frontend s3://hotel-nyx-dev-frontend-978850043984 --delete
```

---

## Paso 4 — Invalidar cache de CloudFront

```bash
aws cloudfront create-invalidation --distribution-id E3BLJYM49TIJP0 --paths "/*"
```

Esperar 1-2 minutos. La web queda disponible en:

```
https://d17vxoaph6y320.cloudfront.net
```

Nota: entregable Semana 12 presentado sin dominio personalizado, pendiente de adquisicion.

---

## Teardown

```bash
cd iac
terraform destroy
```

El bucket de estado y la tabla DynamoDB del bootstrap se eliminan manualmente si es necesario.

---

## Arquitectura AWS (us-east-2)

| Servicio            | Uso                              |
|---------------------|----------------------------------|
| S3 + CloudFront     | Frontend estático con CDN        |
| ECS Fargate         | Backend containerizado           |
| API Gateway         | Endpoints REST                   |
| RDS PostgreSQL      | Base de datos de reservas        |
| Cognito             | Autenticación de usuarios        |
| SES                 | Emails de confirmación           |
| CloudWatch          | Monitoreo y logs                 |
```
