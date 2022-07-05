#!/bin/bash

# Function to set CASE version
set_case_version() {
   source case_versions.conf
   if [ "$CP4S_VERSION" = "1.9" ]
   then
      export CASE_VERSION=${case_versions_for_cp4s_1dot9[-1]}
   elif [ "$CP4S_VERSION" = "1.10" ]
   then
      export CASE_VERSION=${case_versions_for_cp4s_1dot10[-1]}
   else
      printf "\nCase version not found.\n"
      exit 1;
   fi
   printf "IBM Cloud Pak for Security Version: $CP4S_VERSION\nCASE Version: $CASE_VERSION\n"
   return
}

# Function to check exit status
check_exit_status() {
   printf "\n"
   if [ "$rc" != "0" ];
   then
      echo $error_msg
      printf "\n"
      exit 1
   else
      echo $success_msg
      printf "\n"
      return
   fi
}

# Function to validate CP4S FQDN, TLS Certificate & Key
check_dns() {
# Checking whether fully qualified domain name (FQDN) is provided or not
  if [  -z "$CP4SFQDN" ]; then
    printf "The fully qualified domain name (FQDN) for IBM Cloud Pak for Security is not specified. Using OpenShift cluster domain instead for installation.\n"
    export DOMAIN_CERTIFICATE_PATH=''
    export DOMAIN_CERTIFICATE_KEY_PATH=''
    export CUSTOM_CA_FILE_PATH=''
    return
  fi

  printf "The fully qualified domain name (FQDN) for IBM Cloud Pak for Security is $CP4SFQDN"
  printf "\n[INFO] - Validating certificates and keys needed for CP4S FQDN.\n"
  if [ -z "$DOMAIN_CERTIFICATE_PATH" ]; then
    if [ -n "$CUSTOM_CA_FILE_PATH" ]; then
       printf "[ERROR] Custom CA is provided but no certificate\n"
       exit 1
    fi
    if [ -n "$DOMAIN_CERTIFICATE_KEY_PATH" ]; then
       printf "[ERROR] Domain key is provided but no certificate\n"
       exit 1
    fi
    printf "\n[INFO] The server certificate for the platform fully qualified domain name (FQDN) is not provided. Default would be used.\n"
    return
  fi

  if [ ! -f "$DOMAIN_CERTIFICATE_PATH" ]; then
     printf "[ERROR] Certificate file $DOMAIN_CERTIFICATE_PATH not found. Make sure to upload the certificate crt file into the 'dns' folder inside the 'QSS3KeyPrefix' folder of your S3 bucket.\n"
     exit 1
  fi
  if [ -z "$DOMAIN_CERTIFICATE_KEY_PATH" ]; then
     printf "[ERROR] Certificate key file not set\n"
     exit 1
  fi
  if [ ! -f "$DOMAIN_CERTIFICATE_KEY_PATH" ]; then
     printf "[ERROR] Certificate key file $DOMAIN_CERTIFICATE_KEY_PATH  not found. Make sure to upload the certificate key file into the 'dns' folder inside the 'QSS3KeyPrefix' folder of your S3 bucket.\n"
     exit 1
  fi
  if [ -z "$CUSTOM_CA_FILE_PATH" ]; then
     return
  fi
  if [ ! -f "$CUSTOM_CA_FILE_PATH" ]; then
     printf "[ERROR] CA certificate file $CUSTOM_CA_FILE_PATH not found. Make sure to upload the custom ca crt file into the 'dns' folder inside the 'QSS3KeyPrefix' folder of your S3 bucket.\n"
     exit 1
  fi
  return
}

# Function to create or update a secret
create_secret() {
   if [[ -n $(oc get secret $CUSTOMER_LICENSE_SECRET -n $CP4S_NAMESPACE --no-headers) ]]
   then
      printf "\n"
      echo "Secret '$CUSTOMER_LICENSE_SECRET' already exists."
      echo "[INFO] - Updating secret '$CUSTOMER_LICENSE_SECRET'."
      oc create secret generic -n $CP4S_NAMESPACE $CUSTOMER_LICENSE_SECRET --from-file=/ibm/license.key --dry-run=client -o yaml | oc replace -f -
      printf "\n[SUCCESS] Configuring license for Orchestration & Automation is complete.\n"
   else
      printf "\n"
      echo "Secret '$CUSTOMER_LICENSE_SECRET' is not created yet."
      echo "[INFO] - Creating secret '$CUSTOMER_LICENSE_SECRET'."
      oc create secret generic -n $CP4S_NAMESPACE $CUSTOMER_LICENSE_SECRET --from-file=/ibm/license.key
      printf "\n[SUCCESS] Configuring license for Orchestration & Automation is complete.\n"
   fi
   return
}

# Function to delete all secrets after stack completion
cleanup_secrets() {
   if [ -f "/ibm/license.key" ]; then
      sudo rm -f /ibm/license.key
   fi
   if [ -d "/ibm/tls/" ]; then
      sudo rm -rf /ibm/tls
   fi
   if [ -f "/ibm/pull-secret" ]; then
      sudo rm -f /ibm/pull-secret
   fi
   printf "\nCleanup complete, deleted all secrets from the EC2 instance!\n"
   return
}
