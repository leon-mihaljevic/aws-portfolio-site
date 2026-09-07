"""
portfolio-cache-invalidation

Triggered by S3 "object created" events on the site bucket.
Invalidates the CloudFront cache so updated files are served immediately
instead of waiting for the old cached version to expire (default TTL).

Environment variables:
    DISTRIBUTION_ID - the CloudFront distribution ID to invalidate
"""

import os
import boto3

def lambda_handler(event, context):
    distribution_id = os.environ["DISTRIBUTION_ID"]
    cf = boto3.client("cloudfront")

    response = cf.create_invalidation(
        DistributionId=distribution_id,
        InvalidationBatch={
            "Paths": {
                "Quantity": 1,
                "Items": ["/*"],
            },
            "CallerReference": str(context.aws_request_id),
        },
    )

    invalidation_id = response["Invalidation"]["Id"]
    print(f"Created invalidation: {invalidation_id}")

    return {"statusCode": 200, "invalidationId": invalidation_id}
