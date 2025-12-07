output "prometheus_url" {
  description = "Prometheus Web UI URL"
  value       = "http://localhost:9090"
}

output "grafana_url" {
  description = "Grafana Web UI URL"
  value       = "http://localhost:3000"
}

output "grafana_credentials" {
  description = "Grafana login credentials"
  value = {
    username = "admin"
    password = "admin"
  }
  sensitive = true
}

output "jmx_exporter_url" {
  description = "JMX Exporter metrics endpoint"
  value       = "http://localhost:5556/metrics"
}

output "setup_instructions" {
  description = "Setup instructions for monitoring stack"
  value       = <<-EOT
    
    📊 Cassandra Monitoring Stack Deployed
    ========================================
    
    🔍 Prometheus (Metrics Collection)
    URL: http://localhost:9090
    
    📈 Grafana (Dashboards)
    URL: http://localhost:3000
    Username: admin
    Password: admin
    
    📊 JMX Exporter (Cassandra Metrics)
    URL: http://localhost:5556/metrics
    
    ⚙️  Setup Steps:
    
    1. Open Grafana: http://localhost:3000
    2. Login with admin/admin (change password when prompted)
    3. Add Prometheus data source:
       - Go to Configuration > Data Sources
       - Click "Add data source"
       - Select "Prometheus"
       - URL: http://prometheus:9090
       - Click "Save & Test"
    
    4. Import Cassandra Dashboard:
       - Go to Dashboards > Import
       - Use Dashboard ID: 11971 (Cassandra Overview)
       - Or ID: 13132 (Cassandra Metrics)
       - Select Prometheus as data source
    
    5. View Metrics:
       - Prometheus: http://localhost:9090/targets
       - Grafana: http://localhost:3000/dashboards
    
    📊 Available Metrics:
    - JVM memory usage
    - Thread pools
    - Compaction stats
    - Read/Write latency
    - Cache hit rates
    - Node status
    
    🔧 Query Examples (Prometheus):
    - cassandra_threadpools_activetasks
    - cassandra_cache_hits
    - cassandra_table_readlatency
    
  EOT
}
