variable "lb_name" {}
variable "is_internal" { type = bool }
variable "vpc_id" {}
variable "subnets" { type = list(string) }
variable "security_groups" { type = list(string) }
variable "target_instances" { type = list(string) }
variable "health_check_path" {
  description = "The destination path for the health check request."
  type        = string
  default     = "/"
}