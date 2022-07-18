#!/bin/bash

log_file="/ibm/logs/cp4s_install.log"
exec &> >(tee -a "$log_file")

export CP4SFQDN=$1
export OCP_SERVER_URL=$2
export OCP_PASSWORD=$3
export ADMIN_USER=$4
export STORAGE_CLASS=$5
export BACKUP_STORAGE_CLASS=$6
export BACKUP_STORAGE_SIZE=$7
export IMAGE_PULL_POLICY=$8
export REPOSITORY_PASSWORD=$9
export DEPLOY_DRC=${10}
export DEPLOY_RISK_MANAGER=${11}
export DEPLOY_THREAT_INVESTIGATOR=${12}
export CP4S_VERSION=${13}
export CP4S_NAMESPACE=${14}
export OCP_USERNAME="kubeadmin"
export ACCEPT_LICENSE="true"
export CUSTOMER_LICENSE_SECRET="isc-cases-customer-license"

[[ $CP4SFQDN == "-" ]] && export CP4SFQDN=''
[[ $STORAGE_CLASS == "-" ]] && export STORAGE_CLASS=''
[[ $BACKUP_STORAGE_CLASS == "-" ]] && export BACKUP_STORAGE_CLASS=''
[[ $BACKUP_STORAGE_SIZE == "-" ]] && export BACKUP_STORAGE_SIZE=''

if [ -f "/ibm/tls/tls.crt" ]; then
  export DOMAIN_CERTIFICATE_PATH="/ibm/tls/tls.crt"
else
  export DOMAIN_CERTIFICATE_PATH=''
fi
if [ -f "/ibm/tls/tls.key" ]; then
  export DOMAIN_CERTIFICATE_KEY_PATH="/ibm/tls/tls.key"
else
  export DOMAIN_CERTIFICATE_KEY_PATH=''
fi
if [ -f "/ibm/tls/ca.crt" ]; then
  export CUSTOM_CA_FILE_PATH="/ibm/tls/ca.crt"
else
  export CUSTOM_CA_FILE_PATH=''
fi

source install_utils.sh
# Set CASE version
set_case_version
# Checking exit status
rc=$?
success_msg="[SUCCESS] IBM Cloud Pak for Security CASE version set successfully."
error_msg="[ERROR] Failed to set IBM Cloud Pak for Security CASE version."
check_exit_status

# Logging in to the OCP cluster
echo "-------------------------"
echo "LOGGING IN TO THE CLUSTER"
echo "-------------------------"
oc login $OCP_SERVER_URL -u $OCP_USERNAME -p $OCP_PASSWORD --insecure-skip-tls-verify
# Checking exit status
rc=$?
success_msg="[SUCCESS] OpenShift cluster login successful. Logged in as $OCP_USERNAME."
error_msg="[ERROR] OpenShift cluster login failed."
check_exit_status

# Install the OpenShift Serverless operator
echo "----------------------------------------"
echo "INSTALLING OPENSHIFT SERVERLESS OPERATOR"
echo "----------------------------------------"
oc apply -f oc/yaml/namespace.yaml
oc apply -f oc/yaml/operator-group.yaml
[[ ! $(oc apply -f oc/yaml/operator-group.yaml) ]] && { exit 1; }
oc apply -f ./oc/yaml/subscription.yaml
[[ ! $(oc apply -f oc/yaml/subscription.yaml) ]] && { exit 1; }
# Validate Openshift Serverless Operator installation
oc/scripts/serverless_status_check.sh

# Installing Knative Serving
echo "--------------------------"
echo "INSTALLING KNATIVE SERVING"
echo "--------------------------"
oc apply -f oc/yaml/serving.yaml
printf "[info] - Waiting for Knative namespace and CRD to be created...\n"
sleep 30
# Validate Knative Serving installation
oc/scripts/knative_status_check.sh

# Validating certificates and keys needed for CP4S FQDN
echo "-----------------------------------------------------"
echo "VALIDATING CERTIFICATES AND KEYS NEEDED FOR CP4S FQDN"
echo "-----------------------------------------------------"
check_dns
rc=$?
success_msg="[SUCCESS] Validated certificates and keys needed for CP4S FQDN."
error_msg="[ERROR] Failed to validate certificates and keys needed for CP4S FQDN."
check_exit_status

echo "Creating cp4s_install working directory..."
export CP4S_DIR=$HOME/cp4s_install
mkdir $CP4S_DIR
# Checking exit status
rc=$?
success_msg="[SUCCESS] Created cp4s_install working directory."
error_msg="[ERROR] Failed to create cp4s_install working directory."
check_exit_status
cd $CP4S_DIR

