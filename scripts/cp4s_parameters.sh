cat << EOF  > /cp4s_install/ibm-cp-security/inventory/ibmSecurityOperatorSetup/files/values.conf
# The user who will be given administrative privileges in the System Administration account after installation. Specify the short name or the email for the administrator user.
adminUser="$ADMIN_USER"

# Set to "true" if deploying Cloud Pak for Security in an offline or disconnected environment. Set to "false" if deploying Cloud Pak for Security in an online environment.
airgapInstall="false"

# (Optional) The Fully Qualified Domain Name (FQDN) created for Cloud Pak for Security. When the domain is not specified, it will be generated as cp4s.<cluster_ingress_subdomain>.
domain="$CP4SFQDN"

# (Optional) Path to the domain TLS certificate file e.g <path-to-certs>/cert.crt. Leave blank if you are installing Cloud Pak for Security without specifying a domain.
# See more details at https://www.ibm.com/docs/en/SSTDPP_1.10/docs/security-pak/tls_certs.html.
domainCertificatePath="$DOMAIN_CERTIFICATE_PATH"

# (Optional) Path to the domain TLS key file e.g <path-to-certs>/cert.key. Leave blank if you are installing Cloud Pak for Security without specifying a domain.
# See more details at https://www.ibm.com/docs/en/SSTDPP_1.10/docs/security-pak/tls_certs.html.
domainCertificateKeyPath="$DOMAIN_CERTIFICATE_KEY_PATH"

# (Optional) Path to the custom CA cert file e.g <path-to-certs>/ca.crt. Only required if using custom or self signed certificates. Leave blank if you are installing Cloud Pak for Security without specifying a domain.
# See more details at https://www.ibm.com/docs/en/SSTDPP_1.10/docs/security-pak/tls_certs.html.
customCaFilePath="$CUSTOM_CA_FILE_PATH"

# (Optional) The provisioned block or file storage class to be used for creating all the PVCs required by Cloud Pak for Security. When it is not specified, the default storage class will be used.
# See more details in the storage requirements section at https://www.ibm.com/docs/en/SSTDPP_1.10/docs/security-pak/persistent_storage.html. The storage class cannot be modified after installation.
storageClass="$STORAGE_CLASS"

# (Optional) Storage class used for creating the backup and restore PVC. If this value is not set, Cloud Pak for Security will use the same value set in "storageClass" parameter.
backupStorageClass="$BACKUP_STORAGE_CLASS"

# (Optional) Override the default backup and restore storage PVC size. Must be 500Gi or higher.
backupStorageSize="$BACKUP_STORAGE_SIZE"

# (Optional) Set the pull policy for the images. When OpenShift creates containers, it uses the imagePullPolicy to determine if the image should be pulled prior to starting the container.
# Options are "Always", "IfNotPresent", or "Never".
imagePullPolicy="$IMAGE_PULL_POLICY"

# Set the repository in which the images will be pulled from. Must be set to "cp.icr.io/cp/cp4s" if you are installing Cloud Pak for Security in an online environment.
# If you are installing Cloud Pak for Security in an air-gapped environment, specify the URL and port for the local Docker registry with the "/cp/cp4s" namespace appended. For example, example-registry:5000/cp/cp4s.
repository="cp.icr.io/cp/cp4s"

# Set the username for the repository in which the images will be pulled from. Must be set to "cp" if you are installing Cloud Pak for Security in an online environment.
# If you are installing Cloud Pak for Security in an air-gapped environment, specify a user with access to the local Docker registry.
repositoryUsername="cp"

# Set the password for the repository in which the images will be pulled from.
# If you are installing Cloud Pak for Security in an air-gapped environment, specify the password for the user with access to the local Docker registry.
repositoryPassword="$REPOSITORY_PASSWORD"

# Enable ROKS authentication (if deployment is on IBM Cloud Environment). See more details at https://www.ibm.com/docs/en/SSTDPP_1.10/docs/scp-core/roks-authentication.html.
roksAuthentication="false"

# Set to "true" to deploy Detection and Response Center (Beta). Set to "false" to skip deployment of Detection and Response Center (Beta). See more details at https://www.ibm.com/docs/en/SSTDPP_1.10/docs/drc/c_DRC_intro.html.
deployDRC="$DEPLOY_DRC"

# Set to "true" to deploy Risk Manager. Set to "false" to skip deployment of Risk Manager. See more details at https://www.ibm.com/docs/en/SSTDPP_1.10/datariskmanager/welcome.html.
deployRiskManager="$DEPLOY_RISK_MANAGER"

# Set to "true" to deploy Threat Investigator. Set to "false" to skip deployment of Threat Investigator. See more details at https://www.ibm.com/docs/en/SSTDPP_1.10/investigator/investigator_intro.html.
deployThreatInvestigator="$DEPLOY_THREAT_INVESTIGATOR"

EOF