##################################################################################
# VARIABLES
##################################################################################

variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {
  default = "id_rsa_aws"
}
variable "network_address_space" {
  default = "192.168.0.0/16"
}

variable "ssh_user" {
  default = "ec2-user"
}

variable "dbnodes_count" {
  default = 3
}

variable "db_subnet_count" {
  default = 3
}

variable "webnodes_count" {
  default = 4
}

variable "web_subnet_count" {
  default = 2
}

locals {
  modulus_az = "${length(split(",", join(", ",data.aws_availability_zones.available.names)))}"
}

