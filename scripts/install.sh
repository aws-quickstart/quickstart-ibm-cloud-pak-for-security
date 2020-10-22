#!/bin/bash

exec > cp4s_install_logs.log

echo 
echo "Running CP4S Install"
echo 

export I_PWD=$(pwd)

ENTITLED_REGISTRY_PASSWORD=$1
CP4S_FQDN=$2
OCP_URL=$3

echo $ENTITLED_REGISTRY_PASSWORD
echo $OCP_URL

python3 pyca/ca.py $CP4S_FQDN

tar xf cp4s_1.4.0.0/ibm-cp-security-1.0.9.tgz

function self-signed {
cat << EOF  > ibm-cp-security/inventory/installProduct/files/values.conf

# Admin User ID (Required)
adminUserId="platform-admin" 

#Cluster type e.g aws,ibmcloud, ocp (Required)
cloudType="aws"

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
entitledRegistryUrl="cp.icr.io"

## Only Required for online install 
entitledRegistryPassword="$ENTITLED_REGISTRY_PASSWORD" 

## Only Required for online install 
entitledRegistryUsername="cp" 

# Only required for airgap install
localDockerRegistry="" 

# Only required for airgap install
localDockerRegistryUsername=""

# Only required for airgap install
localDockerRegistryPassword=""

#Entitled by default,set to <local> for airgap install 
registryType="entitled"

# Block storage (Required)
storageClass="gp2"

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
adminUserId="platform-admin" 

#Cluster type e.g aws,ibmcloud, ocp (Required)
cloudType="aws"

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
entitledRegistryUrl="cp.icr.io"

## Only Required for online install 
entitledRegistryPassword="$ENTITLED_REGISTRY_PASSWORD" 

## Only Required for online install 
entitledRegistryUsername="cp" 

# Only required for airgap install
localDockerRegistry="" 

# Only required for airgap install
localDockerRegistryUsername=""

# Only required for airgap install
localDockerRegistryPassword=""

#Entitled by default,set to <local> for airgap install 
registryType="entitled"

# Block storage (Required)
storageClass="gp2"

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

self-signed

echo
cat ibm-cp-security/inventory/installProduct/files/values.conf
echo

echo cloudctl case launch
echo
cloudctl case launch --case ibm-cp-security --namespace cp4s  --inventory installProduct --action install --args "--license accept --helm3 /usr/local/bin/helm3 --inputDir cp4s_1.4.0.0/" --tolerance 1
echo

echo 
echo "CP4S Install completed"
echo 

function install-openldap {
echo Installing openldap:
echo

CP_PASSWORD=$(oc get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' -n ibm-common-services | base64 -d)
CP_ROUTE=$(oc get route cp-console -n ibm-common-services|awk 'FNR == 2 {print $2}')
SERVER="$(cut -d':' -f1 <<<"$OCP_URL")"
PORT="$(cut -d':' -f2 <<<"$OCP_URL")"

cat << EOF  > ldap/playbook.yml
---
- hosts: local
  gather_facts: true
  any_errors_fatal: true
  roles:
    - roles/secops.ibm.icp.login
    - roles/secops.ibm.icp.openldap.deploy
    - roles/secops.ibm.icp.openldap.register

  vars:
    icp:        
        console_url: "$CP_ROUTE"
        ibm_cloud_server: "$SERVER" # Only Applicable for IBMCloud Deployment
        ibm_cloud_port: "$PORT"   # Only Applicable for IBMCloud Deployment
        username: "admin"
        password: "$CP_PASSWORD"
        account: "id-mycluster-account"
        namespace: "default"

    
    openldap:
        adminPassword: "isc-demo"
        initialPassword: "isc-demo"
        userlist: "analyst,manager,platform-admin"
EOF

export TILLER_NAMESPACE=ibm-common-services

echo
cat ldap/playbook.yml
echo


echo ansible-playbook -i ldap/hosts ldap/playbook.yml
ansible-playbook -i ldap/hosts ldap/playbook.yml
echo

echo openldap installation complete
}

##########################################################
# Comment out following line to skip openldap installation
# install-openldap

echo 
echo "End of script"
echo 