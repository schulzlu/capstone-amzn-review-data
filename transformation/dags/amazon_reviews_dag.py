from datetime import datetime, timedelta
import os

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.models import Variable

DBT_PROJECT_DIR = Variable.get("DBT_PROJECT_DIR", "/opt/airflow/amazon_project")
SUMMARY_WINDOW_DAYS = Variable.get("SUMMARY_WINDOW_DAYS", "30")

default_args = {
    "owner": "airflow",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="capstone_amazon_etl",
    start_date=datetime(2025, 1, 1),
    schedule="0 2 * * *", 
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["dbt", "currency"],
) as dag:

    dbt_debug = BashOperator(
        task_id="dbt_debug",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && "
            f"dbt debug --profiles-dir . --project-dir .  || true"
        ),
        env=os.environ,
    )

    # install deps (if you use packages.yml in dbt; cheap if cached)
    dbt_deps = BashOperator(
        task_id="dbt_deps",
        bash_command=f"cd {DBT_PROJECT_DIR} && dbt deps --profiles-dir . --project-dir .",
        env=os.environ,
    )

    # run staging + core models
    dbt_run_staging = BashOperator(
        task_id="dbt_run_staging",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && "
            f"dbt run --profiles-dir . --project-dir . --select stg_reviews stg_meta "
            f"--vars '{{summary_window_days: {SUMMARY_WINDOW_DAYS}}}'"
        ),
        env=os.environ,
    )

    # run marts (trend + summary)
    dbt_run_marts = BashOperator(
        task_id="dbt_run_marts",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && "
            f"dbt run --profiles-dir . --project-dir . "
            f"--select fact_helpful_products "
            f"--select fact_product_overall "
            f"--select fact_product_sentiment "
            f"--select fact_product_reviews "
            f"--select fact_rating_distribution "
            f"--select fact_review_quality "
            f"--select fact_seller_reviews "
            f"--select fact_top_helpful_reviews "
            f"--vars '{{summary_window_days: {SUMMARY_WINDOW_DAYS}}}'"
        ),
        env=os.environ,
    )

    # run tests
    dbt_test = BashOperator(
        task_id="dbt_test",
        bash_command=(
            f"cd {DBT_PROJECT_DIR} && "
            f"dbt test --profiles-dir . --project-dir . "
            f"--select schema"
        ),
        env=os.environ,
    )

    # DAG order
    dbt_debug >> dbt_deps >> dbt_run_staging >> dbt_run_marts >> dbt_test