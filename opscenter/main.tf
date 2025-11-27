terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

# Use the same network as Cassandra cluster
data "docker_network" "cassandra_network" {
  name = "cassandra-network"
}

# DataStax OpsCenter image
resource "docker_image" "opscenter" {
  name = "datastax/dse-opscenter:6.8.47"
}

# OpsCenter container for monitoring Cassandra cluster
resource "docker_container" "opscenter" {
  name  = "opscenter"
  image = docker_image.opscenter.image_id
  
  env = [
    "DS_LICENSE=accept"
  ]
  
  networks_advanced {
    name = data.docker_network.cassandra_network.name
  }

  # Web UI port
  ports {
    internal = 8888
    external = 8888
  }

  # Agent communication port
  ports {
    internal = 61620
    external = 61620
  }

  volumes {
    container_path = "/var/lib/opscenter"
    volume_name    = docker_volume.opscenter_data.name
  }

  restart = "unless-stopped"
}

# Persistent storage for OpsCenter data
resource "docker_volume" "opscenter_data" {
  name = "opscenter-data"
}
