#!/bin/bash

# Email address used with letsencrypt cert - empty means don't use letsencrypt
LETS_ENCRYPT=""
# Use helm to install rancher 0=no 1=yes
HELM_INSTALL=0
# Use local storage 1=yes 0=no
LOCAL_STORAGE=0
# Install with rancher version
RANCHER_VERSION="2.2.2"

while getopts "c:ilv:" opt; do
  case $opt in
    c)
      LETS_ENCRYPT=$OPTARG
      ;;
    i) 
      HELM_INSTALL=1
      ;;
		l) 
			LOCAL_STORAGE=1
			echo "Backend type must be set in configuration file main.tf. Use 'backend \"s3\"{}'"
			;;
    v)
      RANCHER_VERSION=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# Backend type MUST be set in the config file main.tf
if [[ "$LOCAL_STORAGE" -eq 0 ]]; then
	# backend "local" {}
	terraform init 
else
  # backend "s3" {}
	terraform init -backend-config=../s3-backend/backend.tfvars
fi

terraform plan -out=plan.tfout -detailed-exitcode
TERRA_DIFF=$?

read -p "Please enter y to accept the plan and apply: " -n 1 -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]; then

	terraform apply plan.tfout
	RANCHER_HOST=$(terraform output rancherhost)
	if [[ $? -eq 0 ]]; then

		if [[ "$TERRA_DIFF" -ne 0 ]]; then
			terraform output clusteryml > cluster.yml
			echo "Sleeping for 3 minutes in order to allow docker 17.03 to be installed"
			sleep 180
			rke up
			export KUBECONFIG=$(pwd)/kube_config_cluster.yml
		fi
		
		if [[ "$HELM_INSTALL" -eq 0 ]]; then
			echo "Congratulations, you now have an RKE-created cluster in AWS."
			echo "To install Rancher, please follow the Rancher HA install guide."
			echo "https://rancher.com/docs/rancher/v2.x/en/installation/ha/helm-init/"
		else
			kubectl -n kube-system create serviceaccount tiller
			kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller
			helm init --service-account tiller

			echo "Take a 30 second break k8s needs a moment to reconcile ..."
			sleep 30

			helm install stable/cert-manager --name cert-manager --namespace kube-system --version v0.5.2
			helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
			helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
			helm repo update
			if [[ ! -z "$LETS_ENCRYPT" ]]; then
				helm install rancher-latest/rancher --name rancher --namespace cattle-system --version "$RANCHER_VERSION" --set addLocal="true" --set hostname="$RANCHER_HOST" --set ingress.tls.source=letsEncrypt --set letsEncrypt.email="$LETS_ENCRYPT"
			else
				helm install rancher-latest/rancher --name rancher --namespace cattle-system --version "$RANCHER_VERSION" --set addLocal="true" --set hostname="$RANCHER_HOST"
			fi
		fi
	else

		echo "An issue occurred trying to apply the terraform plan file. Please check the issue and try again."

	fi

fi

rm plan.tfout
