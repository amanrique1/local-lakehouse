# ============================================================================
# Makefile for Local Lakehouse
# ============================================================================

# Variables
COMPOSE_FILE = docker-compose-system.yaml
POETRY := poetry
POETRY_RUN := poetry run

# Docker container names
MINIO_CONTAINER = minio
TRINO_CONTAINER = trino-coordinator

# Colors for terminal output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
NC     := \033[0m # No Color

.DEFAULT_GOAL := help

# ============================================================================
# HELP
# ============================================================================
.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)Local Lakehouse - Available Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make $(YELLOW)<target>$(NC)\n\n"} \
		/^[a-zA-Z_-]+:.*?##/ { printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2 } \
		/^##@/ { printf "\n$(GREEN)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

# ============================================================================
##@ 🐍 Python Environment
# ============================================================================

.PHONY: install install-dev setup clean-pyc poetry-shell

install: ## Install project dependencies with Poetry
	@echo "$(GREEN)Installing dependencies with Poetry...$(NC)"
	$(POETRY) install --no-root

install-dev: ## Install development dependencies
	@echo "$(GREEN)Installing development dependencies...$(NC)"
	$(POETRY) install --no-root --with dev

setup: install-dev ## Complete development environment setup
	@echo "$(GREEN)Setting up development environment...$(NC)"
	$(POETRY_RUN) pre-commit install
	$(POETRY_RUN) pre-commit install --hook-type commit-msg
	@echo "$(GREEN)✓ Setup complete!$(NC)"
	@echo "$(YELLOW)Run 'make poetry-shell' to activate the virtual environment$(NC)"

poetry-shell: ## Activate Poetry virtual environment
	@echo "$(GREEN)Activating Poetry shell...$(NC)"
	$(POETRY) shell

clean-pyc: ## Remove Python file artifacts
	@echo "$(YELLOW)Cleaning Python cache files...$(NC)"
	find . -type f -name '*.py[co]' -delete
	find . -type d -name '__pycache__' -delete
	find . -type d -name '*.egg-info' -exec rm -rf {} +
	find . -type d -name '.pytest_cache' -exec rm -rf {} +
	find . -type d -name '.ruff_cache' -exec rm -rf {} +

# ============================================================================
##@ 🎨 Code Quality (Linting & Formatting)
# ============================================================================

.PHONY: lint format check type-check lint-all

lint: ## Run ruff linter (check only)
	@echo "$(GREEN)Running ruff linter...$(NC)"
	$(POETRY_RUN) ruff check .

format: ## Format code with ruff and auto-fix issues
	@echo "$(GREEN)Formatting code with ruff...$(NC)"
	$(POETRY_RUN) ruff format .
	$(POETRY_RUN) ruff check --fix .

check: ## Run linter without fixing (CI mode)
	@echo "$(GREEN)Running linter checks (CI mode)...$(NC)"
	$(POETRY_RUN) ruff check --no-fix .
	$(POETRY_RUN) ruff format --check .

type-check: ## Run mypy type checker
	@echo "$(GREEN)Running type checks...$(NC)"
	$(POETRY_RUN) mypy dags/ --ignore-missing-imports || true

lint-all: clean-pyc lint type-check ## Run all linting checks
	@echo "$(GREEN)✓ All linting checks passed!$(NC)"

# ============================================================================
##@ 🪝 Pre-commit Hooks
# ============================================================================

.PHONY: pre-commit pre-commit-all pre-commit-update

pre-commit: ## Run pre-commit on staged files
	@echo "$(GREEN)Running pre-commit hooks...$(NC)"
	$(POETRY_RUN) pre-commit run

pre-commit-all: ## Run pre-commit on all files
	@echo "$(GREEN)Running pre-commit on all files...$(NC)"
	$(POETRY_RUN) pre-commit run --all-files

pre-commit-update: ## Update pre-commit hooks to latest versions
	@echo "$(GREEN)Updating pre-commit hooks...$(NC)"
	$(POETRY_RUN) pre-commit autoupdate

# ============================================================================
##@ 🧪 Testing
# ============================================================================

.PHONY: test test-cov test-dag-validation

