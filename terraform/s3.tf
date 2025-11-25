resource "random_id" "suffix" {
    byte_length = 4
}

data "aws_caller_identity" "current" {}

locals {
    name = var.bucket_name != "" ? var.bucket_name : "public-bucket-${random_id.suffix.hex}"
    replica_bucket_name = var.replica_bucket_name != "" ? var.replica_bucket_name : "${local.name}-replica-${random_id.suffix.hex}"
}

resource "aws_s3_bucket" "public" {
    bucket        = local.name
    acl           = "public-read"
    force_destroy = true
    tags = {
        Name = local.name
        Env  = "dev"
    }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "public" {
    bucket = aws_s3_bucket.public.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm     = "aws:kms"
            kms_master_key_id = "alias/aws/s3"
        }
    }    
}

resource "aws_s3_bucket_public_access_block" "public" {
    bucket = aws_s3_bucket.public.id

    block_public_acls       = false
    block_public_policy     = false
    ignore_public_acls      = false
    restrict_public_buckets = false
}

data "aws_iam_policy_document" "public_read_objects" {
    statement {
        sid = "AllowPublicRead"
        principals {
            type        = "AWS"
            identifiers = ["*"]
        }
        actions   = ["s3:GetObject"]
        resources = ["${aws_s3_bucket.public.arn}/*"]
    }
}

resource "aws_s3_bucket_policy" "public" {
    bucket = aws_s3_bucket.public.id
    policy = data.aws_iam_policy_document.public_read_objects.json
}


resource "aws_s3_bucket_versioning" "source" {
    bucket = aws_s3_bucket.public.id
    versioning_configuration {
        status = "Enabled"
    }
}

# Replica bucket in the other region
resource "aws_s3_bucket" "replica" {
    bucket        = local.replica_bucket_name
    acl           = "public-read"
    force_destroy = true

    tags = {
        Name = "${local.name}-replica"
        Env  = "dev"
    }
}

resource "aws_s3_bucket_versioning" "replica" {
    bucket   = aws_s3_bucket.replica.id
    versioning_configuration {
        status = "Enabled"
    }
}


resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
    bucket = aws_s3_bucket.replica.id

    rule {
        apply_server_side_encryption_by_default {
            sse_algorithm     = "aws:kms"
            kms_master_key_id = "alias/aws/s3"
        }
    }    
}

data "aws_iam_policy_document" "replication_assume_role" {
    statement {
        effect = "Allow"
        principals {
            type        = "Service"
            identifiers = ["s3.amazonaws.com"]
        }
        actions = ["sts:AssumeRole"]
    }
}

resource "aws_iam_role" "replication" {
    name               = "${local.name}-replication-role"
    assume_role_policy = data.aws_iam_policy_document.replication_assume_role.json
    path               = "/service-role/"
}

data "aws_iam_policy_document" "replication_role_policy" {
    statement {
        sid = "SourceRead"
        effect = "Allow"
        actions = [
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAcl",
            "s3:GetObjectVersionTagging",
            "s3:GetReplicationConfiguration",
            "s3:ListBucket"
        ]
        resources = [
            aws_s3_bucket.public.arn,
            "${aws_s3_bucket.public.arn}/*"
        ]
    }

    statement {
        sid = "DestinationWrite"
        effect = "Allow"
        actions = [
            "s3:ReplicateObject",
            "s3:ReplicateDelete",
            "s3:ReplicateTags",
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:PutObjectVersionAcl"
        ]
        resources = [
            aws_s3_bucket.replica.arn,
            "${aws_s3_bucket.replica.arn}/*"
        ]
    }
}

resource "aws_iam_role_policy" "replication" {
    role = aws_iam_role.replication.id
    policy = data.aws_iam_policy_document.replication_role_policy.json
}

data "aws_iam_policy_document" "replica_bucket_policy" {
    statement {
        sid = "AllowReplicationRoleWrite"
        effect = "Allow"
        principals {
            type        = "AWS"
            identifiers = [aws_iam_role.replication.arn]
        }
        actions = [
            "s3:PutObject",
            "s3:PutObjectAcl",
            "s3:PutObjectVersionAcl"
        ]
        resources = ["${aws_s3_bucket.replica.arn}/*"]
    }
}

resource "aws_s3_bucket_policy" "replica" {
    bucket = aws_s3_bucket.replica.id
    policy = data.aws_iam_policy_document.replica_bucket_policy.json
}

resource "aws_s3_bucket_replication_configuration" "public" {
    bucket = aws_s3_bucket.public.id
    role   = aws_iam_role.replication.arn

    rule {
        id       = "replicate-to-${var.replica_region}"
        priority = 1
        status   = "Enabled"

        filter {
            prefix = ""
        }

        destination {
            bucket        = aws_s3_bucket.replica.arn
            account       = data.aws_caller_identity.current.account_id
            storage_class = "STANDARD"
        }
    }
}