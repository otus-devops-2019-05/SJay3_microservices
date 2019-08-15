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

resource "google_compute_instance" "docker" {
  name = "docker-tf-host-${count.index + 1}"
  machine_type = "${var.machine_type}"
  zone = "${var.zone}"
  tags = ["docker-host"]
  count = "${var.instance_count}"

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = "${var.docker_disk_image}"
      size = "${var.docker_disk_size}"
    }
  }

  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    network = "default"

    # использовать ephemeral IP для доступа из Интернет
    access_config {
      nat_ip = "${google_compute_address.docker_ip.address}"
    }
  }

  metadata {
    # Путь до публичного ключа
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

}

resource "google_compute_address" "docker_ip" {
  name = "docker-tf-host-ip-${count.index + 1}"
}

resource "google_compute_firewall" "docker_http" {
  count = "${var.enable_web_traffic ? 1 : 0}" # Если переменная false ресурс не будет создан
  name = "allow-docker-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags = ["docker-host"]
}
