FROM apache/airflow:3.0.6
WORKDIR /opt/airflow
COPY requirements-dbt.txt requirements-dbt.txt
RUN pip install --no-cache-dir apache-airflow=="${AIRFLOW_VERSION}" -r requirements-dbt.txt
