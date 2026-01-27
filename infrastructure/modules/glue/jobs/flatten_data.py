import sys
import logging
from datetime import date
from awsglue.utils import getResolvedOptions
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import col, explode_outer, to_json
from pyspark.sql.types import StructType, ArrayType

# ------------------------------------------------------------------
# Logging setup (Glue -> CloudWatch)
# ------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
)
logger = logging.getLogger("jsonl-to-parquet-flattened")

# ------------------------------------------------------------------
# Resolve job arguments
# ------------------------------------------------------------------
try:
    args = getResolvedOptions(
        sys.argv,
        ["RAW_BUCKET", "RAW_PREFIX", "FLATTENED_BUCKET", "FLATTENED_PREFIX"]
    )
except Exception:
    logger.exception("Failed to resolve Glue job arguments")
    raise

RAW_S3_PATH = f"s3://{args['RAW_BUCKET']}/{args['RAW_PREFIX']}"
FLATTENED_S3_PATH = f"s3://{args['FLATTENED_BUCKET']}/{args['FLATTENED_PREFIX']}"

logger.info("Job arguments resolved")
logger.info("RAW_S3_PATH=%s", RAW_S3_PATH)
logger.info("FLATTENED_S3_PATH=%s", FLATTENED_S3_PATH)

# ------------------------------------------------------------------
# Spark session
# ------------------------------------------------------------------
try:
    spark = (
        SparkSession.builder
        .appName("jsonl-to-parquet-flattened")
        .getOrCreate()
    )
except Exception:
    logger.exception("Failed to create SparkSession")
    raise


# ------------------------------------------------------------------
# Main ETL
# ------------------------------------------------------------------
def s3_jsonl_to_flat_parquet(jsonl_path: str, parquet_path: str):
    logger.info("Starting ETL for %s", jsonl_path)

    try:
        df_flat = spark.read.json(f"{RAW_S3_PATH}/{jsonl_path}")
    except Exception:
        logger.error("Aborting ETL due to read failure")
        raise

    run_date = date.today().isoformat()
    output_path = f"{FLATTENED_S3_PATH}/{parquet_path}/run_date={run_date}"

    logger.info("Writing Parquet to %s", output_path)

    try:
        (
            df_flat.write
            .mode("overwrite")
            .option("compression", "snappy")
            .parquet(output_path)
        )
    except Exception:
        logger.exception("Failed to write Parquet output to %s", output_path)
        raise

    logger.info("ETL completed successfully for %s", jsonl_path)


# ------------------------------------------------------------------
# Entry point
# ------------------------------------------------------------------
if __name__ == "__main__":
    try:
        s3_jsonl_to_flat_parquet("reviews/Amazon_Fashion_Review.jsonl", "reviews")
        s3_jsonl_to_flat_parquet("meta_data/Amazon_Fashion_Meta.jsonl", "meta_data")
    except Exception:
        logger.exception("Job failed")
        raise
    finally:
        logger.info("Stopping Spark session")
        spark.stop()
