#!/bin/sh

terraform destroy -auto-approve

if [ $? -eq 0 ]; then

	rm -f backend.tfvars

	rm -f terraform.tfstate
	rm -f terraform.tfstate.backup

	rm -rf .terraform

fi
