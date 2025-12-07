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

# Prometheus image
resource "docker_image" "prometheus" {
  name = "prom/prometheus:latest"
}

# Grafana image
resource "docker_image" "grafana" {
  name = "grafana/grafana:latest"
}

# JMX Exporter for Cassandra metrics
resource "docker_image" "jmx_exporter" {
  name = "bitnami/jmx-exporter:latest"
}

# Prometheus configuration volume
resource "docker_volume" "prometheus_config" {
  name = "prometheus-config"
}

# Prometheus data volume
resource "docker_volume" "prometheus_data" {
  name = "prometheus-data"
}

# Grafana data volume
resource "docker_volume" "grafana_data" {
  name = "grafana-data"
}

# Prometheus container
resource "docker_container" "prometheus" {
  name  = "prometheus"
  image = docker_image.prometheus.image_id
  
  networks_advanced {
    name = data.docker_network.cassandra_network.name
  }

  # Web UI port
  ports {
    internal = 9090
    external = 9091
  }

  volumes {
    container_path = "/etc/prometheus"
    host_path      = abspath("${path.module}/prometheus-config")
    read_only      = true
  }

  volumes {
    container_path = "/prometheus"
    volume_name    = docker_volume.prometheus_data.name
  }

  command = [
    "--config.file=/etc/prometheus/prometheus.yml",
    "--storage.tsdb.path=/prometheus",
    "--web.console.libraries=/usr/share/prometheus/console_libraries",
    "--web.console.templates=/usr/share/prometheus/consoles"
  ]

  restart = "unless-stopped"
}

# Grafana container
resource "docker_container" "grafana" {
  name  = "grafana"
  image = docker_image.grafana.image_id
  
  networks_advanced {
    name = data.docker_network.cassandra_network.name
  }

  # Web UI port
  ports {
    internal = 3000
    external = 3001
  }

  env = [
    "GF_SECURITY_ADMIN_USER=admin",
    "GF_SECURITY_ADMIN_PASSWORD=admin",
    "GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource"
  ]

  volumes {
    container_path = "/var/lib/grafana"
    volume_name    = docker_volume.grafana_data.name
  }

  restart = "unless-stopped"
}

# JMX Exporter for Cassandra
resource "docker_container" "jmx_exporter" {
  name  = "jmx-exporter"
  image = docker_image.jmx_exporter.image_id
  
  networks_advanced {
    name = data.docker_network.cassandra_network.name
  }

  # JMX metrics port
  ports {
    internal = 5556
    external = 5557
  }

  env = [
    "SERVICE_PORT=5556"
  ]

  restart = "unless-stopped"
}
