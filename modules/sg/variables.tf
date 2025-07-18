variable "project_name" {}
variable "sg_name" {}
variable "vpc_id" {}
variable "ingress_rules" { type = list(any) }