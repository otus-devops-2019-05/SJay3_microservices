variable "project" {
  type        = "string"
  description = "Project ID"
}

variable "region" {
  type        = "string"
  description = "region"
  default     = "europe-west1"
}

variable "machine_type" {
  type = "string"
  description = "GCP machine type. g1-small by default"
  default = "g1-small"
}

variable "public_key_path" {
  type        = "string"
  description = "Path to the public key used to connect to instance"
}

variable "privat_key_path" {
  type        = "string"
  description = "Path to privat key used for provisioner connection"
}

variable "zone" {
  type        = "string"
  description = "Zone"
  default     = "europe-west1-b"
}

variable "docker_disk_image" {
  type        = "string"
  description = "Disk image for reddit app"
  default     = "docker-base"
}

variable "docker_disk_size" {
  type = "string"
  description = "Boot disk size"
  default = "10"
}

variable "instance_count" {
  type        = "string"
  description = "Count instances"
  default     = "1"
}

variable "enable_web_traffic" {
  type = "string"
  description = "Create http/https firewall rules and map to instance or not"
  default = "false"
}
