#!/bin/bash

SCRIPT=${0##*/}
echo $SCRIPT
source /etc/profile.d/cp4s_install.sh
source ${P}

#Checking AWS cli version
aws --version

#Enable EPEL repo
qs_enable_epel &> /var/log/userdata.qs_enable_epel.log

cd /tmp

#Installing AWS SSH agent
qs_retry_command 10 wget https://s3-us-west-1.amazonaws.com/amazon-ssm-us-west-1/latest/linux_amd64/amazon-ssm-agent.rpm
qs_retry_command 10 yum install -y ./amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent
rm -f ./amazon-ssm-agent.rpm

if [ ! -d "/usr/local/bin/" ]; then
  mkdir /usr/local/bin/
  rc=$?
  if [ "$rc" != "0" ]; then
    echo "Creating /usr/local/bin/ directory failed.  Exiting..."
    exit 1
  fi
fi

#Installing Red Hat Openshift CLI
qs_retry_command 10 wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.8/openshift-client-linux.tar.gz
tar -xvf openshift-client-linux.tar.gz
chmod 755 oc
mv oc /usr/local/bin/oc
rm -rf kubectl
rm -f openshift-client-linux.tar.gz

#Installing Red Hat Openshift installer
qs_retry_command 10 wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.8/openshift-install-linux.tar.gz
tar -xvf openshift-install-linux.tar.gz
chmod 755 openshift-install
mv openshift-install /ibm
rm -f openshift-install-linux.tar.gz

cd ..

#Installing docker engine
wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz
tar -xvf docker-19.03.9.tgz 
cp docker/* /usr/local/bin/
dockerd &> /dev/null &
rm -f ./docker-19.03.9.tgz

#Testing docker
ps -ef |grep docker
docker run hello-world

#Installing cloudctl
curl -L https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz -o cloudctl-linux-amd64.tar.gz
tar -xvf cloudctl-linux-amd64.tar.gz
chmod 755 cloudctl-linux-amd64
mv cloudctl-linux-amd64 /usr/local/bin/cloudctl
rm -f cloudctl-linux-amd64.tar.gz

#Installing jq
wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O /usr/local/bin/jq
chmod 755 /usr/local/bin/jq

#Installing yq
wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_386 -O /usr/local/bin/yq
chmod 755  /usr/local/bin/yq

#Installing certauth
pip3 install certauth

#Installed boto3
qs_retry_command 10 pip install boto3 &> /var/log/userdata.boto3_install.log

#Downloading quick start assets from s3 bucket

if [ -n "$CP4S_QS_S3URI" ]; then
  printf "\nDownloading scripts from S3 bucket...\n"
  aws s3 cp ${CP4S_QS_S3URI}scripts/ /ibm/ --recursive
fi
if [ -n "$DOMAIN_CERTIFICATE_S3URI" ]; then
  printf "\nDownloading TLS certificate from S3 bucket...\n"
  aws s3 cp ${DOMAIN_CERTIFICATE_S3URI} /ibm/tls/tls.crt
  if [ ! -f "/ibm/tls/tls.crt" ]; then
    printf "\nFailed to download TLS certificate from S3 bucket. Invalid S3 Endpoint URI. Exiting...\n"
    exit 1
  fi
fi
if [ -n "$DOMAIN_CERTIFICATE_KEY_S3URI" ]; then
  printf "\nDownloading TLS certificate key from S3 bucket...\n"
  aws s3 cp ${DOMAIN_CERTIFICATE_KEY_S3URI} /ibm/tls/tls.key
  if [ ! -f "/ibm/tls/tls.key" ]; then
    printf "\nFailed to download TLS certificate key from S3 bucket. Invalid S3 Endpoint URI. Exiting...\n"
    exit 1
  fi
fi
if [ -n "$CUSTOM_CA_FILE_S3URI" ]; then
  printf "\nDownloading custom TLS certificate from S3 bucket...\n"
  aws s3 cp ${CUSTOM_CA_FILE_S3URI} /ibm/tls/ca.crt
  if [ ! -f "/ibm/tls/ca.crt" ]; then
    printf "\nFailed to download custom TLS certificate from S3 bucket. Invalid S3 Endpoint URI. Exiting...\n"
    exit 1
  fi
fi
if [ -n "$SOAR_ENTITLEMENT" ]; then
  printf "\nDownloading SOAR entitlement from S3 bucket...\n"
  aws s3 cp ${SOAR_ENTITLEMENT} /ibm/license.key
  if [ ! -f "/ibm/license.key" ]; then
    printf "\nFailed to download SOAR entitlement from S3 bucket. Invalid S3 Endpoint URI. Exiting...\n"
    exit 1
  fi
fi

cd /ibm
if [ ! -d "${PWD}/logs" ]; then
  mkdir logs
  rc=$?
  if [ "$rc" != "0" ]; then
    echo "Creating ${PWD}/logs directory failed.  Exiting..."
    exit 1
  fi
fi

chmod 755 cp4s_install.py
chmod 755 install.sh
chmod 755 install_utils.sh
chmod 755 case_versions.conf
chmod 755 cp4s_parameters.sh
chmod 755 destroy.sh
chmod -R 755 oc
if [ -d "${PWD}/tls/" ]; then
  chmod -R 755 tls
fi
if [ -f "/ibm/license.key" ]; then
  chmod 755 license.key
fi

LOGFILE="${PWD}/logs/bootstrap.log--`date +'%Y-%m-%d_%H-%M-%S'`"
echo $HOME
export KUBECONFIG=/root/.kube/config
echo $KUBECONFIG
echo $PATH
python /ibm/cp4s_install.py --region "${AWS_REGION}" --stackid "${AWS_STACKID}" --stack-name ${AWS_STACKNAME} --logfile $LOGFILE --loglevel "*=all"