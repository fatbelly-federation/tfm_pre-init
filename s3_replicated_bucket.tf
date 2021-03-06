# To provide a backup of the one bucket to rule them all
# create an S3 bucket in a different region that
# the primary bucket will replicate to

# You'll need to update terraformt.tfvars, if you want to use this backup bucket

# references
# https://www.cloudendure.com/blog/aws-s3-replication-6-things-know/
# https://aws.amazon.com/blogs/aws/new-cross-region-replication-for-amazon-s3/
# https://www.terraform.io/docs/providers/aws/r/s3_bucket.html

# Create role for S3 to use when replicating
resource "aws_iam_role" "replication" {
  name = "tf-iam-role-replication"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "s3.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "replication" {
  name = "tf-iam-role-policy-replication"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:GetReplicationConfiguration",
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.terraform_tf_bucket.arn}"
      ]
    },
    {
      "Action": [
        "s3:GetObjectVersion",
        "s3:GetObjectVersionAcl"
      ],
      "Effect": "Allow",
      "Resource": [
        "${aws_s3_bucket.terraform_tf_bucket.arn}/*"
      ]
    },
    {
      "Action": [
        "s3:ReplicateObject",
        "s3:ReplicateDelete"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.destination.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy" {
  #name       = "tf-iam-role-attachment-replication"
  role       = "${aws_iam_role.replication.name}"
  policy_arn = "${aws_iam_policy.replication.arn}"
}

resource "aws_s3_bucket" "destination" {
  bucket   = "${var.s3_replica_bucket}"
  provider = "aws.replica_provider"
  acl      = "private"

  versioning {
    enabled = true
  }

  # enable server-side encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.bucket_key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  # enforce ssl only access to the bucket
  # ref: https://docs.aws.amazon.com/config/latest/developerguide/s3-bucket-ssl-requests-only.html
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${data.aws_caller_identity.current.account_id}"
        ]
      },
      "Action": "s3:Get*",
      "Resource": "arn:aws:s3:::${var.s3_replica_bucket}/*"
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "*",
      "Resource": "arn:aws:s3:::${var.s3_replica_bucket}/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY


  logging {
    target_bucket = "${aws_s3_bucket.destination_log_bucket.id}"
    target_prefix = "${var.terraform_state_log_prefix}/"
  }

  tags = "${var.tags}"

}

resource "aws_s3_bucket" "destination_log_bucket" {
  bucket    = "${var.s3_replica_log_bucket}"
  provider  = "aws.replica_provider"
  acl       = "log-delivery-write"

  tags = "${var.tags}"

  # enable server-side encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = "${aws_kms_key.bucket_key.arn}"
        sse_algorithm     = "aws:kms"
      }
    }
  }

  # enforce ssl only access to the bucket
  # ref: https://docs.aws.amazon.com/config/latest/developerguide/s3-bucket-ssl-requests-only.html
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${data.aws_caller_identity.current.account_id}"
        ]
      },
      "Action": "s3:Get*",
      "Resource": "arn:aws:s3:::${var.s3_replica_log_bucket}/*"
    },
    {
      "Effect": "Deny",
      "Principal": "*",
      "Action": "*",
      "Resource": "arn:aws:s3:::${var.s3_replica_log_bucket}/*",
      "Condition": {
        "Bool": {
          "aws:SecureTransport": "false"
        }
      }
    }
  ]
}
POLICY

}

