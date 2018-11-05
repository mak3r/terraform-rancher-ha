#!/bin/bash

terraform init

terraform plan -out=plan.tfout -detailed-exitcode
TERRA_DIFF=$?

read -p "Please enter y to accept the plan and apply: " -n 1 -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]; then

	terraform apply plan.tfout
	if [[ $? -eq 0 ]]; then
			terraform output backend_tfvars > backend.tfvars
	else
		echo "An issue occurred trying to apply the terraform plan file. Please check the issue and try again."
	fi

fi

rm plan.tfout
