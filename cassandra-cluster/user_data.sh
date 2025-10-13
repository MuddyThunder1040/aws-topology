#!/bin/bash

# Cassandra EC2 User Data Script
# This script installs and configures Apache Cassandra on Amazon Linux 2

set -e  # Exit on any error

# Logging setup
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting Cassandra installation at $(date)"

# Variables from Terraform template
CLUSTER_NAME="${cluster_name}"
NODE_COUNT="${node_count}"
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

echo "Instance ID: $INSTANCE_ID"
echo "Private IP: $PRIVATE_IP"
echo "Public IP: $PUBLIC_IP"
echo "Availability Zone: $AZ"

# Update system packages
echo "Updating system packages..."
yum update -y

# Install required packages
echo "Installing required packages..."
yum install -y java-11-amazon-corretto-headless wget curl vim htop iotop

# Install CloudWatch agent
echo "Installing CloudWatch agent..."
wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
rpm -U ./amazon-cloudwatch-agent.rpm

# Create cassandra user
echo "Creating cassandra user..."
useradd -r -s /bin/false cassandra

# Prepare data volume
echo "Setting up data volume..."
if [[ -b /dev/xvdf ]]; then
    # Format the data volume if it's not already formatted
    if ! blkid /dev/xvdf; then
        mkfs.ext4 /dev/xvdf
    fi
    
    # Create mount point and mount
    mkdir -p /var/lib/cassandra
    mount /dev/xvdf /var/lib/cassandra
    
    # Add to fstab for persistence
    echo "/dev/xvdf /var/lib/cassandra ext4 defaults,nofail 0 2" >> /etc/fstab
    
    # Set ownership
    chown cassandra:cassandra /var/lib/cassandra
else
    echo "Warning: Data volume /dev/xvdf not found. Using root volume for data."
    mkdir -p /var/lib/cassandra
    chown cassandra:cassandra /var/lib/cassandra
fi

# Download and install Cassandra
echo "Downloading and installing Cassandra..."
CASSANDRA_VERSION="4.1.3"
CASSANDRA_HOME="/opt/cassandra"

cd /tmp
wget "https://archive.apache.org/dist/cassandra/$CASSANDRA_VERSION/apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"
tar xzf "apache-cassandra-$CASSANDRA_VERSION-bin.tar.gz"

# Move Cassandra to /opt
mv "apache-cassandra-$CASSANDRA_VERSION" "$CASSANDRA_HOME"
chown -R cassandra:cassandra "$CASSANDRA_HOME"

# Create symbolic link
ln -sf "$CASSANDRA_HOME" /opt/cassandra-current

# Create necessary directories
mkdir -p /var/lib/cassandra/data
mkdir -p /var/lib/cassandra/commitlog
mkdir -p /var/lib/cassandra/saved_caches
mkdir -p /etc/cassandra
mkdir -p /var/log/cassandra

# Set ownership
chown -R cassandra:cassandra /var/lib/cassandra
chown -R cassandra:cassandra /var/log/cassandra
chown -R cassandra:cassandra /etc/cassandra

# Copy configuration files
cp "$CASSANDRA_HOME/conf/"* /etc/cassandra/

# Configure Cassandra
echo "Configuring Cassandra..."

# Backup original configuration
cp /etc/cassandra/cassandra.yaml /etc/cassandra/cassandra.yaml.backup

# Get all private IPs from the cluster (this is a simplified approach)
# In a real deployment, you'd use AWS CLI to get all instances in the cluster
SEED_NODES="$PRIVATE_IP"  # For now, use self as seed. This will be improved.

# Generate cassandra.yaml configuration
cat > /etc/cassandra/cassandra.yaml << EOF
# Cassandra Configuration File
cluster_name: '$CLUSTER_NAME'
num_tokens: 256
hinted_handoff_enabled: true
max_hint_window_in_ms: 10800000
hinted_handoff_throttle_in_kb: 1024
max_hints_delivery_threads: 2
hints_directory: /var/lib/cassandra/hints
hints_flush_period_in_ms: 10000
max_hints_file_size_in_mb: 128
batchlog_replay_throttle_in_kb: 1024
authenticator: AllowAllAuthenticator
authorizer: AllowAllAuthorizer
role_manager: CassandraRoleManager
roles_validity_in_ms: 2000
permissions_validity_in_ms: 2000
credentials_validity_in_ms: 2000
partitioner: org.apache.cassandra.dht.Murmur3Partitioner
data_file_directories:
    - /var/lib/cassandra/data
