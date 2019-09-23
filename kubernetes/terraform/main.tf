### KUBERNETES ###
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

module "kubernetes" {
  source = "modules/kubernetes"
  # Common vars
  public_key_path       = "${var.public_key_path}"
  zone                  = "${var.zone}"
  region = "${var.region}"

  # Controller vars
  controller_disk_image = "${var.disk_image}"
  controller_count        = "${var.kube_controller_count}"

  # worker vars
  worker_disk_image = "${var.disk_image}"
  worker_count    = "${var.kube_worker_count}"
}
