locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

module "network" {
  source = "./modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  app_port           = var.app_port
  ssh_allowed_cidr   = var.ssh_allowed_cidr
}

module "compute" {
  source = "./modules/compute"

  name_prefix       = local.name_prefix
  instance_type     = var.instance_type
  subnet_id         = module.network.public_subnet_id
  security_group_id = module.network.app_security_group_id
  app_port          = var.app_port
  key_pair_name     = var.key_pair_name
}
