# Configure the Amazon AWS Provider
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

variable "aws_access_key" {
  default     = "xxx"
  description = "Amazon AWS Access Key"
}

variable "aws_secret_key" {
  default     = "xxx"
  description = "Amazon AWS Secret Key"
}

variable "region" {
  default     = "us-west-2"
  description = "Amazon AWS Region for deployment"
}

variable "bucket" {
  default     = "bucket_name"
  description = "The bucket to create in S3"
}

variable "key" {
  default     = "terraform.tfstate"
  description = "The key used to reference this backend data set"
}

variable "encrypt" {
  default     = true
  description = "Encryption at rest option"
}

variable "originator" {
  default     = "unspecified"
  description = "The name of the individual who created this bucket"
}


# terraform state file setup
# create an S3 bucket to store the state file in
resource "aws_s3_bucket" "terraform-state-storage-s3" {
    bucket = "${var.bucket}"
 
    versioning {
      enabled = true
    }
 
    lifecycle {
      prevent_destroy = true
    }
 
    tags {
      Name = "S3 Remote Terraform State Store"
      Originator = "${var.originator}"
    }      
}

data "template_file" "segment" {
  template = "bucket = \"${var.bucket}\"\nkey = \"${var.key}\"\nregion = \"${var.region}\"\nencrypt = ${var.encrypt}"
}

output "backend_tfvars" {
  value = "### AUTO GENERATED - DO NOT MODIFY ###\n\n${join("\n",data.template_file.segment.*.rendered)}"
}