test: ## Run pytest tests
	@echo "$(GREEN)Running tests...$(NC)"
	$(POETRY_RUN) pytest tests/ -v

test-cov: ## Run tests with coverage report
	@echo "$(GREEN)Running tests with coverage...$(NC)"
	$(POETRY_RUN) pytest tests/ -v --cov=dags --cov-report=term-missing --cov-report=html
	@echo "$(GREEN)Coverage report generated: htmlcov/index.html$(NC)"

test-dag-validation: ## Validate Airflow DAGs syntax
	@echo "$(GREEN)Validating Airflow DAGs...$(NC)"
	$(POETRY_RUN) python -c "import sys; sys.path.insert(0, 'dags'); \
		from airflow.models import DagBag; \
		db = DagBag(dag_folder='dags', include_examples=False); \
		assert not db.import_errors, f'DAG import errors: {db.import_errors}'; \
		print('✓ All DAGs validated successfully')"

# ============================================================================
##@ 🐳 Docker Services
# ============================================================================

.PHONY: start stop restart logs status clean

start: ## Start all Docker services
	@echo "$(GREEN)Starting Local Lakehouse services...$(NC)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "$(YELLOW)Airflow UI:$(NC) http://localhost:8080"
	@echo "$(YELLOW)MinIO UI:$(NC)   http://localhost:9001"
	@echo "$(YELLOW)Trino UI:$(NC)   http://localhost:8081"

stop: ## Stop all Docker services
	@echo "$(YELLOW)Stopping Local Lakehouse services...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down

restart: stop start ## Restart all Docker services

logs: ## Tail logs of all services
	@echo "$(GREEN)Tailing logs (Ctrl+C to exit)...$(NC)"
	docker-compose -f $(COMPOSE_FILE) logs -f

status: ## Show status of all services
	@echo "$(GREEN)Service Status:$(NC)"
	docker-compose -f $(COMPOSE_FILE) ps

clean: stop clean-pyc ## Stop services and clean artifacts
	@echo "$(YELLOW)Cleaning Docker volumes and artifacts...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down -v
	rm -rf logs/ dags/dbt_trino/target/ dags/dbt_trino/dbt_packages/
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

# ============================================================================
##@ 📦 MinIO Operations
# ============================================================================

.PHONY: list-buckets create-bucket

list-buckets: ## List all MinIO buckets
	@echo "$(GREEN)Buckets in MinIO:$(NC)"
	docker exec -it $(MINIO_CONTAINER) mc ls local

create-bucket: ## Create a new bucket (usage: make create-bucket BUCKET=my-bucket)
ifndef BUCKET
	@echo "$(RED)Error: BUCKET variable not set$(NC)"
	@echo "Usage: make create-bucket BUCKET=my-bucket"
	@exit 1
endif
	@echo "$(GREEN)Creating bucket: $(BUCKET)$(NC)"
	docker exec -it $(MINIO_CONTAINER) mc mb local/$(BUCKET)

# ============================================================================
##@ 🔍 Trino Operations
# ============================================================================

.PHONY: list-catalogs list-schemas list-tables trino-shell

list-catalogs: ## List all Trino catalogs
	@echo "$(GREEN)Catalogs in Trino:$(NC)"
	docker exec -it $(TRINO_CONTAINER) trino --execute "SHOW CATALOGS"

list-schemas: ## List schemas in a catalog (usage: make list-schemas CATALOG=iceberg)
ifndef CATALOG
	@echo "$(RED)Error: CATALOG variable not set$(NC)"
	@echo "Usage: make list-schemas CATALOG=iceberg"
	@exit 1
endif
	@echo "$(GREEN)Schemas in $(CATALOG):$(NC)"
	docker exec -it $(TRINO_CONTAINER) trino --execute "SHOW SCHEMAS FROM $(CATALOG)"

list-tables: ## List tables in a schema (usage: make list-tables CATALOG=iceberg SCHEMA=staging)
ifndef CATALOG
	@echo "$(RED)Error: CATALOG variable not set$(NC)"
	@echo "Usage: make list-tables CATALOG=iceberg SCHEMA=staging"
	@exit 1
