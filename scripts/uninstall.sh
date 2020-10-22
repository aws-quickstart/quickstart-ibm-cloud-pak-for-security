#!/bin/bash

echo 
echo "Running CP4S Install"
echo 

export I_PWD=$(pwd)

if [ -z $1 ]
then
  source ./environment_variables.sh
else
  echo $1 file used
  source ./$1
fi

oc login -u=$OCP_USERNAME -p=$OCP_PASSWORD

function uninstall-openldap {
export TILLER_NAMESPACE=ibm-common-services

LDAP_ID=$(cloudctl iam ldaps | grep ICPOpenLDAP | awk -F' ' '{print $1 }');

cloudctl iam ldap-delete -c $LDAP_ID -f

helm delete --purge icp-openldap --tls

echo
echo openldap uninstallation complete
echo
}

##########################################################
# Comment out following line to skip openldap uninstall
uninstall-openldap

rm -rf ibm-cp-security
tar xf cp4s_1.4.0.0/ibm-cp-security-1.0.9.tgz

function self-signed {
cat << EOF  > ibm-cp-security/inventory/installProduct/files/values.conf

# Admin User ID (Required)
adminUserId="$PLATFORM_ADMIN" 

#Cluster type e.g aws,ibmcloud, ocp (Required)
cloudType="$CLUSTER_PLATFORM"

# CP4S FQDN domain(Required)
cp4sapplicationDomain="$CP4S_FQDN"

# e.g ./path-to-cert/cert.crt (Required)
cp4sdomainCertificatePath="./domain-cert.crt" 

## Path to domain certificate key ./path-to-key/cert.key (Required)
cp4sdomainCertificateKeyPath="./private.key"  

# Path to custom ca cert e.g <path-to-cert>/ca.crt (Only required if using custom/self signed certificate)
cp4scustomcaFilepath="./ca.crt" 

# Set image pullpolicy  e.g Always,IfNotPresent, default is IfNotPresent (Optional)
cp4simagePullPolicy="IfNotPresent"

# Default Account name, default is "Cloud Pak For Security" (Optional)
#defaultAccountName="Cloud Pak For Security" 

# set to "true" to enable CSA Adapter (Optional)
enableCloudSecurityAdvisor="false" 

## Only Required for online install 
entitledRegistryUrl="$ENTITLED_REGISTRY_URL"

## Only Required for online install 
entitledRegistryPassword="$ENTITLED_REGISTRY_PASSWORD" 

## Only Required for online install 
entitledRegistryUsername="$ENTITLED_REGISTRY_USERNAME" 

# Only required for airgap install
localDockerRegistry="" 

# Only required for airgap install
localDockerRegistryUsername=""

# Only required for airgap install
localDockerRegistryPassword=""

#Entitled by default,set to <local> for airgap install 
registryType="entitled"

# Block storage (Required)
storageClass="$STORAGE_CLASS"

# Set storage fs group. Default is 26 (Optional)
storageClassFsGroup="26"

# Set storage class supplemental groups (Optional)
storageClassSupplementalGroups="" 

# set seperate storageclass for toolbox (Optional)
toolboxStorageClass="" 

# set custom storage size for toolbox,default is 100Gi (Optional)
toolboxStorageSize="100Gi" 

EOF
}

function not-self-signed {
cat << EOF  > ibm-cp-security/inventory/installProduct/files/values.conf

# Admin User ID (Required)
adminUserId="$PLATFORM_ADMIN" 

#Cluster type e.g aws,ibmcloud, ocp (Required)
cloudType="$CLUSTER_PLATFORM"

# CP4S FQDN domain(Required)
cp4sapplicationDomain="$CP4S_FQDN"

# e.g ./path-to-cert/cert.crt (Required)
cp4sdomainCertificatePath="./domain-cert.crt" 

## Path to domain certificate key ./path-to-key/cert.key (Required)
cp4sdomainCertificateKeyPath="./private.key"  

# Path to custom ca cert e.g <path-to-cert>/ca.crt (Only required if using custom/self signed certificate)
cp4scustomcaFilepath="" 

# Set image pullpolicy  e.g Always,IfNotPresent, default is IfNotPresent (Optional)
cp4simagePullPolicy="IfNotPresent"

# Default Account name, default is "Cloud Pak For Security" (Optional)
#defaultAccountName="Cloud Pak For Security" 

# set to "true" to enable CSA Adapter (Optional)
enableCloudSecurityAdvisor="false" 

## Only Required for online install 
entitledRegistryUrl="$ENTITLED_REGISTRY_URL"

## Only Required for online install 
entitledRegistryPassword="$ENTITLED_REGISTRY_PASSWORD" 

## Only Required for online install 
entitledRegistryUsername="$ENTITLED_REGISTRY_USERNAME" 

# Only required for airgap install
localDockerRegistry="" 

# Only required for airgap install
localDockerRegistryUsername=""

# Only required for airgap install
localDockerRegistryPassword=""

#Entitled by default,set to <local> for airgap install 
registryType="entitled"

# Block storage (Required)
storageClass="$STORAGE_CLASS"

# Set storage fs group. Default is 26 (Optional)
storageClassFsGroup="26"

# Set storage class supplemental groups (Optional)
storageClassSupplementalGroups="" 

# set seperate storageclass for toolbox (Optional)
toolboxStorageClass="" 

# set custom storage size for toolbox,default is 100Gi (Optional)
toolboxStorageSize="100Gi" 

EOF
}

if $SELF_SIGNED_CERT
then
  self-signed
else
  not-self-signed
fi

echo
cat ibm-cp-security/inventory/installProduct/files/values.conf
echo

echo cloudctl case launch
echo
cloudctl case launch --case ibm-cp-security --namespace cp4s  --inventory installProduct --action uninstall --args "--helm3 /usr/local/bin/helm3 --inputDir cp4s_1.4.0.0/" --tolerance 1
echo


echo 
echo "CP4S Uninstall completed"
echo 