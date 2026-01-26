
from __future__ import annotations
import sys
import logging
import socket
import json
from datetime import datetime

from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from pyspark.sql import DataFrame
from pyspark.sql.functions import col, explode_outer
from pyspark.sql.types import StructType, ArrayType


# ----------------- Helpers for CLI args (handles Glue injected args) -----------------
def parse_optional_arg(name: str, default=None):
    flag = f"--{name}"
    if flag in sys.argv:
        idx = sys.argv.index(flag)
        if idx + 1 < len(sys.argv):
            val = sys.argv[idx + 1]
            if not val.startswith("--"):
                return val
    # also try underscored variant
    alt_flag = f"--{name.replace('-', '_')}"
    if alt_flag in sys.argv:
        idx = sys.argv.index(alt_flag)
        if idx + 1 < len(sys.argv):
            val = sys.argv[idx + 1]
            if not val.startswith("--"):
                return val
    return default

args = getResolvedOptions(
    sys.argv,
    ["RAW_BUCKET", "RAW_PREFIX", "FLATTENED_BUCKET", "FLATTENED_PREFIX"]
)

RAW_S3_PATH = f"s3://{args['RAW_BUCKET']}/{args['RAW_PREFIX']}"
FLATTENED_S3_PATH = f"s3://{args['FLATTENED_BUCKET']}/{args['FLATTENED_PREFIX']}"


# ----------------- Spark / Glue contexts -----------------
sc = SparkContext.getOrCreate()
glueContext = GlueContext(sc)
spark = glueContext.spark_session

# Root Python logging (ensures messages appear in CloudWatch driver logs)
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
pylogger = logging.getLogger()
pylogger.setLevel(logging.INFO)
glue_logger = glueContext.get_logger()


# ----------------- Collision-safe naming helper -----------------
def unique_name(base: str, existing: set) -> str:
    """Return a name based on `base` that's not in `existing` and add it to existing."""
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

# ----------------- Flattening utilities (collision-safe) -----------------
def flatten_structs(df: DataFrame) -> DataFrame:
    """
    Expand top-level StructType columns into separate columns (parent_child), avoiding name collisions.
    """
    schema = df.schema
    struct_fields = [f for f in schema.fields if isinstance(f.dataType, StructType)]
    if not struct_fields:
        return df

    existing = set(df.columns)
    select_cols = []
    for field in schema.fields:
        name = field.name
        dtype = field.dataType
        if isinstance(dtype, StructType):
            if name in existing:
                existing.remove(name)
            for child in dtype:
                child_name = child.name
                base = f"{name}_{child_name}"
                uniq = unique_name(base, existing)
                select_cols.append(col(f"{name}.{child_name}").alias(uniq))
                pylogger.debug("Expanding struct %s.%s -> %s", name, child_name, uniq)
        else:
            if name in existing:
                existing.remove(name)
                select_cols.append(col(name))
            else:
                safe = unique_name(name, existing)
                select_cols.append(col(name).alias(safe))
                pylogger.debug("Renaming non-struct column %s -> %s to avoid conflict", name, safe)
    return df.select(*select_cols)

def find_array_column(df: DataFrame):
    """Return first array column name if any, else None."""
    for f in df.schema.fields:
        if isinstance(f.dataType, ArrayType):
            return f.name
    return None

def sanitize_column_names(df: DataFrame) -> DataFrame:
    """Ensure column names contain no dots and are unique. Apply deterministic suffixes if needed."""
    cols = list(df.columns)
    new_cols = []
    existing = set()
    for c in cols:
        clean = c.replace(".", "_")
        if clean in existing:
            clean = unique_name(clean, existing)
            pylogger.info("sanitize: renamed duplicate column to %s", clean)
        else:
            existing.add(clean)
        new_cols.append((c, clean))
    out = df
    for orig, new in new_cols:
        if orig != new:
            out = out.withColumnRenamed(orig, new)
    return out

def flatten_df(df: DataFrame, max_iters: int = 50) -> DataFrame:
    """
    Recursively flatten structs and explode arrays.
    """
    cur = df
    it = 0
    while it < max_iters:
        it += 1
        schema = cur.schema
        has_struct = any(isinstance(f.dataType, StructType) for f in schema.fields)
        arr_col = find_array_column(cur)
        if not has_struct and not arr_col:
            pylogger.info("Flattening complete after %d iterations", it-1)
            break
        if has_struct:
            pylogger.info("Iteration %d: expanding struct fields", it)
            cur = flatten_structs(cur)
            continue
        if arr_col:
            pylogger.info("Iteration %d: exploding array column '%s'", it, arr_col)
            cur = cur.withColumn(arr_col, explode_outer(col(arr_col)))
            continue
    if it >= max_iters:
        pylogger.warning("Reached max iterations in flatten_df; result may still contain nested types.")
    cur = sanitize_column_names(cur)
    return cur

