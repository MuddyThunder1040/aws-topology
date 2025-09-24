# Makefile for Cassandra Cluster Operations

.PHONY: help init plan apply destroy fmt validate clean ssh status logs

# Default target
help: ## Show this help message
	@echo "Cassandra Cluster Terraform Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Terraform Operations
init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate

fmt: ## Format Terraform files
	terraform fmt -recursive

plan: ## Show Terraform execution plan
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply

destroy: ## Destroy all resources (WARNING: This deletes everything!)
	terraform destroy

# Utility Commands
clean: ## Clean Terraform temporary files
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate.backup
	find . -name "*.tfplan" -delete

ssh: ## SSH to the first (seed) node
	@echo "Connecting to seed node..."
	@SEED_IP=$$(terraform output -raw cassandra_elastic_ips | jq -r '.[0] // empty'); \
	if [ -z "$$SEED_IP" ]; then \
		SEED_IP=$$(terraform output -raw cassandra_public_ips | jq -r '.[0]'); \
	fi; \
	echo "Connecting to $$SEED_IP"; \
	ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$SEED_IP

ssh-all: ## Show SSH commands for all nodes
	@terraform output ssh_connection_commands

status: ## Check cluster status
	@echo "Checking Cassandra cluster status..."
	@SEED_IP=$$(terraform output -raw cassandra_elastic_ips | jq -r '.[0] // empty'); \
	if [ -z "$$SEED_IP" ]; then \
		SEED_IP=$$(terraform output -raw cassandra_public_ips | jq -r '.[0]'); \
	fi; \
	ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$SEED_IP '/opt/cassandra/bin/nodetool status'

logs: ## View recent Cassandra logs from seed node
	@echo "Fetching recent Cassandra logs..."
	@SEED_IP=$$(terraform output -raw cassandra_elastic_ips | jq -r '.[0] // empty'); \
	if [ -z "$$SEED_IP" ]; then \
		SEED_IP=$$(terraform output -raw cassandra_public_ips | jq -r '.[0]'); \
	fi; \
	ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$SEED_IP 'sudo tail -50 /var/log/cassandra/system.log'

# Development Helpers
check-vars: ## Check if required variables are set
	@echo "Checking required variables..."
	@if [ ! -f terraform.tfvars ]; then \
		echo "❌ terraform.tfvars not found. Copy from terraform.tfvars.example"; \
		exit 1; \
	fi
	@if ! grep -q "public_key.*ssh-rsa" terraform.tfvars; then \
		echo "❌ public_key not set in terraform.tfvars"; \
		exit 1; \
	fi
	@echo "✅ Required variables appear to be set"

key-gen: ## Generate SSH key pair for cluster access
	@echo "Generating SSH key pair..."
	@if [ -f ~/.ssh/cassandra-cluster-key ]; then \
		echo "❌ Key already exists at ~/.ssh/cassandra-cluster-key"; \
		echo "Remove it first if you want to generate a new one"; \
		exit 1; \
	fi
	ssh-keygen -t rsa -b 4096 -f ~/.ssh/cassandra-cluster-key -N ""
	@echo "✅ Key generated at ~/.ssh/cassandra-cluster-key"
	@echo "📋 Public key content:"
	@cat ~/.ssh/cassandra-cluster-key.pub
	@echo ""
	@echo "Copy the above public key to the 'public_key' variable in terraform.tfvars"

show-outputs: ## Show all Terraform outputs
	terraform output

show-cost: ## Show estimated monthly cost
	@terraform output estimated_monthly_cost

show-cluster: ## Show cluster summary
	@terraform output cluster_summary

# Cassandra Operations
cql: ## Connect to Cassandra with CQL shell
	@echo "Connecting to Cassandra CQL shell..."
	@SEED_IP=$$(terraform output -raw cassandra_elastic_ips | jq -r '.[0] // empty'); \
	if [ -z "$$SEED_IP" ]; then \
		SEED_IP=$$(terraform output -raw cassandra_public_ips | jq -r '.[0]'); \
	fi; \
	PRIVATE_IP=$$(terraform output -raw cassandra_private_ips | jq -r '.[0]'); \
	ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$SEED_IP "/opt/cassandra/bin/cqlsh $$PRIVATE_IP"

