variable "project" {
  description = "Nombre del proyecto, usado en tags y nombres de recursos"
  type        = string
}

variable "environment" {
  description = "Nombre del ambiente de despliegue"
  type        = string
}

variable "domain_name" {
  description = "Dominio raíz del proyecto (nombre de la hosted zone)"
  type        = string
}

variable "enable_custom_domain" {
  description = "Crear la hosted zone. false (demo) = no se crea ninguna zona."
  type        = bool
}
