terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "6.9.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#local 

locals {
  project = "fsl-devops"
  env     = var.env
  account_suffix = var.account_suffix
  logs_bucket_name = "${local.project}-${local.env}-${local.account_suffix}"
  site_bucket_name = "${local.project}-${local.env}-${local.account_suffix}"
  tags = merge(var.tags, {
    Project = local.project
    Env     = local.env
  })
}
# S3
resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket_name
  force_destroy = true
  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = local.logs_bucket_name
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]

  bucket = aws_s3_bucket.logs.id
  acl    = "log-delivery-write"
}

# site_bucket

resource "aws_s3_bucket" "site" {
  bucket = local.site_bucket_name
  force_destroy = true
  tags = local.tags
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = local.site_bucket_name
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "site_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]

  bucket = aws_s3_bucket.site.id
  acl    = "log-delivery-write"
}

#S3 Buket policy to allow cloufront access

resource"aws_s3_bucket_policy" "site_policy" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "AllowCloudfrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action = "s3:GetObject"
        Resource = "${aws_s3_bucket.site.arn}/*"
        Condition ={
            StringEquals ={
                "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
            }
        }
      }
    ]
  })
}
# cloudfront distribution

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${local.project}-${local.env}-oac"
  description                       = "OAC for ${local.env}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "cdn" {
  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = "s3_origin-${local.env}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${local.project}-${local.env}"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_regional_domain_name
    prefix          = "clpoudfront/${local.env}/"
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3_origin-${local.env}"
    viewer_protocol_policy = "redirect-to-https"
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
      locations        = []
    }
  }

  tags = local.tags


  viewer_certificate {
    cloudfront_default_certificate = true
  }
}