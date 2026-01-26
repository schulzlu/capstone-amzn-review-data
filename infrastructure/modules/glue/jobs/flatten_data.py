import sys
import re
import json
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
# Helpers
# ------------------------------------------------------------------
def normalize(name: str) -> str:
    return re.sub(r"[^a-zA-Z0-9]+", "_", name.lower()).strip("_")


def unique_name(base: str, existing: set) -> str:
    if base not in existing:
        existing.add(base)
        return base
    i = 1
    while True:
        candidate = f"{base}_{i}"
        if candidate not in existing:
            existing.add(candidate)
            return candidate
        i += 1


def flatten_structs(df: DataFrame) -> DataFrame:
    logger.debug("Flattening struct columns")
    existing = set()
    select_cols = []

    for field in df.schema.fields:
        name = field.name
        dtype = field.dataType

        if isinstance(dtype, StructType):
            for child in dtype.fields:
                base = normalize(f"{name}_{child.name}")
                uniq = unique_name(base, existing)
                select_cols.append(col(f"{name}.{child.name}").alias(uniq))
        else:
            base = normalize(name)
            uniq = unique_name(base, existing)
            select_cols.append(col(name).alias(uniq))

    return df.select(*select_cols)


def explode_arrays(df: DataFrame) -> DataFrame:
    logger.debug("Exploding array columns")
    for field in df.schema.fields:
        if isinstance(field.dataType, ArrayType):
            name = field.name
            elem = field.dataType.elementType
            if isinstance(elem, StructType):
                df = df.withColumn(name, explode_outer(col(name)))
            else:
                df = df.withColumn(name, to_json(col(name)))
    return df


def deduplicate_columns_final(df: DataFrame) -> DataFrame:
    logger.debug("Deduplicating final column names")
    seen = set()
    select_exprs = []

    for c in df.columns:
        if c not in seen:
            seen.add(c)
            select_exprs.append(col(c))
        else:
            i = 1
            while f"{c}_{i}" in seen:
                i += 1
            new_name = f"{c}_{i}"
            seen.add(new_name)
            select_exprs.append(col(c).alias(new_name))

    return df.select(*select_exprs)


def _object_pairs_lastwin(pairs):
    d = {}
    for k, v in pairs:
        d[k] = v
    return d


def read_json_safe(spark: SparkSession, path: str) -> DataFrame:
    logger.info("Reading JSONL from %s", path)
    try:
        rdd = spark.sparkContext.textFile(path)

        parsed = (
            rdd
            .map(lambda ln: ln.strip())
            .filter(lambda ln: ln != "")
            .map(lambda ln: json.loads(ln, object_pairs_hook=_object_pairs_lastwin))
        )

        df = spark.createDataFrame(parsed, samplingRatio=1.0)
        logger.info("JSON read successful. Initial columns=%d", len(df.columns))
        return df

    except json.JSONDecodeError as e:
        logger.error("JSON decoding failed for input path %s", path)
        logger.exception(e)
        raise

    except Exception:
        logger.exception("Unexpected failure while reading JSONL from %s", path)
        raise


def flatten_df(df: DataFrame, max_iters: int = 50) -> DataFrame:
    cur = df

    for i in range(max_iters):
        try:
            has_struct = any(isinstance(f.dataType, StructType) for f in cur.schema.fields)
            has_array = any(isinstance(f.dataType, ArrayType) for f in cur.schema.fields)

            logger.info(
                "Flatten iteration %d | structs=%s | arrays=%s | columns=%d",
                i, has_struct, has_array, len(cur.columns)
            )

            if not has_struct and not has_array:
                logger.info("Flattening complete after %d iterations", i)
                break

            if has_struct:
                cur = flatten_structs(cur)

            if has_array:
                cur = explode_arrays(cur)

        except Exception:
            logger.exception("Failure during flatten iteration %d", i)
            raise

    else:
        logger.warning("Max flatten iterations (%d) reached", max_iters)

    return cur


# ------------------------------------------------------------------
# Main ETL
# ------------------------------------------------------------------
def s3_jsonl_to_flat_parquet(jsonl_path: str, parquet_path: str):
    logger.info("Starting ETL for %s", jsonl_path)

    try:
        df_raw = read_json_safe(spark, f"{RAW_S3_PATH}/{jsonl_path}")
    except Exception:
        logger.error("Aborting ETL due to read failure")
        raise

    try:
        df_flat = flatten_df(df_raw)
        df_flat = deduplicate_columns_final(df_flat)
    except Exception:
        logger.error("Aborting ETL due to flatten failure")
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
        #s3_jsonl_to_flat_parquet("meta_data/Amazon_Fashion_Meta.jsonl", "meta_data")
    except Exception:
        logger.exception("Job failed")
        raise
    finally:
        logger.info("Stopping Spark session")
        spark.stop()
