variable "instance_name" {}
variable "ami_id" {}
variable "instance_type" {}
variable "subnet_id" {}
variable "security_group_ids" { type = list(string) }
variable "key_name" {}
variable "associate_public_ip" { default = false }
variable "provisioner_script" { default = "echo 'No script provided'" }
variable "source_file" { default = null }
variable "destination_file" { default = null }
variable "bastion_host" { default = null }