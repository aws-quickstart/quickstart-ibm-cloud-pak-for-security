#! /bin/bash

exec > bootstrap_logs.txt

########################################################################
#                                                                      #
#  Calls ocp_install.py script to deploy OpenShift Container Platform, #
#+ IBM Common Services, and Cloud Pak for Security.                    #
#                                                                      #
#  Version: 1.1-beta                                                   #
#  OpenShift Version: 4.4.21                                           #
#  IBM Common Services Version: 3.2.4                                  #
#  Cloud Pak for Security Version: 1.4.0.0                             #
#                                                                      #
#  Contributors:                                                       #
#  Tyler Stednara/IBM - Cloud Pak Acceleration Team                    #
#  Andrew Campagna/IBM - Cloud Pak Acceleration Team                   #
#                                                                      #
#  See README.md for guide.                                            #
#                                                                      #
########################################################################

SCRIPT="${0##*/}"
LOGFILE="/ibm/logs/${SCRIPT%.*}.log"
echo "Bootstrap started... ${SCRIPT}"
echo "HANDLE"
echo "${ICPDInstallationCompletedURL}"

#  Enable quickstart-linix-utilities
#  Reference: https://aws.amazon.com/blogs/infrastructure-and-automation/introduction-to-quickstart-linux-utilities/
export P=/quickstart-linux-utilities/quickstart-cfn-tools.source
source ${P}

#  Enable Extra Packages for Enterprise Linux (EPEL)
echo "INSTALLING EPEL"
sudo qs_enable_epel &> /var/log/userdata.qs_enable_epel.log

#  Download SSM Agent for quick remote command execution on EC2 instance
echo "INSTALLING SSM"
cd /tmp
sudo $(qs_retry_command 10 wget https://s3-us-west-1.amazonaws.com/ \
amazon-ssm-us-west-1/latest/linux_amd64/amazon-ssm-agent.rpm)
sudo $(qs_retry_command 10 yum install -y ./amazon-ssm-agent.rpm)
sudo systemctl start amazon-ssm-agent
sudo systemctl enable amazon-ssm-agent
rm -f ./amazon-ssm-agent.rpm
cd -

# Store pull-secret for OCP
sudo aws s3 cp ${PULLSECRET} /ibm/pull-secret

# Downloading OpenShift Binaries
sudo wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.21/openshift-client-linux.tar.gz
sudo wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.21/openshift-install-linux.tar.gz
sudo tar xvf openshift-client-linux.tar.gz
sudo tar xvf openshift-install-linux.tar.gz
sudo cp oc /usr/local/bin/oc
sudo cp oc /usr/local/bin/kubectl
sudo cp openshift-install /ibm/openshift-install

#  Install and run docker enginer
echo "INSTALLING DOCKER/ENGINE"
sudo wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz
sudo tar xvf docker-19.03.9.tgz 
sudo cp docker/* /usr/local/bin/
sudo dockerd &> /dev/null &

#  Testing Docker
echo "TESTING DOCKER"
ps -ef |grep docker
docker run hello-world

#  Install helm3
echo "INSTALLING HELM3"
sudo wget https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz
sudo tar xvf helm-v3.2.4-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/helm3


#  Install cloudctl
echo "INSTALLING CLOUDCTL"
sudo curl -L https://github.com/IBM/cloud-pak-cli/releases/download/v3.4.4/cloudctl-linux-amd64.tar.gz -o cloudctl-linux-amd64.tar.gz
sudo tar xvf cloudctl-linux-amd64.tar.gz
sudo cp cloudctl-linux-amd64 /usr/local/bin/cloudctl

#  Install command-line JSON program called jq
echo "INSTALLING JQ"
wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O \
/usr/local/bin/jq

#  Install command-line YAML program called yq
echo "INSTALLING YQ"
wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_386 -O \
/usr/local/bin/yq

#  Install python 3.x
echo "INSTALLING PYTHON3"
yum -y install python3

#  Install certauth for Python 3.x
echo "INSTALLING CERTAUTH"
pip3 install certauth

#  Install Ansible / Paramiko
python -m pip install --user ansible
python -m pip install --user paramiko

#  Configure CLI tools for OpenShift / Kubernetes
cp /ibm/oc /usr/local/bin/oc
cp /ibm/oc /usr/local/bin/kubectl

#  PIP install boto3
echo "INSTALLING BOTO3"
qs_retry_command 10 pip install boto3 &> /var/log/userdata.boto3_install.log

#  Work from directory with installation scripts
cd /ibm

#  Ensure /logs folder is present
if [ ! -d "${PWD}/logs" ]; then
  mkdir logs
  rc=$?
  if [ "$rc" != "0" ]; then
    echo "Creating ${PWD}/logs directory failed.  Exiting..."
    exit 1
  fi
fi

#  Configure file system
mkdir artifacts
mkdir templates
mkdir -p /root/.kube
chmod +x /usr/local/bin/oc
chmod +x /usr/local/bin/kubectl
chmod +x /usr/local/bin/helm
chmod +x /usr/local/bin/cloudctl
chmod +x /usr/local/bin/yq
chmod +x /ibm/openshift-install
chmod +x /ibm/cloud_install.py
chmod +x /ibm/destroy.sh

#  Configure kubeconfig for kubectl and oc
export KUBECONFIG=/root/.kube/config
aws s3 /bootstrap_logs.txt s3://aws-cp4s-test/

#  Deploy installation of OpenShift, IBM Common Services, and Cloud Pak for Security
echo "START INSTALL"
touch i.log
echo ${AWS_REGION} ${AWS_STACKID} 
python /ibm/cloud_install.py ${AWS_REGION} ${AWS_STACKID} ${CPD_SECRET}