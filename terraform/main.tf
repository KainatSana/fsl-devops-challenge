# In this file put all the logic to crete the proper infraestructure
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

locals {
  project   = "fsl-devops"
  env       = var.env
  suffix    = var.account_suffix
  logs_bucket_name = "${local.project}-${local.env}-${local.suffix}"
  site_bucket_name = "${local.project}-${local.env}-${local.suffix}"
  tags = merge(var.tags, {
    Project =local.project
    Env = local.env
  })
}

resource "aws_s3_bucket" "logs" {
  bucket = local.logs_bucket_name
  force_destroy = true
  tags =local.tags
  }

  resource "aws_s3_bucket_public_access_block" "logs" {
    bucket = aws_s3_bucket.logs.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }

  resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
    bucket = aws_s3_bucket.logs.id
    rule {
        apply_server_side_encryption_by_default { sse_algorithm = "AES256"}
    }
  }

  resource "aws_s3_bucket_ownership_controls" "logs" {
    bucket = aws_s3_bucket.logs.id
    rule {
        object_ownership = "BucketOwnerPreferred"
  }
  }
 
 resource "aws_s3_bucket_acl" "logs_acl" {
    depends_on = [ aws_s3_bucket_ownership_controls.logs ]
    bucket = aws_s3_bucket.logs.id
    acl    = "private"
  }
  #site bucket

  resource "aws_s3_bucket" "site" {
    bucket = local.site_bucket_name
    force_destroy = true
    tags =local.tags
  }

   resource "aws_s3_bucket_ownership_controls" "site" {
    bucket = aws_s3_bucket.site.id
    rule {
        object_ownership = "BucketOwnerPreferred"
  }
  }

  resource "aws_s3_bucket_public_access_block" "site" {
    bucket = aws_s3_bucket.site.id
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
  }

    resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
        bucket = aws_s3_bucket.site.id
        rule {
            apply_server_side_encryption_by_default { sse_algorithm = "AES256"}
        }
    }

    resource "aws_s3_bucket_acl" "site_acl" {
        depends_on = [ aws_s3_bucket_ownership_controls.logs ]
        bucket = aws_s3_bucket.site.id
        acl    = "private"
  }
  # cdn

  resource "aws_cloudfront_origin_access_control" "oac"{
      name                              = "${local.project}-${local.env}-oac"
      description                       = "OAC for ${local.env}"
      origin_access_control_origin_type = "s3"
      signing_behavior                  = "always"
      signing_protocol                  = "sigv4"
    }


resource "aws_cloudfront_distribution" "cdn" {
    enabled             = true
    is_ipv6_enabled     = true
    comment             = "C${local.project} ${local.env}"
    default_root_object = "index.html"
    price_class = "PriceClass_100"
    tags = local.tags

    default_cache_behavior {
        target_origin_id = "s3-origin-${local.env}"
        viewer_protocol_policy = "redirect-to-https"
        allowed_methods = ["GET", "HEAD"]
        cached_methods = ["GET", "HEAD"]
        cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
    }

    restrictions {
        geo_restriction {
        restriction_type = "whitelist"
        locations        = ["US", "CA", "GB", "DE"]
        }
  }

    viewer_certificate {
        cloudfront_default_certificate = true
    }

    origin {
        domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
        origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
        origin_id                = "s3-origin-${local.env}"
    }
 
   logging_config {
    bucket          = aws_s3_bucket.logs.bucket_domain_name   
    include_cookies = false
    prefix = "cloudfront/${local.env}/"
  }

}
    