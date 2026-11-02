variable "aws_region" {
  description = "Região AWS onde a infraestrutura será criada"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo dos recursos"
  type        = string
  default     = "minha-estante"
}

variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment deve ser dev, staging ou prod."
  }
}

variable "vpc_cidr" {
  description = "Bloco CIDR da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Bloco CIDR da sub-rede pública"
  type        = string
  default     = "10.0.1.0/24"
}

variable "instance_type" {
  description = "Tipo da instância EC2 (t3.micro é elegível ao free tier)"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "Porta em que a API Flask escuta"
  type        = number
  default     = 5000
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorizado a acessar SSH (use seu IP/32)"
  type        = string
  default     = "0.0.0.0/32"
}

variable "key_pair_name" {
  description = "Nome de um key pair já existente na AWS (opcional)"
  type        = string
  default     = null
}
