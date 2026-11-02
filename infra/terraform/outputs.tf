output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.network.vpc_id
}

output "instance_id" {
  description = "ID da instância EC2"
  value       = module.compute.instance_id
}

output "app_url" {
  description = "URL pública da API"
  value       = "http://${module.compute.public_ip}:${var.app_port}"
}
