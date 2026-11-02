variable "name_prefix" {
  description = "Prefixo dos nomes dos recursos"
  type        = string
}

variable "instance_type" {
  description = "Tipo da instância EC2"
  type        = string
}

variable "subnet_id" {
  description = "Sub-rede onde a instância será criada"
  type        = string
}

variable "security_group_id" {
  description = "Security group associado à instância"
  type        = string
}

variable "app_port" {
  description = "Porta da aplicação"
  type        = number
}

variable "key_pair_name" {
  description = "Key pair para SSH (opcional)"
  type        = string
  default     = null
}
