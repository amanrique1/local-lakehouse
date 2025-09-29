# Makefile for Local Lakehouse

# Variables
COMPOSE_FILE = docker-compose-system.yaml

# Commands

.PHONY: start stop logs status list-buckets list-catalogs list-schemas list-tables

# Starts all services in the background
start:
	@echo "Starting Local Lakehouse services..."
	docker-compose -f $(COMPOSE_FILE) up -d

# Stops all services and removes containers
stop:
	@echo "Stopping Local Lakehouse services..."
	docker-compose -f $(COMPOSE_FILE) down

# Tails the logs of all services
logs:
	@echo "Tailing logs of all services..."
	docker-compose -f $(COMPOSE_FILE) logs -f

# Shows the status of all services
status:
	@echo "Status of all services..."
	docker-compose -f $(COMPOSE_FILE) ps

# Lists all buckets in MinIO
list-buckets:
	@echo "Listing buckets in MinIO..."
	docker exec -it minio mc ls local

# Lists all catalogs in Trino
list-catalogs:
	@echo "Listing catalogs in Trino..."
	docker exec -it trino-coordinator trino --execute "SHOW CATALOGS"

# Lists all schemas in a given catalog in Trino
list-schemas:
	@echo "Listing schemas in Trino..."
	docker exec -it trino-coordinator trino --execute "SHOW SCHEMAS FROM $(catalog)"

# Lists all tables in a given schema in Trino
list-tables:
	@echo "Listing tables in Trino..."
	docker exec -it trino-coordinator trino --execute "SHOW TABLES FROM $(catalog).$(schema)"
