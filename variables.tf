variable "region" {
  default = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID for the temporary instance"
}

variable "subnet_id" {
  description = "Subnet ID for the temporary instance"
}

variable "key_name" {
  description = "EC2 Key pair name for SSH"
}

variable "app_docker_image" {
  default = "muddythunder/appserver:latest"
}
