variable "aws_region" {
    description = "AWS region to use for resources"
    type        = string
    default     = "us-east-1"
}

variable "aws_profile" {
    description = "AWS CLI profile to use (optional). Leave empty to use default credential chain."
    type        = string
    default     = ""
}


variable "aws_replica_region" {
    description = "AWS region to use for replica resources"
    type        = string
    default     = "us-east-2"
}


variable "bucket_name" {
    description = "Optional bucket name. If empty a unique name will be generated."
    type        = string
    default     = ""
}



variable "replica_bucket_name" {
    description = "Optional replica bucket name. If empty a unique name will be generated."
    type        = string
    default     = ""
}

variable "env" {
    description = "Optional replica bucket name. If empty a unique name will be generated."
    type        = string
    default     = ""
}
