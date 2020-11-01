#!/bin/bash


##### "Main" starts here
SCRIPT=${0##*/}

echo $SCRIPT
source ${P}
qs_enable_epel &> /var/log/userdata.qs_enable_epel.log
yum -y install jq
qs_retry_command 10 pip install boto3 &> /var/log/userdata.boto3_install.log


cd /tmp
qs_retry_command 10 wget https://s3-us-west-1.amazonaws.com/amazon-ssm-us-west-1/latest/linux_amd64/amazon-ssm-agent.rpm
qs_retry_command 10 yum install -y ./amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent
rm -f ./amazon-ssm-agent.rpm

qs_retry_command 10 wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.29/openshift-client-linux.tar.gz
tar xvf openshift-client-linux.tar.gz
mv ./oc /usr/bin/
mv ./kubectl /usr/bin

qs_retry_command 10 wget https://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.4.29/openshift-install-linux.tar.gz
tar xvf openshift-install-linux.tar.gz
mv ./openshift-install /ibm/
cd -

echo "INSTALLING DOCKER/ENGINE"
sudo wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz
sudo tar xvf docker-19.03.9.tgz 
sudo cp docker/* /usr/local/bin/
sudo dockerd &> /dev/null &

echo "TESTING DOCKER"
ps -ef |grep docker
docker run hello-world

echo "INSTALLING HELM3"
sudo wget https://get.helm.sh/helm-v3.2.4-linux-amd64.tar.gz
sudo tar xvf helm-v3.2.4-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/helm3

echo "INSTALLING CLOUDCTL"
sudo curl -L https://github.com/IBM/cloud-pak-cli/releases/download/v3.4.4/cloudctl-linux-amd64.tar.gz -o cloudctl-linux-amd64.tar.gz
sudo tar xvf cloudctl-linux-amd64.tar.gz
sudo cp cloudctl-linux-amd64 /usr/local/bin/cloudctl

echo "INSTALLING JQ"
wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O \
/usr/local/bin/jq

echo "INSTALLING YQ"
wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_386 -O \
/usr/local/bin/yq

echo "INSTALLING PYTHON3"
yum -y install python3

echo "INSTALLING CERTAUTH"
pip3 install certauth

echo "INSTALLING ANSIBLE"
pip3 install ansible

echo "INSTALLING BOTO3"
qs_retry_command 10 pip install boto3 &> /var/log/userdata.boto3_install.log

aws s3 cp  ${CP4S_QS_S3URI}scripts/  /ibm/ --recursive
cd /ibm
# Make sure there is a "logs" directory in the current directory
if [ ! -d "${PWD}/logs" ]; then
  mkdir logs
  rc=$?
  if [ "$rc" != "0" ]; then
    # Not sure why this would ever happen, but...
    # Have to echo here since trace log is not set yet.
    echo "Creating ${PWD}/logs directory failed.  Exiting..."
    exit 1
  fi
fi

LOGFILE="${PWD}/logs/${SCRIPT%.*}.log"


mkdir -p artifacts
mkdir -p  templates
chmod +x /ibm/cp4s_install.py
chmod +x /ibm/destroy.sh
chmod +x /ibm/cp4s-deployment/cp4s-install.sh
chmod +x /usr/bin/oc
chmod +x /usr/bin/kubectl
chmod +x /usr/local/bin/helm
chmod +x /usr/local/bin/cloudctl
chmod +x /usr/local/bin/yq
chmod +x /ibm/openshift-install

echo $HOME
export KUBECONFIG=/root/.kube/config
echo $KUBECONFIG
echo $PATH
/ibm/cp4s_install.py --region "${AWS_REGION}" --stackid "${AWS_STACKID}" --stack-name ${AWS_STACKNAME} --logfile $LOGFILE --loglevel "*=all"