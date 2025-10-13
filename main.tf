provider "aws" {
  region = var.region
}

module "ami_builder" {
  source           = "git::https://github.com/MuddyThunder1040/aws-topology-modules.git//ami"
  region           = var.region
  vpc_id           = var.vpc_id
  subnet_id        = var.subnet_id
  key_name         = var.key_name
  app_docker_image = var.app_docker_image
}

output "ami_id" {
  value = module.ami_builder.ami_id
}
