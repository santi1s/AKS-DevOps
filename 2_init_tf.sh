#!/bin/bash

# Load Env Vars
source 0_envvars.sh

echo -e "Running terraform init ...\n"az storage account list -g $RG -o json | jq -r '.[].id' | awk -F "/" '{print $NF}'
{ # try
    SANAME=$(az storage account list -g RG-AksTerraform -o json | jq -r '.[].id' | awk -F "/" '{print $NF}')
    if [ -d terraform ]; then cd terraform; fi
    terraform init -reconfigure -backend-config="resource_group_name=$RG" -backend-config="storage_account_name=$SANAME" -backend-config="container_name=tfstate"
} || { # catch
    echo -e "Error running terraform init\n"
    exit 1
}
