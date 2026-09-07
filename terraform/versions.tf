terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
  # Credentials come from the default CLI profile (aws-portfolio-project),
  # configured earlier via `aws configure`. No keys are stored in this repo.
}

# CloudFront's global API surface is addressed via us-east-1, and one of the
# two SNS topics (portfolio-alerts-us) also lives there — this aliased
# provider lets us manage both from the same Terraform config.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
