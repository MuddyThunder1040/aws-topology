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

# Cassandra Web UI for monitoring
resource "docker_image" "cassandra_web" {
  name = "markusgulden/cassandra-web:latest"
}

# Cassandra Web container for monitoring Cassandra cluster
resource "docker_container" "cassandra_web" {
  name  = "cassandra-web"
  image = docker_image.cassandra_web.image_id
  
  networks_advanced {
    name = data.docker_network.cassandra_network.name
  }

  # Web UI port
  ports {
    internal = 3000
    external = 3000
  }

  env = [
    "CASSANDRA_HOST=cassandra-node1",
    "CASSANDRA_PORT=9042",
    "CASSANDRA_USERNAME=",
    "CASSANDRA_PASSWORD="
  ]

  volumes {
    container_path = "/data"
    volume_name    = docker_volume.cassandra_web_data.name
  }

  restart = "unless-stopped"
}

# Persistent storage for Cassandra Web data
resource "docker_volume" "cassandra_web_data" {
  name = "cassandra-web-data"
}
