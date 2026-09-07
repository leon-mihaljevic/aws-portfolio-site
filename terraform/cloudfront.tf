resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "oac-dexthida-portfolio-site-project.s3.eu-central-1.-mthgw1jvcvw"
  description                       = "Created by CloudFront"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = ""
  price_class         = "PriceClass_All"
  http_version        = "http2"

  # Pre-existing WAF Web ACL, created by CloudFront's console default.
  # Not managed by Terraform (no aws_wafv2_web_acl resource) - referenced
  # as-is so `plan` doesn't try to remove it.
  web_acl_id = "arn:aws:wafv2:us-east-1:260317865228:global/webacl/CreatedByCloudFront-a456be0c/04e1116a-c6d9-4644-b4f2-bdc6938ea026"

  tags = {
    Name = "Portfolio Project Distribution"
  }

  origin {
    origin_id                = "dexthida-portfolio-site-project.s3.eu-central-1.amazonaws.com-mthgvr5f7ko"
    domain_name               = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "dexthida-portfolio-site-project.s3.eu-central-1.amazonaws.com-mthgvr5f7ko"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods          = ["GET", "HEAD"]
    compress                = true

    # AWS managed "CachingOptimized" policy - not a custom cache policy
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    # minimum_protocol_version intentionally omitted - not configurable
    # when using the default *.cloudfront.net certificate; AWS assigns
    # "TLSv1" automatically in this mode.
  }
}
