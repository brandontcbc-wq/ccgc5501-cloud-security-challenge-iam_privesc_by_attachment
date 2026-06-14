#=====================================================
# CLOUDTRAIL (OPTIONAL - FOR DETECTION PRACTICE)
# Enable this to log all actions for blue team analysis
#=====================================================

resource "aws_s3_bucket" "cloudtrail" {
  count         = var.enable_cloudtrail ? 1 : 0
  bucket        = "cg-cloudtrail-${local.resource_suffix}-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name     = "cg-cloudtrail-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.cloudtrail[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.cloudtrail[0].arn
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/cg-trail-${local.resource_suffix}"
          }
        }
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.cloudtrail[0].arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "AWS:SourceArn" = "arn:aws:cloudtrail:${var.region}:${data.aws_caller_identity.current.account_id}:trail/cg-trail-${local.resource_suffix}"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = "cg-trail-${local.resource_suffix}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail[0].id
  include_global_service_events = true
  is_multi_region_trail         = false
  enable_logging                = true

  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  tags = {
    Name     = "cg-trail-${local.resource_suffix}"
    Scenario = var.scenario_name
    Stack    = "CloudGoat"
  }

  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

output "cloudtrail_bucket" {
  description = "S3 bucket containing CloudTrail logs (for detection analysis)"
  value       = var.enable_cloudtrail ? aws_s3_bucket.cloudtrail[0].id : "CloudTrail not enabled"
}
