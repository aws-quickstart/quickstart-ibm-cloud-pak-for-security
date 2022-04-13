cat << EOF  > /cp4s_install/ibm-cp-security/inventory/ibmSecurityOperatorSetup/files/values.conf
# (Required) The Admin user who will be given administrative privileges in the default account. See more details in IBM Documentation (https://ibm.biz/Bdf8VX).
adminUser="$ADMIN_USER"

# (Optional) Set to "true" if deploying Cloud Pak for Security in an offline or disconnected environment. Default value is false.
airgapInstall="false"

# (Optional) The Fully Qualified Domain Name (FQDN) created for Cloud Pak for Security. When the domain is not specified, it will be generated as cp4s.<cluster_ingress_subdomain>.
domain="$CP4SFQDN"

# (Optional) Path to the domain certificate crt file e.g <path-to-certs>/cert.crt. See more details at https://www.ibm.com/docs/en/SSTDPP_1.9/docs/security-pak/tls_certs.html.
domainCertificatePath="$DOMAIN_CERTIFICATE_PATH"

# (Optional) Path to the domain certificate key file e.g <path-to-certs>/cert.key. See more details at https://www.ibm.com/docs/en/SSTDPP_1.9/docs/security-pak/tls_certs.html.
domainCertificateKeyPath="$DOMAIN_CERTIFICATE_KEY_PATH"

# (Optional) Path to the custom CA cert file e.g <path-to-certs>/ca.crt. Only required if using custom or self signed certificates. See more details at https://www.ibm.com/docs/en/SSTDPP_1.9/docs/security-pak/tls_certs.html.
customCaFilePath="$CUSTOM_CA_FILE_PATH"

# (Optional) The provisioned block or file storage class to be used for creating all the PVCs required by Cloud Pak for Security. When it is not specified, the default storage class will be used. 
# See more details in the storage requirements section (https://ibm.co/3ivpQMl). The storage class cannot be modified after installation. 
storageClass="$STORAGE_CLASS"

# (Optional) Storage class used for creating the backup PVC. If this value is not set, Cloud Pak for Security will use the same value set in "storageClass" parameter. See more details in IBM Documentation (https://ibm.biz/Bdf8VX).
backupStorageClass="$BACKUP_STORAGE_CLASS"

# (Optional) Override the default backup storage PVC size. Default value is 500Gi.
backupStorageSize="$BACKUP_STORAGE_SIZE"

# (Optional) Set the image pull policy for the containers. Options are "IfNotPresent", "Always", and "Never". Default value is IfNotPresent.
imagePullPolicy="$IMAGE_PULL_POLICY"

# (Optional) Set the repository in which the images will be pulled from. Default value is cp.icr.io/cp/cp4s.
repository="cp.icr.io/cp/cp4s"

# (Required) Set the username for the repository in which the images will be pulled from. Default value is cp.
repositoryUsername="cp"

# (Required) Set the password for the repository in which the images will be pulled from.
repositoryPassword="$REPOSITORY_PASSWORD"

# (Optional) Enable ROKS authentication (if deployment is on IBM Cloud Environment). Default value is false. For more details, see https://www.ibm.com/docs/en/cpfs?topic=types-delegating-authentication-openshift.
roksAuthentication="false"

# (Optional) This is optional when deploying Threat Management. Set to "false" to skip deployment of Detection and Response Center (Beta). Default value is true. See more details in IBM® Security Detection Response Center Documentation (https://ibm.biz/Bdf8VX).
deployDRC="$DEPLOY_DRC"

# (Optional) This is optional when deploying Threat Management. Set to "false" to skip deployment of Risk Manager. Default value is true. See more details in IBM® Security Risk Manager Documentation (https://ibm.biz/Bdf8VX).
deployRiskManager="$DEPLOY_RISK_MANAGER"

# (Optional) This is optional when deploying Threat Management. Set to "false" to skip deployment of Threat Investigator. Default value is true. See more details in IBM® Threat Investigator Documentation (https://ibm.biz/Bdf8VX).
deployThreatInvestigator="$DEPLOY_THREAT_INVESTIGATOR"
EOF