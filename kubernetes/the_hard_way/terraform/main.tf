provider "yandex" {
  service_account_key_file = var.service_account_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
module "network" {
  source = "./modules/network"
}
module "masters" {
  source          = "./modules/masters"
  public_key_path = var.public_key_path
  subnet_id       = module.network.subnet_id
  masters_count   = var.masters_count
}
module "workers" {
  source          = "./modules/workers"
  public_key_path = var.public_key_path
  subnet_id       = module.network.subnet_id
  workers_count   = var.workers_count
}
module "target_group" {
  source          = "./modules/target_group"
  subnet_id       = module.network.subnet_id
  masters_ips     = module.masters.ips
}
module "lb" {
  source          = "./modules/lb"
  static_ip       = "84.201.159.56"
  target_group_id = module.target_group.id
}
