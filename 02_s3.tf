## S3 buckets and policies

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