commitlog_directory: /var/lib/cassandra/commitlog
cdc_enabled: false
disk_failure_policy: stop
commit_failure_policy: stop
prepared_statements_cache_size_mb:
thrift_prepared_statements_cache_size_mb:
key_cache_size_in_mb:
key_cache_save_period: 14400
row_cache_size_in_mb: 0
row_cache_save_period: 0
counter_cache_size_in_mb:
counter_cache_save_period: 7200
saved_caches_directory: /var/lib/cassandra/saved_caches
commitlog_sync: periodic
commitlog_sync_period_in_ms: 10000
commitlog_segment_size_in_mb: 16  # Reduced for limited memory
seed_provider:
    - class_name: org.apache.cassandra.locator.SimpleSeedProvider
      parameters:
          - seeds: "$SEED_NODES"
# Optimized for t2.micro (1 vCPU) - reduced concurrency
concurrent_reads: 4
concurrent_writes: 4
concurrent_counter_writes: 4
concurrent_materialized_view_writes: 4
memtable_allocation_type: heap_buffers
index_summary_capacity_in_mb:
index_summary_resize_interval_in_minutes: 60
trickle_fsync: false
trickle_fsync_interval_in_kb: 10240
storage_port: 7000
ssl_storage_port: 7001
listen_address: $PRIVATE_IP
start_native_transport: true
native_transport_port: 9042
start_rpc: false
rpc_address: $PRIVATE_IP
rpc_port: 9160
rpc_keepalive: true
rpc_server_type: sync
thrift_framed_transport_size_in_mb: 15
incremental_backups: false
snapshot_before_compaction: false
auto_snapshot: true
column_index_size_in_kb: 64
column_index_cache_size_in_kb: 2
compaction_throughput_mb_per_sec: 16
sstable_preemptive_open_interval_in_mb: 50
read_request_timeout_in_ms: 5000
range_request_timeout_in_ms: 10000
write_request_timeout_in_ms: 2000
counter_write_request_timeout_in_ms: 5000
cas_contention_timeout_in_ms: 1000
truncate_request_timeout_in_ms: 60000
request_timeout_in_ms: 10000
slow_query_log_timeout_in_ms: 500
cross_node_timeout: false
endpoint_snitch: GossipingPropertyFileSnitch
dynamic_snitch_update_interval_in_ms: 100
dynamic_snitch_reset_interval_in_ms: 600000
dynamic_snitch_badness_threshold: 0.1
request_scheduler: org.apache.cassandra.scheduler.NoScheduler
server_encryption_options:
    internode_encryption: none
    keystore: conf/.keystore
    keystore_password: cassandra
    truststore: conf/.truststore
    truststore_password: cassandra
client_encryption_options:
    enabled: false
    optional: false
    keystore: conf/.keystore
    keystore_password: cassandra
internode_compression: dc
inter_dc_tcp_nodelay: false
tracetype_query_ttl: 86400
tracetype_repair_ttl: 604800
enable_user_defined_functions: false
enable_scripted_user_defined_functions: false
windows_timer_interval: 1
transparent_data_encryption_options:
    enabled: false
    chunk_length_kb: 64
    cipher: AES/CBC/PKCS5Padding
    key_alias: testing:1
    key_provider:
      - class_name: org.apache.cassandra.security.JKSKeyProvider
        parameters:
          - keystore: conf/.keystore
            keystore_password: cassandra
            store_type: JCEKS
            key_password: cassandra
tombstone_warn_threshold: 1000
tombstone_failure_threshold: 100000
batch_size_warn_threshold_in_kb: 5
batch_size_fail_threshold_in_kb: 50
unlogged_batch_across_partitions_warn_threshold: 10
compaction_large_partition_warning_threshold_mb: 100
gc_warn_threshold_in_ms: 1000
max_value_size_in_mb: 256
EOF

# Configure JVM options
echo "Configuring JVM options..."
cat > /etc/cassandra/jvm.options << EOF
# JVM Options for Cassandra

# Heap size (configured for instance type)
-Xms${cassandra_heap_size}
-Xmx${cassandra_heap_size}

# GC Options
-XX:+UseG1GC
-XX:+UnlockExperimentalVMOptions
-XX:G1NewSizePercent=20
-XX:G1ReservePercent=20
-XX:MaxGCPauseMillis=200
-XX:G1HeapRegionSize=16m
-XX:G1HeapWastePercent=5
-XX:G1MixedGCCountTarget=8
-XX:InitiatingHeapOccupancyPercent=70
-XX:G1MixedGCLiveThresholdPercent=85

# GC Logging
-Xloggc:/var/log/cassandra/gc.log
-XX:+UseGCLogFileRotation
-XX:NumberOfGCLogFiles=10
-XX:GCLogFileSize=10M
-XX:+PrintGC
-XX:+PrintGCDetails
-XX:+PrintGCTimeStamps
-XX:+PrintGCApplicationStoppedTime
-XX:+PrintPromotionFailure
-XX:PrintFLSStatistics=1

