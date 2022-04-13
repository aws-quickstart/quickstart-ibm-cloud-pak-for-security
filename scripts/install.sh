#!/bin/bash

log_file="/ibm/logs/cp4s_install_logs.log--`date +'%Y-%m-%d_%H-%M-%S'`"
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
#Set CASE version
set_case_version
#Checking exit status
rc=$?
success_msg="[SUCCESS] IBM Cloud Pak for Security CASE version set successfully."
error_msg="[ERROR] Failed to set IBM Cloud Pak for Security CASE version. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log."
check_exit_status "$rc" "$success_msg" "$error_msg"

#Logging in to the OCP cluster
printf "\n"
echo "-------------------------"
echo "LOGGING IN TO THE CLUSTER"
echo "-------------------------"
printf "\n"
oc login $OCP_SERVER_URL -u $OCP_USERNAME -p $OCP_PASSWORD --insecure-skip-tls-verify
#Checking exit status
rc=$?
success_msg="[SUCCESS] OpenShift cluster login successful. Logged in as $(oc whoami)."
error_msg="[ERROR] OpenShift cluster login failed. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log."
check_exit_status "$rc" "$success_msg" "$error_msg"

#Install the OpenShift Serverless operator
printf "\n"
echo "----------------------------------------"
echo "INSTALLING OPENSHIFT SERVERLESS OPERATOR"
echo "----------------------------------------"
printf "\n"
oc apply -f oc/yaml/namespace.yaml
oc apply -f oc/yaml/operator-group.yaml
[[ ! $(oc apply -f oc/yaml/operator-group.yaml) ]] && { exit 1; }
oc apply -f ./oc/yaml/subscription.yaml
[[ ! $(oc apply -f oc/yaml/subscription.yaml) ]] && { exit 1; }
#Validate Openshift Serverless Operator installation
oc/scripts/serverless_status_check.sh

#Installing Knative Serving
printf "\n"
echo "--------------------------"
echo "INSTALLING KNATIVE SERVING"
echo "--------------------------"
printf "\n"
oc apply -f oc/yaml/serving.yaml
printf "[info] - Waiting for Knative namespace and CRD to be created...\n"
sleep 30
#Validate Knative Serving installation
oc/scripts/knative_status_check.sh

#Validating certificates and keys needed for CP4S FQDN
printf "\n"
echo "-----------------------------------------------------"
echo "VALIDATING CERTIFICATES AND KEYS NEEDED FOR CP4S FQDN"
echo "-----------------------------------------------------"
printf "\n"
#Validate CP4S FQDN, TLS certificate & key
check_dns
rc=$?
success_msg="[SUCCESS] Validated certificates and keys needed for CP4S FQDN."
error_msg="[ERROR] Failed to validate certificates and keys needed for CP4S FQDN. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log."
check_exit_status "$rc" "$success_msg" "$error_msg"
cd /cp4s_install

#Downloading and extracting the IBM Cloud Pak for Security archive file
printf "\n"
echo "------------------------------------------------------------------"
echo "DOWNLOADING AND EXTRACTING THE CLOUD PAK FOR SECURITY ARCHIVE FILE"
echo "------------------------------------------------------------------"
printf "\n"
cloudctl case save \
  --repo https://github.com/IBM/cloud-pak/raw/master/repo/case \
  --case ibm-cp-security \
  --version $CASE_VERSION \
  --outputdir /cp4s_install \
  && tar -xf /cp4s_install/ibm-cp-security-$CASE_VERSION.tgz
#Checking exit status
rc=$?
success_msg="[SUCCESS] Download and extracted IBM Cloud Pak for Security CASE."
error_msg="[ERROR] Failed to download and extract IBM Cloud Pak for Security CASE. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log."
check_exit_status "$rc" "$success_msg" "$error_msg"
#Checking for CASE 'ibm-cp-security'
[ -d /cp4s_install/ibm-cp-security/ ] || { printf "[ERROR] IBM Cloud Pak for Security CASE not found. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log.\n"; exit 1; }

