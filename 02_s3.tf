## S3 buckets and policies

data "template_file" "cdn_bucket_policy" {
  template = "${file("${path.module}/templates/cdn_bucket_policy.json")}"

  vars {
    bucket_name                 = "${var.cdn_bucket}"
    cf_s3_canonical_user_id     = "${aws_cloudfront_origin_access_identity.s3_id.s3_canonical_user_id}"
    aws_account_id              = "${var.aws_account_id}"
  }
}

resource "aws_s3_bucket" "cdn_bucket" {
    bucket = "${var.cdn_bucket}"
    acl = "private"
    policy = "${data.template_file.cdn_bucket_policy.rendered}"

    tags {
      Cluster = "${var.cluster_name}"
      Owner = "${var.tag_Owner}"
      builtWith = "terraform"
    }
}

resource "aws_s3_bucket" "uploads_bucket" {
    bucket = "${var.uploads_bucket}"
    acl = "private"

    cors_rule {
        # allowed_origins should be website domain only!
        allowed_origins = ["*"]
        allowed_methods = ["PUT","POST","GET"]
        allowed_headers = ["*"]
        expose_headers  = ["ETag"]
    }

    tags {
      Cluster = "${var.cluster_name}"
      Owner = "${var.tag_Owner}"
      builtWith = "terraform"
    }
}

## CloudFront
resource "aws_cloudfront_origin_access_identity" "s3_id" {
  comment = "Access Identity for private s3 bucket"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
    origin {
        domain_name = "${cdn_bucket}.s3.amazonaws.com"
        origin_id = "S3-${aws_s3_bucket.cdn_bucket.bucket}"

        s3_origin_config {
          origin_access_identity = "${aws_cloudfront_origin_access_identity.s3_id.cloudfront_access_identity_path}"
        }
    }

    enabled             = true
    default_root_object = "index.html"

    # aliases = ["mysite.example.com", "yoursite.example.com"]

    restrictions {
      geo_restriction {
        restriction_type = "none"
      }
    }

    tags {
      Environment = "production"
    }

    viewer_certificate {
      cloudfront_default_certificate = true
    }

    # If there is a 404, return index.html with a HTTP 200 Response
    custom_error_response {
        error_caching_min_ttl = 3000
        error_code = 404
        response_code = 200
        response_page_path = "/index.html"
    }

    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-${aws_s3_bucket.cdn_bucket.bucket}"

        # Forward all query strings, cookies and headers
        forwarded_values {
            query_string = true
        }
        viewer_protocol_policy = "allow-all"
        min_ttl                = 0
        default_ttl            = 3600
        max_ttl                = 86400
    }

    # Distributes content to Asia, US and Europe
    price_class = "PriceClass_200"
}