# JMX Configuration
-Dcom.sun.management.jmxremote.port=7199
-Dcom.sun.management.jmxremote.rmi.port=7199
-Dcom.sun.management.jmxremote.ssl=false
-Dcom.sun.management.jmxremote.authenticate=false
-Djava.rmi.server.hostname=$PRIVATE_IP

# Other JVM options
-ea
-XX:+HeapDumpOnOutOfMemoryError
-XX:HeapDumpPath=/var/log/cassandra/
-XX:+ExitOnOutOfMemoryError
-Djava.net.preferIPv4Stack=true
-Dlogback.configurationFile=logback.xml
-Dcassandra.logdir=/var/log/cassandra
-Dcassandra.storagedir=/var/lib/cassandra
EOF

# Configure datacenter and rack information
echo "Configuring datacenter and rack..."
cat > /etc/cassandra/cassandra-rackdc.properties << EOF
dc=dc1
rack=rack1
prefer_local=false
EOF

# Create systemd service file
echo "Creating systemd service..."
cat > /etc/systemd/system/cassandra.service << EOF
[Unit]
Description=Apache Cassandra
After=network.target

[Service]
Type=forking
User=cassandra
Group=cassandra
ExecStart=/opt/cassandra/bin/cassandra -p /var/run/cassandra/cassandra.pid
PIDFile=/var/run/cassandra/cassandra.pid
StandardOutput=journal
StandardError=journal
LimitNOFILE=100000
LimitMEMLOCK=infinity
LimitNPROC=32768
LimitAS=infinity
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

# Create PID directory
mkdir -p /var/run/cassandra
chown cassandra:cassandra /var/run/cassandra

# Set environment variables
echo "Setting environment variables..."
cat > /etc/profile.d/cassandra.sh << EOF
export CASSANDRA_HOME=/opt/cassandra
export CASSANDRA_CONF=/etc/cassandra
export PATH=\$PATH:\$CASSANDRA_HOME/bin
EOF

# Configure logback for better logging
cat > /etc/cassandra/logback.xml << EOF
<configuration scan="true">
  <jmxConfigurator />
  
  <appender name="FILE" class="ch.qos.logback.core.rolling.RollingFileAppender">
    <file>/var/log/cassandra/system.log</file>
    <rollingPolicy class="ch.qos.logback.core.rolling.FixedWindowRollingPolicy">
      <fileNamePattern>/var/log/cassandra/system.log.%i.zip</fileNamePattern>
      <minIndex>1</minIndex>
      <maxIndex>20</maxIndex>
    </rollingPolicy>
    
    <triggeringPolicy class="ch.qos.logback.core.rolling.SizeBasedTriggeringPolicy">
      <maxFileSize>20MB</maxFileSize>
    </triggeringPolicy>
    
    <encoder>
      <pattern>%-5level [%thread] %date{ISO8601} %F:%L - %msg%n</pattern>
    </encoder>
  </appender>
  
  <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
    <encoder>
      <pattern>%-5level %date{HH:mm:ss,SSS} %msg%n</pattern>
    </encoder>
  </appender>
  
  <root level="INFO">
    <appender-ref ref="FILE" />
  </root>
  
  <logger name="com.thinkaurelius.thrift" level="ERROR"/>
</configuration>
EOF

# Configure CloudWatch agent
echo "Configuring CloudWatch agent..."
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/cassandra/system.log",
            "log_group_name": "/aws/ec2/$CLUSTER_NAME",
            "log_stream_name": "{instance_id}/cassandra-system"
          },
          {
            "file_path": "/var/log/cassandra/gc.log",
            "log_group_name": "/aws/ec2/$CLUSTER_NAME",
            "log_stream_name": "{instance_id}/cassandra-gc"
          },
          {
            "file_path": "/var/log/user-data.log",
            "log_group_name": "/aws/ec2/$CLUSTER_NAME",
            "log_stream_name": "{instance_id}/user-data"
          }
        ]
      }
    }
  },
  "metrics": {
    "namespace": "CassandraCluster",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      }
    }
  }
}
EOF

# Enable and start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Create startup script to wait for other nodes and update seed list
cat > /opt/cassandra/bin/wait-for-cluster.sh << 'EOF'
#!/bin/bash

# Wait for cluster script
# This script waits for other nodes to be available and updates the seed list

CLUSTER_NAME="CLUSTER_NAME_PLACEHOLDER"
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "Waiting for cluster nodes to be ready..."

# Wait a bit for other instances to come online
sleep 60

# Get instance information from AWS (this requires appropriate IAM permissions)
# For simplicity, we'll use a basic approach here
# In production, you'd want to use AWS CLI to get all cluster nodes

# For now, we'll start with the current configuration
echo "Starting Cassandra node with current configuration..."
EOF

