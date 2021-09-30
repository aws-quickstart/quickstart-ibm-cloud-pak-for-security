exec > cp4s_install_logs.log

export ENTITLED_REGISTRY_PASSWORD=$1
export OCP_URL=$2
export LDAP_PASS=$3
export CLOUDCTL_TRACE=TRUE

cloudctl case save --case https://github.com/IBM/cloud-pak/raw/master/repo/case/ibm-cp-security-1.0.17.tgz --outputdir .
tar xvf ibm-cp-security-1.0.17.tgz

cat << EOF  > ibm-cp-security/inventory/installProduct/files/values.conf

# Admin User ID (Required): The user that is to be assigned as an Administrator in the default account after the installation. The user must exist in an LDAP directory that will be connected to Foundational Services after deployment.
adminUserId="platform-admin" 

# Cluster type (Required) should be one of the following: i.e. "aws", "ibmcloud", "azure", "ocp". This is a mandatory value, If not set it will be "ocp" by default.
cloudType="aws"

# Block storage (Required), see more details https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.7.0/docs/security-pak/persistent_storage.html
storageClass="gp2"

# Entitled by default (Required)
registryType="entitled"

# Only Required for online install 
entitledRegistryUrl="cp.icr.io"

# Only Required for online install 
entitledRegistryPassword="$ENTITLED_REGISTRY_PASSWORD" 

# Only Required for online install 
entitledRegistryUsername="cp" 

# Only required for offline/airgap install
localDockerRegistry="" 

# Only required for offline/airgap install
localDockerRegistryUsername=""

# Only required for offline/airgap install
localDockerRegistryPassword=""

# CP4S FQDN domain (Optional: Not required if your cloudType is set to "ibmcloud" or "aws")
cp4sapplicationDomain=""

# e.g ./path-to-cert/cert.crt (Optional: Not required if you are using ibmcloud or aws). See more details: https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.7.0/docs/security-pak/tls_certs.html.
cp4sdomainCertificatePath="" 

# Path to domain certificate key ./path-to-key/cert.key (Optional: Not required if you using ibmcloud or aws). See more at https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.7.0/docs/security-pak/tls_certs.html.
cp4sdomainCertificateKeyPath=""  

# Path to custom ca cert e.g <path-to-cert>/ca.crt (Only required if using custom/self signed certificate and optional on ibmcloud or aws). See more at https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.7.0/docs/security-pak/tls_certs.html.
cp4scustomcaFilepath="" 

# Set image pullpolicy  e.g Always,IfNotPresent, default is Always (Required)
cp4simagePullPolicy="Always"

# Set to "true" to enable Openshift authentication (Optional). Only supported for ROKS clusters, for more details, see https://www.ibm.com/support/knowledgecenter/en/SSHKN6/iam/3.x.x/roks_config.html
cp4sOpenshiftAuthentication="false"

# Default Account name, default is "Cloud Pak For Security" (Optional)
defaultAccountName="Cloud Pak For Security" 

# set to "true" to enable CSA Adapter (Optional), see https://www.ibm.com/support/knowledgecenter/en/SSTDPP_1.7.0/docs/scp-core/csa-adapter-cases.html for more details
enableCloudSecurityAdvisor="false"

# Set storage fs group. Default is 26 (Optional)
storageClassFsGroup="26"

# Set storage class supplemental groups (Optional)
storageClassSupplementalGroups="" 

# Set seperate storageclass for backup (Optional)
backupStorageClass="" 

# Set custom storage size for backup, default is 100Gi (Optional)
backupStorageSize="100Gi"

EOF

cat patch.sh > /ibm/ibm-cp-security/inventory/installProduct/files/launch.sh
cloudctl case launch -t 1 --case ibm-cp-security --namespace cp4s  --inventory installProduct --action install --args "--license accept --helm3 /usr/local/bin/helm3 --inputDir /ibm"
CP_RESULT=${?}

echo $CP_RESULT

CP_PASSWORD=$(oc get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' -n ibm-common-services | base64 -d)
CP_ROUTE=$(oc get route cp-console -n ibm-common-services|awk 'FNR == 2 {print $2}')
SERVER="$(cut -d':' -f1 <<<"$OCP_URL")"
PORT="$(cut -d':' -f2 <<<"$OCP_URL")"

cat << EOF > cp4s-openldap-master/playbook.yml

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
        ibm_cloud_server: "" # Only Applicable for IBMCloud Deployment
        ibm_cloud_port: ""   # Only Applicable for IBMCloud Deployment
        username: "admin"
        password: "$CP_PASSWORD"
        account: "id-mycluster-account"
        namespace: "default"

    
    openldap:
        adminPassword: "$LDAP_PASS"
        initialPassword: "$LDAP_PASS"
        userlist: "isc-demo,isc-test,platform-admin"

EOF

cd cp4s-openldap-master
ansible-playbook -i hosts playbook.yml