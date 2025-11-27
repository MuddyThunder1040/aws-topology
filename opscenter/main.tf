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
  name = "datastax/dse-opscenter:latest"
}

# OpsCenter container for monitoring Cassandra cluster
resource "docker_container" "opscenter" {
  name  = "opscenter"
  image = docker_image.opscenter.image_id
  
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

  # Stomp port for agents
  ports {
    internal = 61621
    external = 61621
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
