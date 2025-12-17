terraform {
    required_version = ">= 1.5.0"

    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region  = var.aws_region
    profile = var.aws_profile
}

# providers and version shouldn't be in main.tf.
# best to add them under providers.tf/version.tf 