#Configure parameters for the IBM Cloud Pak for Security installation
printf "\n"
echo "------------------------------------------------------------------"
echo "CONFIGURING PARAMETERS FOR THE CLOUD PAK FOR SECURITY INSTALLATION"
echo "------------------------------------------------------------------"
printf "\n"
[ -f /cp4s_install/ibm-cp-security/inventory/ibmSecurityOperatorSetup/files/values.conf ] || { printf "[ERROR] IBM Cloud Pak for Security Installation Configuration File Not Found.\n"; exit 1; }
/ibm/cp4s_parameters.sh "$ADMIN_USER" "$CP4SFQDN" "$DOMAIN_CERTIFICATE_PATH" "$DOMAIN_CERTIFICATE_KEY_PATH" "$CUSTOM_CA_FILE_PATH" "$STORAGE_CLASS" "$BACKUP_STORAGE_CLASS" "$BACKUP_STORAGE_SIZE" "$IMAGE_PULL_POLICY" "$REPOSITORY_PASSWORD" "$DEPLOY_DRC" "$DEPLOY_RISK_MANAGER" "$DEPLOY_THREAT_INVESTIGATOR"
rc=$?
success_msg="[SUCCESS] Configuring parameters for the IBM Cloud Pak for Security installation is complete."
error_msg="[ERROR] Configuring parameters for the IBM Cloud Pak for Security installation failed. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log."
check_exit_status "$rc" "$success_msg" "$error_msg"

#Install IBM Cloud Pak for Security
printf "\n"
echo "------------------------------------------------"
echo "INSTALLING IBM CLOUD PAK FOR SECURITY USING CASE"
echo "------------------------------------------------"
printf "\n"
cloudctl case launch -t 1 \
  --case ibm-cp-security \
  --namespace $CP4S_NAMESPACE \
  --inventory ibmSecurityOperatorSetup \
  --action install --args "--acceptLicense $ACCEPT_LICENSE --inputDir /cp4s_install" 
#Checking exit status
rc=$?
success_msg="[SUCCESS] IBM Cloud Pak for Security Installation using CASE is complete."
error_msg="[ERROR] IBM Cloud Pak for Security Installation using CASE failed. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log."
check_exit_status "$rc" "$success_msg" "$error_msg"
sleep 60

#Validate IBM Cloud Pak for Security installation
printf "\n"
echo "--------------------------------------------------"
echo "VALIDATING IBM CLOUD PAK FOR SECURITY INSTALLATION"
echo "--------------------------------------------------"
printf "\n"
cloudctl case launch -t 1 \
  --case ibm-cp-security \
  --namespace $CP4S_NAMESPACE \
  --inventory ibmSecurityOperatorSetup \
  --action validate
#Checking exit status
rc=$?
success_msg="[SUCCESS] IBM Cloud Pak for Security validation is complete."
error_msg="[ERROR] IBM Cloud Pak for Security validation failed. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log"
check_exit_status "$rc" "$success_msg" "$error_msg"
sleep 30

#Configure license for Orchestration & Automation
printf "\n"
echo "--------------------------------------------------"
echo "CONFIGURING LICENSE FOR ORCHESTRATION & AUTOMATION"
echo "--------------------------------------------------"
#Create or update secret if SOAR entitlement is provided.
if [ -f "/ibm/license.key" ]; then
  create_secret
fi
#Checking exit status
rc=$?
success_msg="[SUCCESS] Configuration license for Orchestration & Automation is complete."
error_msg="[ERROR] Configuring License for Orchestration & Automation failed. Check logs in S3 log bucket or on the Boot node EC2 instance in /ibm/logs/cp4s_install_logs.log"
check_exit_status "$rc" "$success_msg" "$error_msg"
sleep 30

printf "\n"
printf "\nIBM CLOUD PAK FOR SECURITY DEPLOYMENT IS COMPLETE\n"
printf "\n============= Postinstallation Steps ============\n"
printf "\nConfiguring LDAP Authentication - IBM Cloud Pak for Security has a simple static LDAP-configured (openLDAP and phpLDAPadmin) user system. Connect your own LDAP server to IBM Common Services to better support your long-term use of the product. For more information, see https://ibm.biz/BdfWwY \n"
printf "\nNote: IBM Cloud Pak for Security connects to various data sources using data connectors. Ensure that only trusted priveleged users have access to both the data sources on the IBM Cloud Pak for Security console or the OpenShift console.\n\n"

cleanup_secrets