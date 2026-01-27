from pathlib import Path
import logging
import requests
import boto3
from botocore.exceptions import ClientError
import gzip
import shutil
import sys
import re
import json
from awsglue.utils import getResolvedOptions

REVIEW_DATA_URL = "https://mcauleylab.ucsd.edu/public_datasets/data/amazon_2023/raw/review_categories/Amazon_Fashion.jsonl.gz"
META_DATA_URL = "https://mcauleylab.ucsd.edu/public_datasets/data/amazon_2023/raw/meta_categories/meta_Amazon_Fashion.jsonl.gz"

LOCAL_REVIEW_GZ_PATH = Path("/tmp/Amazon_Fashion_Review.jsonl.gz")
LOCAL_META_GZ_PATH = Path("/tmp/Amazon_Fashion_Meta.jsonl.gz")

LOCAL_REVIEW_JSON = Path("/tmp/Amazon_Fashion_Review.jsonl")
LOCAL_META_JSON = Path("/tmp/Amazon_Fashion_Meta.jsonl")

args = getResolvedOptions(sys.argv, ["RAW_BUCKET", "RAW_PREFIX"])

S3_RAW_BUCKET = args["RAW_BUCKET"]
S3_RAW_DATA_KEY = args["RAW_PREFIX"]

###
# Helper functions
###
def normalize_key(key):
    key = key.strip().lower()
    key = re.sub(r"[^a-z0-9]+", "_", key)
    key = re.sub(r"_+", "_", key)
    key = key.strip("_")
    return key or "field"


def normalize_object(obj):
    if isinstance(obj, dict):
        seen = {}
        out = {}
        for k, v in obj.items():
            base = normalize_key(str(k))
            if base in seen:
                seen[base] += 1
                key = f"{base}__dup_{seen[base]}"
            else:
                seen[base] = 0
                key = base
            out[key] = normalize_object(v)
        return out
    if isinstance(obj, list):
        return [normalize_object(x) for x in obj]
    return obj


#Simply downloads the gzip files from url
def download_zipped_data(url: str, output_dir: Path):
    with requests.get(url, stream=True) as request:
        request.raise_for_status()
        with open(output_dir, "wb") as file:
            for chunk in request.iter_content(chunk_size=8192):
                file.write(chunk)

#Unzips the files and normalizes them if needed
def unzip_raw_data(zipped_data_path: Path, output_dir: Path):
    """
    Unzip a gzipped JSONL file, validate JSON, normalize objects,
    and write to an uncompressed JSONL file.
    """
    with gzip.open(zipped_data_path, "rt", encoding="utf-8") as src, open(
        output_dir, "w", encoding="utf-8"
    ) as dst:
        for line_no, line in enumerate(src, start=1):
            line = line.strip()
            if not line:
                continue

            try:
                obj = json.loads(line)
            except json.JSONDecodeError as e:
                logging.error(
                    f"Invalid JSON in {zipped_data_path} at line {line_no}"
                )
                continue  # skip bad lines instead of crashing the job

            cleaned = normalize_object(obj)
            dst.write(json.dumps(cleaned, ensure_ascii=True) + "\n")

#Uploads the jsonl files to the raw s3 folder
def upload_raw_to_s3(raw_data: Path, s3_bucket: str, s3_key: str):
    s3_client = boto3.client('s3')
    try:
        s3_client.upload_file(str(raw_data), s3_bucket, s3_key)
    except ClientError as e:
        logging.error(e)
        return False
    return True

def main():
    #Download the zipped review and meta data
    download_zipped_data(REVIEW_DATA_URL, LOCAL_REVIEW_GZ_PATH)
    download_zipped_data(META_DATA_URL, LOCAL_META_GZ_PATH)

    #Unzip both files locally
    unzip_raw_data(LOCAL_REVIEW_GZ_PATH, LOCAL_REVIEW_JSON)
    unzip_raw_data(LOCAL_META_GZ_PATH, LOCAL_META_JSON)

    #Upload the data to the s3 bucket
    upload_raw_to_s3(
        LOCAL_REVIEW_JSON,
        S3_RAW_BUCKET,
        f"{S3_RAW_DATA_KEY}/reviews/Amazon_Fashion_Review.jsonl"
    )

    upload_raw_to_s3(
        LOCAL_META_JSON,
        S3_RAW_BUCKET,
        f"{S3_RAW_DATA_KEY}/meta_data/Amazon_Fashion_Meta.jsonl"
    )
        

if __name__ == "__main__":
    main()