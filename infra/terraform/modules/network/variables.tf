variable "name_prefix" {
  description = "Prefixo dos nomes dos recursos"
  type        = string
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "Bloco CIDR da sub-rede pública"
  type        = string
}

variable "app_port" {
  description = "Porta da aplicação"
  type        = number
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado para SSH"
  type        = string
}