repair: ## Run Cassandra repair on all nodes
	@echo "Running Cassandra repair (this may take a while)..."
	@SEED_IP=$$(terraform output -raw cassandra_elastic_ips | jq -r '.[0] // empty'); \
	if [ -z "$$SEED_IP" ]; then \
		SEED_IP=$$(terraform output -raw cassandra_public_ips | jq -r '.[0]'); \
	fi; \
	ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$SEED_IP '/opt/cassandra/bin/nodetool repair'

health: ## Run health check on all nodes
	@echo "Running health checks on all nodes..."
	@terraform output -json cassandra_public_ips | jq -r '.[]' | while read ip; do \
		echo "Checking node $$ip..."; \
		ssh -i ~/.ssh/cassandra-cluster-key -o ConnectTimeout=5 ec2-user@$$ip '/opt/cassandra/bin/health-check.sh' || echo "❌ Health check failed for $$ip"; \
	done

# Monitoring
cloudwatch: ## Open CloudWatch logs in browser
	@LOG_GROUP=$$(terraform output -raw cloudwatch_log_group_name); \
	REGION=$$(terraform output -json cluster_summary | jq -r '.region'); \
	echo "Opening CloudWatch logs for $$LOG_GROUP in $$REGION"; \
	ENCODED_LOG_GROUP=$$(echo "$$LOG_GROUP" | sed 's/\//%252F/g'); \
	open "https://console.aws.amazon.com/cloudwatch/home?region=$$REGION#logsV2:log-groups/log-group/$$ENCODED_LOG_GROUP"

ec2-console: ## Open EC2 console in browser
	@CLUSTER_NAME=$$(terraform output -json cluster_summary | jq -r '.cluster_name'); \
	REGION=$$(terraform output -json cluster_summary | jq -r '.region'); \
	echo "Opening EC2 console for cluster $$CLUSTER_NAME in $$REGION"; \
	open "https://console.aws.amazon.com/ec2/home?region=$$REGION#Instances:search=$$CLUSTER_NAME"

# Backup and Restore
snapshot: ## Create snapshots of all nodes
	@echo "Creating snapshots..."
	@terraform output -json cassandra_public_ips | jq -r '.[]' | while read ip; do \
		echo "Creating snapshot on node $$ip..."; \
		ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$ip '/opt/cassandra/bin/nodetool snapshot'; \
	done

# Security
security-check: ## Check security group rules
	@SG_ID=$$(terraform output -raw security_group_id); \
	echo "Security Group: $$SG_ID"; \
	aws ec2 describe-security-groups --group-ids $$SG_ID --query 'SecurityGroups[0].{GroupId:GroupId,VpcId:VpcId,InboundRules:IpPermissions[*].{Port:FromPort,Protocol:IpProtocol,Source:IpRanges[0].CidrIp}}'

# Full workflow targets
setup: key-gen ## Complete setup: generate keys and copy example vars
	cp terraform.tfvars.example terraform.tfvars
	@echo "✅ Setup complete!"
	@echo "📝 Next steps:"
	@echo "   1. Edit terraform.tfvars with your settings"
	@echo "   2. Add the generated public key to terraform.tfvars"
	@echo "   3. Run 'make deploy' to create the cluster"

deploy: check-vars init validate plan apply ## Complete deployment workflow
	@echo "✅ Deployment complete!"
	@echo "📊 Cluster summary:"
	@make show-cluster
	@echo ""
	@echo "🔗 Connection commands:"
	@make ssh-all

# Emergency procedures
emergency-stop: ## Emergency stop: stop Cassandra on all nodes
	@echo "🚨 EMERGENCY STOP: Stopping Cassandra on all nodes..."
	@terraform output -json cassandra_public_ips | jq -r '.[]' | while read ip; do \
		echo "Stopping Cassandra on $$ip..."; \
		ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$ip 'sudo systemctl stop cassandra' || true; \
	done

emergency-start: ## Emergency start: start Cassandra on all nodes
	@echo "🚀 EMERGENCY START: Starting Cassandra on all nodes..."
	@terraform output -json cassandra_public_ips | jq -r '.[]' | while read ip; do \
		echo "Starting Cassandra on $$ip..."; \
		ssh -i ~/.ssh/cassandra-cluster-key ec2-user@$$ip 'sudo systemctl start cassandra' || true; \
	done