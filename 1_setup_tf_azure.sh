#!/bin/bash

# Load Env Vars
source 0_envvars.sh


echo -e "Creating RG $RG ...\n"
{ # try
    az group create -n $RG -l $LOC
} || { # catch
    echo -e "Error creating RG $RG\n"
    exit 1
}

echo -e "Setting up Storage Account $SANAME for Terraform state...\n"
{ # try
    az storage account create -n $SANAME -g $RG -l $LOC --sku Standard_LRS
    az storage container create -n tfstate --account-name $SANAME
} || { # catch
    echo -e "Error Setting up Storage account $SANAME\n"
    exit 1
}

echo -e "Creating keyvault $KVNAME...\n"
{ # try
    az keyvault create -n $KVNAME -g $RG -l $LOC
} || { # catch
    echo -e "Error creating keyvault $KVNAME \n"
    exit 1
}

echo -e "Creating a SAS Token for storage account $SANAME, storing in KeyVault $KVNAME...\n"
{ # try
    az storage container generate-sas --account-name $SANAME --expiry 2023-01-01 --name tfstate --permissions dlrw -o json | xargs az keyvault secret set --vault-name $KVNAME --name TerraformSASToken --value
} || { # catch
    echo -e "Error creating SAS Token \n"
    exit 1
}


echo -e "Creating ServicePrincipal $SPNAME...\n"
{ # try
    SPSECRET=$(az ad sp create-for-rbac -n $SPNAME -o tsv --query password)
    SPID=$(az ad sp show --id http://$SPNAME -o tsv --query appId)
} || { # catch
    echo -e "Error Creating ServicePrincipal $SPNAME \n"
    exit 1
}

echo -e "Storing SSH key and SP details in keyvault $KVNAME...\n"
{ # try
    #creating an ssh key
    ssh-keygen  -f ~/.ssh/id_rsa_terraform -N '' -q
    #store the public key in Azure KeyVault
    az keyvault secret set --vault-name $KVNAME --only-show-errors --name LinuxSSHPubKey -f ~/.ssh/id_rsa_terraform.pub
    #store the service principal id in Azure KeyVault
    az keyvault secret set --vault-name $KVNAME --only-show-errors --name spn-id --value $SPID
    #store the service principal secret in Azure KeyVault
    az keyvault secret set --vault-name $KVNAME --only-show-errors --name spn-secret --value $SPSECRET
} || { # catch
    echo -e "Error populating keyvault  $KVNAME\n"
    exit 1
}

echo -e "Setting secret access policies in  $KVNAME for $SPNAME ...\n"
{ # try
    SPOID=$(az ad sp show --id http://$SPNAME -o tsv --query objectId)
    az keyvault set-policy --name kvweuterraform --secret-permissions get --object-id $SPOID
} || { # catch
    echo -e "Error etting secret access policies in $KVNAME\n"
    exit 1
}

