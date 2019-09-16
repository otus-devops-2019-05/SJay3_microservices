variable "cidr_range" {
  type = "string"
  description = "kubernetes GCP subnetwork"
  default = "10.240.0.0/24"
}
