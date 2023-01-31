terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "4.51.0"
        }
        confluent = {
            source = "confluentinc/confluent"
            version = "1.28.0"
        }
    }
}

provider "aws" {
  region = var.region

  ignore_tags {
    key_prefixes = [
      "divvy",
      "confluent-infosec",
      "ics"
    ]
  }

  default_tags {
    tags = local.tf_tags
  }
}

provider "confluent" {
    # Set through env vars as:
    # CONFLUENT_CLOUD_API_KEY="CLOUD-KEY"
    # CONFLUENT_CLOUD_API_SECRET="CLOUD-SECRET"
}

locals {
  tf_tags = {
    "tf_owner"         = "skpabba",
    "tf_owner_email"   = "skpabba@confluent.io",
    "tf_provenance"    = "github.com/justinrlee/field-notes/misc/terraform",
    "tf_last_modified" = "${var.date_updated}",
    "Owner"            = "skpabba",
  }
}