# ----------------- Robust read_json: distributed Python parsing -----------------
def _object_pairs_lastwin(pairs):
    """object_pairs_hook that keeps the last value when duplicate keys occur."""
    d = {}
    for k, v in pairs:
        d[k] = v  # last write wins
    return d

def parse_json_line_safe(line: str):
    """Parse a JSON line string to python dict, return None on parse error."""
    try:
        s = line.strip()
        if not s:
            return None
        return json.loads(s, object_pairs_hook=_object_pairs_lastwin)
    except Exception:
        return None

def read_json(path: str):
    """
    Read JSON lines from S3 path via sc.textFile, parse with python json.loads (distributed),
    and convert to DataFrame. This avoids Spark's duplicate-key schema inference errors.
    """
    pylogger.info("Robust reading JSON via sc.textFile from %s", path)
    try:
        rdd = sc.textFile(path)
    except Exception as e:
        pylogger.exception("sc.textFile failed for path=%s : %s", path, e)
        raise

    parsed = rdd.map(lambda ln: ln.strip()).filter(lambda ln: ln != "").map(lambda ln: (ln, parse_json_line_safe(ln)))
    total = parsed.count()
    parsed_ok = parsed.filter(lambda t: t[1] is not None)
    parsed_bad = parsed.filter(lambda t: t[1] is None)
    ok_count = parsed_ok.count()
    bad_count = parsed_bad.count()
    pylogger.info("Parsed JSON lines: total=%d ok=%d failed=%d", total, ok_count, bad_count)

    if ok_count == 0:
        pylogger.warning("No valid JSON records parsed from %s", path)
        return spark.createDataFrame([], schema=None)

    dict_rdd = parsed_ok.map(lambda t: t[1])
    try:
        df = spark.createDataFrame(dict_rdd)
        pylogger.info("Created DataFrame from parsed JSON with columns: %s", df.columns)
    except Exception as e:
        pylogger.exception("Failed to create DataFrame from parsed JSON RDD: %s", e)
        sample = dict_rdd.take(1000)
        if not sample:
            return spark.createDataFrame([], schema=None)
        df = spark.createDataFrame(sample)
    return df

# ----------------- I/O write utilities -----------------
def write_df(df: DataFrame, out_uri: str):
    pylogger.info("Writing DataFrame to %s as %s (partition_by=%s coalesce=%d compression=%s)",
                  out_uri, 'parquet', 'none', 0, 'none')


    writer = df.write.mode('overwrite')

    writer.parquet(out_uri)

# ----------------- Main processing per dataset -----------------
def process_one(input_path: str, output_prefix: str, label: str) -> bool:
    pylogger.info("START processing %s: input=%s output_prefix=%s", label, input_path, output_prefix)
    try:
        df = read_json(input_path)
        pylogger.info("%s: initial schema/cols: %s", label, ", ".join([f"{n}:{t}" for n,t in zip(df.columns, df.dtypes)]))
        flattened = flatten_df(df)
        pylogger.info("%s: flattened schema cols=%d", label, len(flattened.columns))

        out_uri = f"{FLATTENED_S3_PATH}/{output_prefix}"
        write_df(flattened, out_uri)
        pylogger.info("%s: wrote flattened output to %s", label, out_uri)


        return True
    except Exception as e:
        pylogger.exception("%s: failed to process %s : %s", label, input_path, e)
        return False

# ----------------- Entrypoint -----------------
def main():
    pylogger.info("Host: %s, Python: %s", socket.gethostname(), sys.version.replace('\n', ' '))


    review_input = f"{RAW_S3_PATH}/reviews/Amazon_Fashion_Review.jsonl"
    meta_input = f"{RAW_S3_PATH}/meta_data/Amazon_Fashion_Meta.jsonl"
    pylogger.info("Computed input paths: review=%s meta=%s", review_input, meta_input)

    review_ok = process_one(review_input, "reviews", "review_dataset")
    meta_ok = process_one(meta_input, "meta_data", "meta_dataset")

    pylogger.info("Processing summary: review_ok=%s meta_ok=%s", review_ok, meta_ok)

if __name__ == "__main__":
    main()