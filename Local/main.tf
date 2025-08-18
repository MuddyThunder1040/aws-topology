terraform {
  required_providers {
    Local = {
      source  = "hashicorp/local"
      version = "~> 2.1.0"
    }
  }
}
provider "local" {
  # Configuration options
}
resource "local_file" "example" {
  content  = "This is an example file created by Terraform.\n"
filename = "${path.module}/aws-topology.txt"
}
