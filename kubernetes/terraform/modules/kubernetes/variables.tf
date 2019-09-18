# common variables
variable "public_key_path" {
  type        = "string"
  description = "Path to the public key used to connect to instance"
}

variable "zone" {
  type        = "string"
  description = "Zone"
}

variable "region" {
  type = "string"
  description = "region"
}

# Network vars
variable "cidr_range" {
  type        = "string"
  description = "kubernetes GCP subnetwork"
  default     = "10.240.0.0/24"
}

# controller vars
variable "controller_disk_image" {
  type        = "string"
  description = "Disk image for controller"
  default     = "ubuntu-1804-lts"
}

variable "controller_count" {
  type        = "string"
  description = "Count instances"
  default     = "1"
}

# worker vars
variable "worker_count" {
  type        = "string"
  description = "Count instances"
  default     = "1"
}

variable "worker_disk_image" {
  type        = "string"
  description = "Disk image for worker"
  default     = "ubuntu-1804-lts"
}
