output "kube-external-ip" {
  value = "${google_compute_address.kube-external-address.address}"
}
