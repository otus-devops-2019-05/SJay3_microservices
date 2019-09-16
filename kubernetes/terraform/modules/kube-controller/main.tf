#controller

resource "google_compute_instance" "kube-controller" {
  name         = "controller-${count.index}"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
  tags         = ["kubernetes-the-hard-way", "controller"]
  count        = "${var.instance_count}"

  can_ip_forward = true

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = "${var.controller_disk_image}"
      size = "200"
    }
  }

  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    subnetwork = "kubernetes"
    network_ip = "10.240.0.1${count.index}"

    # использовать ephemeral IP для доступа из Интернет
    access_config {

    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata {
    # Путь до публичного ключа
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

  # # Подключение провиженоров к ВМ
  # connection {
  #   type  = "ssh"
  #   user  = "appuser"
  #   agent = false

  # # путь до приватного ключа
  #   private_key = "${file("~/.ssh/appuser")}"
  # }

  # provisioner "file" {
  #   content      = "${data.template_file.puma_service.rendered}"
  #   destination = "/tmp/puma.service"
  # }

  # provisioner "remote-exec" {
  #   script = "${path.module}/files/deploy.sh"
  # }
}

