# Local Lakehouse

This project provides a complete, local data lakehouse environment using Docker. It's designed for development and testing of data pipelines and analytics workloads.

## Architecture

The local lakehouse is composed of the following services, orchestrated by Docker Compose:

*   **Data Lake:**
    *   **MinIO:** An S3-compatible object storage service that acts as the data lake.
    *   **Nessie:** A data catalog for Apache Iceberg, providing Git-like semantics for data versioning.
*   **Query Engine:**
    *   **Trino:** A distributed SQL query engine for querying data in the lakehouse. It's configured with a coordinator and multiple workers.
*   **Orchestration:**
    *   **Docker Compose:** Used to define and run the multi-container Docker applications.
    *   **Makefile:** Provides a simple command-line interface to manage the lakehouse services.

## Technologies

*   [Docker](https://www.docker.com/)
*   [Docker Compose](https://docs.docker.com/compose/)
*   [MinIO](https://min.io/)
*   [Nessie](https://projectnessie.org/)
*   [Trino](https://trino.io/)
*   [Apache Iceberg](https://iceberg.apache.org/)
*   [Poetry](https://python-poetry.org/)
*   [Ruff](https://beta.ruff.rs/docs/)
*   [pre-commit](https://pre-commit.com/)

## Usage

This project uses a `Makefile` to orchestrate the lakehouse services.

### Prerequisites

*   [Docker](https://docs.docker.com/get-docker/) installed and running.
*   [Make](https://www.gnu.org/software/make/)

### Service Management

*   **Start all services:**

    ```bash
    make start
    ```

*   **Stop all services:**

    ```bash
    make stop
    ```

*   **View logs:**

    ```bash
    make logs
    ```

*   **View status:**

    ```bash
    make status
    ```

### Data Exploration

*   **List MinIO buckets:**

    ```bash
    make list-buckets
    ```

*   **List Trino catalogs:**

    ```bash
    make list-catalogs
    ```

*   **List schemas in a catalog:**

    ```bash
    make list-schemas catalog=<catalog_name>
    ```

*   **List tables in a schema:**

    ```bash
    make list-tables catalog=<catalog_name> schema=<schema_name>
    ```

## Code Quality

This project uses `ruff` for linting and formatting, and `pre-commit` to automate running checks before each commit.

### Ruff

To manually run the linter, use the following command:

```bash
poetry run ruff check .
```

To automatically fix linting issues, use:

```bash
poetry run ruff check . --fix
```

### pre-commit

The `pre-commit` hooks are configured in the `.pre-commit-config.yaml` file. They will run automatically when you commit changes.

To manually run the pre-commit hooks on all files, use:

```bash
poetry run pre-commit run --all-files
```