endif
ifndef SCHEMA
	@echo "$(RED)Error: SCHEMA variable not set$(NC)"
	@echo "Usage: make list-tables CATALOG=iceberg SCHEMA=staging"
	@exit 1
endif
	@echo "$(GREEN)Tables in $(CATALOG).$(SCHEMA):$(NC)"
	docker exec -it $(TRINO_CONTAINER) trino --execute "SHOW TABLES FROM $(CATALOG).$(SCHEMA)"

trino-shell: ## Open interactive Trino shell
	@echo "$(GREEN)Opening Trino shell...$(NC)"
	docker exec -it $(TRINO_CONTAINER) trino

# ============================================================================
##@ 🔄 dbt Operations
# ============================================================================

.PHONY: dbt-debug dbt-deps dbt-seed dbt-run dbt-test dbt-docs

dbt-debug: ## Test dbt connection
	@echo "$(GREEN)Testing dbt connection...$(NC)"
	cd dags/dbt_trino && $(POETRY_RUN) dbt debug

dbt-deps: ## Install dbt dependencies
	@echo "$(GREEN)Installing dbt dependencies...$(NC)"
	cd dags/dbt_trino && $(POETRY_RUN) dbt deps

dbt-seed: ## Load seed data
	@echo "$(GREEN)Loading seed data...$(NC)"
	cd dags/dbt_trino && $(POETRY_RUN) dbt seed

dbt-run: ## Run dbt models
	@echo "$(GREEN)Running dbt models...$(NC)"
	cd dags/dbt_trino && $(POETRY_RUN) dbt run

dbt-test: ## Run dbt tests
	@echo "$(GREEN)Running dbt tests...$(NC)"
	cd dags/dbt_trino && $(POETRY_RUN) dbt test

dbt-docs: ## Generate and serve dbt documentation
	@echo "$(GREEN)Generating dbt documentation...$(NC)"
	cd dags/dbt_trino && $(POETRY_RUN) dbt docs generate && $(POETRY_RUN) dbt docs serve

# ============================================================================
##@ 🚀 CI/CD Workflows
# ============================================================================

.PHONY: ci-local ci-pre-commit ci-test

ci-local: lint-all test-dag-validation ## Run full CI pipeline locally
	@echo "$(GREEN)✓ CI pipeline completed successfully!$(NC)"

ci-pre-commit: ## CI check for pre-commit (no auto-fix)
	@echo "$(GREEN)Running pre-commit in CI mode...$(NC)"
	$(POETRY_RUN) pre-commit run --all-files --show-diff-on-failure

ci-test: check test-dag-validation ## CI tests (linting + DAG validation)
	@echo "$(GREEN)✓ CI tests passed!$(NC)"

# ============================================================================
##@ 🔐 Security & Secrets
# ============================================================================

.PHONY: secrets-baseline secrets-scan

secrets-baseline: ## Create baseline for detect-secrets
	@echo "$(GREEN)Creating secrets baseline...$(NC)"
	$(POETRY_RUN) detect-secrets scan > .secrets.baseline

secrets-scan: ## Scan for secrets
	@echo "$(GREEN)Scanning for secrets...$(NC)"
	$(POETRY_RUN) detect-secrets scan --baseline .secrets.baseline

# ============================================================================
##@ 📊 Project Info
# ============================================================================

.PHONY: info versions

info: ## Show project information
	@echo "$(GREEN)Project: Local Lakehouse$(NC)"
	@echo "Version: 0.1.0"
	@echo "Author:  Andres Manrique"
	@echo ""
	@echo "$(YELLOW)Directory Structure:$(NC)"
	@tree -L 2 -I '__pycache__|*.pyc|target|dbt_packages|logs' || ls -R

versions: ## Show tool versions
	@echo "$(GREEN)Tool Versions:$(NC)"
	@echo "Python:      $$(python --version 2>&1)"
	@echo "Poetry:      $$($(POETRY) --version 2>&1)"
	@echo "Ruff:        $$($(POETRY_RUN) ruff --version 2>&1)"
	@echo "Pre-commit:  $$($(POETRY_RUN) pre-commit --version 2>&1)"
	@echo "Docker:      $$(docker --version 2>&1)"
