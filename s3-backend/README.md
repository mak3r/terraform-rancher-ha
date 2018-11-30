# Create a backend to store a share state file

## tl;dr
1. Copy the terraform.tfvars.example to terraform.tfvars
1. Modify to your liking
1. Run the create script `create.sh`

## Usage
Use this terraform to create an s3 backend for the other terraform projects which install HA rancher.
Running `create.sh` will create the S3 bucket and drop a local file with configuration information needed by the on-demand-eip project if opting to use terraform S3 backend. 