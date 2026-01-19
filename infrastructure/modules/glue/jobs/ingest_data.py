from pathlib import Path
import logging
import requests
import boto3
from botocore.exceptions import ClientError
import gzip
import shutil
import sys
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

def download_zipped_data(url: str, output_dir: Path):
    with requests.get(url, stream=True) as request:
        request.raise_for_status()
        with open(output_dir, "wb") as file:
            for chunk in request.iter_content(chunk_size=8192):
                file.write(chunk)

def unzip_raw_data(zipped_data_path: Path, output_dir: Path):
    with gzip.open(zipped_data_path, "rb") as zipped:
        with open(output_dir, "wb") as unzipped:
            shutil.copyfileobj(zipped, unzipped)

def upload_raw_to_s3(raw_data: Path, s3_bucket: str, s3_key: str):
    s3_client = boto3.client('s3')
    try:
        response = s3_client.upload_file(str(raw_data), s3_bucket, s3_key)
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