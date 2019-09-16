### STAGE ###
terraform {
  # версия terraform
  required_version = "~> 0.11.7"
}

provider "google" {
  # Версия провайдера
  version = "2.0.0"

  # id проекта
  project = "${var.project}"

  region = "${var.region}"
}

module "kube-network" {
  source = "modules/kube-network"
  
}

module "kube-controller" {
  source          = "modules/kube-controller"
  public_key_path = "${var.public_key_path}"
  zone            = "${var.zone}"
  controller_disk_image  = "${var.disk_image}"
  instance_count  = "${var.kube_controller_count}"
}

# module "db" {
#   source          = "../modules/db"
#   public_key_path = "${var.public_key_path}"
#   zone            = "${var.zone}"
#   db_disk_image   = "${var.db_disk_image}"
# }