# Downloading and extracting the IBM Cloud Pak for Security archive file
echo "------------------------------------------------------------------"
echo "DOWNLOADING AND EXTRACTING THE CLOUD PAK FOR SECURITY ARCHIVE FILE"
echo "------------------------------------------------------------------"
cloudctl case save \
  --repo https://github.com/IBM/cloud-pak/raw/master/repo/case \
  --case ibm-cp-security \
  --version $CASE_VERSION \
  --outputdir $CP4S_DIR \
  && tar -xf $CP4S_DIR/ibm-cp-security-$CASE_VERSION.tgz
# Checking exit status
rc=$?
success_msg="[SUCCESS] Download and extracted IBM Cloud Pak for Security CASE."
error_msg="[ERROR] Failed to download and extract IBM Cloud Pak for Security CASE."
check_exit_status
# Checking for CASE 'ibm-cp-security'
[ -d $CP4S_DIR/ibm-cp-security/ ] || { printf "[ERROR] IBM Cloud Pak for Security CASE not found."; exit 1; }

# Update IBM Cloud Pak for Security installation configuration file
echo "-----------------------------------------------------------------"
echo "UPDATE IBM CLOUD PAK FOR SECURITY INSTALLATION CONFIGURATION FILE"
echo "-----------------------------------------------------------------"
[ -f $CP4S_DIR/ibm-cp-security/inventory/ibmSecurityOperatorSetup/files/values.conf ] || { printf "[ERROR] IBM Cloud Pak for Security installation configuration file doesn't exist.\n"; exit 1; }
/ibm/cp4s_parameters.sh
# Checking exit status
rc=$?
success_msg="[SUCCESS] Updated IBM Cloud Pak for Security installation configuration file."
error_msg="[ERROR] Failed to update IBM Cloud Pak for Security installation configuration file."
check_exit_status

# Install IBM Cloud Pak for Security
echo "------------------------------------------------"
echo "INSTALLING IBM CLOUD PAK FOR SECURITY USING CASE"
echo "------------------------------------------------"
cloudctl case launch -t 1 \
  --case ibm-cp-security \
  --namespace $CP4S_NAMESPACE \
  --inventory ibmSecurityOperatorSetup \
  --action install --args "--acceptLicense $ACCEPT_LICENSE --inputDir $CP4S_DIR" 
# Checking exit status
rc=$?
success_msg="[SUCCESS] IBM Cloud Pak for Security Installation using CASE is complete."
error_msg="[ERROR] Failed to install IBM Cloud Pak for Security Installation using CASE."
check_exit_status
sleep 60

# Validate IBM Cloud Pak for Security installation
echo "--------------------------------------------------"
echo "VALIDATING IBM CLOUD PAK FOR SECURITY INSTALLATION"
echo "--------------------------------------------------"
cloudctl case launch -t 1 \
  --case ibm-cp-security \
  --namespace $CP4S_NAMESPACE \
  --inventory ibmSecurityOperatorSetup \
  --action validate
# Checking exit status
rc=$?
success_msg=''
error_msg="[ERROR] IBM Cloud Pak for Security deployment failed."
check_exit_status
sleep 30

# Configure license for Orchestration & Automation
echo "--------------------------------------------------"
echo "CONFIGURING LICENSE FOR ORCHESTRATION & AUTOMATION"
echo "--------------------------------------------------"
# Create or update secret if SOAR entitlement is provided.
if [ -f "/ibm/license.key" ]; then
  create_secret
fi
# Checking exit status
rc=$?
success_msg=''
error_msg="[ERROR] Configuring license for Orchestration & Automation failed."
check_exit_status
sleep 30

printf "\nIBM Cloud Pak for Security deployment is complete.\n\n"
printf "\n============= Postinstallation Steps ============\n"
printf "\nConfiguring LDAP Authentication - IBM Cloud Pak for Security has a simple static LDAP-configured (openLDAP and phpLDAPadmin) user system. Connect your own LDAP server to IBM Common Services to better support your long-term use of the product. For more information, see https://ibm.biz/BdPrS5 .\n"
printf "\nNote: IBM Cloud Pak for Security connects to various data sources using data connectors. Ensure that only trusted priveleged users have access to both the data sources on the IBM Cloud Pak for Security console or the OpenShift console.\n\n"

cleanup_secrets