chmod +x /opt/cassandra/bin/wait-for-cluster.sh

# Create health check script
cat > /opt/cassandra/bin/health-check.sh << 'EOF'
#!/bin/bash

# Cassandra Health Check Script
CQLSH=/opt/cassandra/bin/cqlsh
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

# Check if Cassandra is responding to CQL queries
if $CQLSH $PRIVATE_IP -e "SELECT cluster_name FROM system.local;" > /dev/null 2>&1; then
    echo "Cassandra is healthy"
    exit 0
else
    echo "Cassandra is not responding"
    exit 1
fi
EOF

chmod +x /opt/cassandra/bin/health-check.sh

# Set proper permissions
chown -R cassandra:cassandra /opt/cassandra
chown -R cassandra:cassandra /etc/cassandra
chown -R cassandra:cassandra /var/lib/cassandra
chown -R cassandra:cassandra /var/log/cassandra

# Reload systemd and enable Cassandra service
systemctl daemon-reload
systemctl enable cassandra

# Wait a bit more for network to be fully ready
sleep 30

# Start Cassandra
echo "Starting Cassandra..."
systemctl start cassandra

# Wait for Cassandra to start
sleep 60

# Check Cassandra status
systemctl status cassandra

# Create a simple test keyspace and table
echo "Creating test keyspace..."
sleep 30  # Wait for Cassandra to be fully ready

/opt/cassandra/bin/cqlsh $PRIVATE_IP << 'CQLEOF'
CREATE KEYSPACE IF NOT EXISTS test_keyspace 
WITH REPLICATION = {
    'class' : 'SimpleStrategy',
    'replication_factor' : 1
};

USE test_keyspace;

CREATE TABLE IF NOT EXISTS test_table (
    id UUID PRIMARY KEY,
    name TEXT,
    created_at TIMESTAMP
);

INSERT INTO test_table (id, name, created_at) VALUES (uuid(), 'Test Node', toTimestamp(now()));
CQLEOF

echo "Cassandra installation and configuration completed at $(date)"
echo "Node is ready to join the cluster"

# Final status check
echo "Final status check:"
systemctl is-active cassandra
/opt/cassandra/bin/nodetool status

echo "User data script completed successfully!"

# Create health check endpoint for load balancer
echo "Setting up health check endpoint..."

# Create a simple HTTP health check service
cat > /opt/cassandra-health-check.py << 'HEALTHEOF'
#!/usr/bin/env python3
import subprocess
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import threading
import time
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

class HealthCheckHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            try:
                # Check if Cassandra service is running
                result = subprocess.run(['systemctl', 'is-active', 'cassandra'], 
                                      capture_output=True, text=True)
                
                if result.returncode == 0 and result.stdout.strip() == 'active':
                    # Additional check - try to connect to Cassandra
                    try:
                        cql_result = subprocess.run(['/opt/cassandra/bin/cqlsh', 
                                                   '-e', 'SELECT now() FROM system.local;'], 
                                                  capture_output=True, text=True, timeout=5)
                        
                        if cql_result.returncode == 0:
                            self.send_response(200)
                            self.send_header('Content-type', 'application/json')
                            self.end_headers()
                            response = {
                                'status': 'healthy',
                                'service': 'cassandra',
                                'timestamp': time.time()
                            }
                            self.wfile.write(json.dumps(response).encode())
                        else:
                            self.send_error(503, 'Cassandra not responding to CQL queries')
                    except subprocess.TimeoutExpired:
                        self.send_error(503, 'Cassandra CQL timeout')
                else:
                    self.send_error(503, 'Cassandra service not active')
            except Exception as e:
                logging.error(f"Health check error: {e}")
                self.send_error(500, f'Health check failed: {str(e)}')
        else:
            self.send_error(404, 'Not found')
    
    def log_message(self, format, *args):
        # Override to use proper logging
        logging.info(f"{self.address_string()} - {format % args}")

def run_health_server():
    server = HTTPServer(('0.0.0.0', 8080), HealthCheckHandler)
    logging.info("Health check server starting on port 8080")
    server.serve_forever()

if __name__ == '__main__':
    run_health_server()
HEALTHEOF

chmod +x /opt/cassandra-health-check.py

# Create systemd service for health check
cat > /etc/systemd/system/cassandra-health-check.service << 'SERVICEEOF'
[Unit]
Description=Cassandra Health Check Service
After=network.target cassandra.service
Requires=cassandra.service

[Service]
Type=simple
User=cassandra
Group=cassandra
ExecStart=/opt/cassandra-health-check.py
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Start and enable health check service
systemctl daemon-reload
systemctl enable cassandra-health-check
systemctl start cassandra-health-check

# Verify health check service is running
sleep 5
systemctl status cassandra-health-check

echo "Health check endpoint configured and running on port 8080"