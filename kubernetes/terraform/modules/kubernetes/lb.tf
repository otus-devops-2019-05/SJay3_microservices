# load balancer configuration
# add health check
resource "google_compute_http_health_check" "kube-health" {
  name         = "kubernetes"
  description = "Kubernetes Health Check"
  host = "kubernetes.default.svc.cluster.local"
  request_path = "/healthz"
  port         = "80"
}

# target pool
resource "google_compute_target_pool" "kube-targets" {
  name = "kubernetes-target-pool"

  instances = ["${google_compute_instance.kube-controller.*.self_link}"]

  health_checks = ["${google_compute_http_health_check.kube-health.name}"]
}

#Create forward rule to forward http to target pool
resource "google_compute_forwarding_rule" "kube-forward" {
  name       = "kubernetes-forwarding-rule"
  region = "${var.region}"
  target     = "${google_compute_target_pool.kube-targets.self_link}"
  port_range = "6443"
  ip_address = "${google_compute_address.kube-external-address.address}"
}

resource "google_compute_firewall" "kube-health" {
  name = "kubernetes-the-hard-way-allow-health-check"
  network = "${google_compute_network.kube-network.name}"
  source_ranges = ["209.85.152.0/22", "209.85.204.0/22", "35.191.0.0/16"]

  allow {
    protocol = "tcp"
  }
}
