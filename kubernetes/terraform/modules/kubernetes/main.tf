resource "google_compute_network" "kube-network" {
  name                    = "kubernetes-the-hard-way"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "kube-subnet" {
  name          = "kubernetes"
  ip_cidr_range = "${var.cidr_range}"
  network       = "${google_compute_network.kube-network.self_link}"
}

resource "google_compute_firewall" "kube-internal" {
  name    = "kubernetes-the-hard-way-allow-internal"
  network = "${google_compute_network.kube-network.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]
}

resource "google_compute_firewall" "kube-external" {
  name    = "kubernetes-the-hard-way-allow-external"
  network = "${google_compute_network.kube-network.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "kube-external-address" {
  name = "kubernetes-the-hard-way"
}

#controller

resource "google_compute_instance" "kube-controller" {
  name         = "controller-${count.index}"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
  tags         = ["kubernetes-the-hard-way", "controller"]
  count        = "${var.controller_count}"

  can_ip_forward = true
  # depends_on     = ["module.kube-network"]

  # определение загрузочного диска
  boot_disk {
    initialize_params {
      image = "${var.controller_disk_image}"
      size  = "200"
    }
  }

  # определение сетевого интерфейса
  network_interface {
    # сеть, к которой присоединить данный интерфейс
    subnetwork = "${google_compute_subnetwork.kube-subnet.self_link}"
    network_ip = "10.240.0.1${count.index}"

    # использовать ephemeral IP для доступа из Интернет
    access_config {}
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

#worker
resource "google_compute_instance" "kube-worker" {
  name         = "worker-${count.index}"
  machine_type = "n1-standard-1"
  zone         = "${var.zone}"
  tags         = ["kubernetes-the-hard-way", "worker"]
  count        = "${var.worker_count}"

  can_ip_forward = true
  # depends_on     = ["module.kube-network"]

  boot_disk {
    initialize_params {
      image = "${var.worker_disk_image}"
      size  = "200"
    }
  }

  network_interface {
    subnetwork    = "${google_compute_subnetwork.kube-subnet.self_link}"
    network_ip    = "10.240.0.2${count.index}"
    access_config = {}
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata {
    pod-cidr = "10.200.${count.index}.0/24"
    ssh-keys = "appuser:${file(var.public_key_path)}"
  }

  # Подключение провиженоров к ВМ
  # connection {
  #   type  = "ssh"
  #   user  = "appuser"
  #   agent = false

  # # путь до приватного ключа
  #   private_key = "${file("~/.ssh/appuser")}"
  # }

  # provisioner "file" {
  #   source = "${path.module}/files/mongod.conf"
  #   destination = "/tmp/mongod.conf"
  # }

  # provisioner "remote-exec" {
  #   inline = ["sudo mv /tmp/mongod.conf /etc/mongod.conf", "sudo systemctl restart mongod.service"]
  # }
}

