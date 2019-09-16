resource "google_compute_network" "kube-network" {
  name = "kubernetes-the-hard-way"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "kube-subnet" {
  name = "kubernetes"
  ip_cidr_range = "${var.cidr_range}"
  network = "${google_compute_network.kube-network.self_link}"
}

resource "google_compute_firewall" "kube-internal" {
  name = "kubernetes-the-hard-way-allow-internal"
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
  name = "kubernetes-the-hard-way-allow-external"
  network = "${google_compute_network.kube-network.self_link}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]

}

resource "google_compute_address" "kube-external-address" {
  name = "kubernetes-the-hard-way"
}
