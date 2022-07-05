#!/bin/bash

SCRIPT=${0##*/}
echo $SCRIPT
source /etc/profile.d/cp4s_install.sh
source ${P}

# Function to signal the wait condition handle (ICP4SInstallationCompletedURL) status from cfn-init
cfn_init_status() {
    /usr/bin/cfn-signal -s false -r "FAILURE: Bootstrap action failed. Error executing bootstrap script. ${failure_msg}" $ICP4SInstallationCompletedURL
    sleep 300
    aws ssm put-parameter --name $AWS_STACKNAME"_CleanupStatus" --type "String" --value "READY" --overwrite
    exit 1
}

# Enable EPEL repo
qs_enable_epel &> /var/log/userdata.qs_enable_epel.log

cd /tmp

# Installing AWS SSM agent
qs_retry_command 10 wget https://s3-us-west-1.amazonaws.com/amazon-ssm-us-west-1/latest/linux_amd64/amazon-ssm-agent.rpm
rc=$?
if [ "$rc" != "0" ]; then
  failure_msg="[ERROR] Couldn't download Amazon SSM agent."
  cfn_init_status "$failure_msg"
fi
qs_retry_command 10 yum install -y ./amazon-ssm-agent.rpm
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent
rm -f ./amazon-ssm-agent.rpm

if [ ! -d "/usr/local/bin/" ]; then
  mkdir /usr/local/bin/
  rc=$?
  if [ "$rc" != "0" ]; then
    failure_msg="[ERROR] Couldn't create /usr/local/bin/ directory."
    cfn_init_status "$failure_msg"
  fi
fi

# Installing Red Hat Openshift 4.8 CLI
qs_retry_command 10 wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.8/openshift-client-linux.tar.gz
rc=$?
if [ "$rc" != "0" ]; then
  failure_msg="[ERROR] Couldn't download Red Hat Openshift CLI."
  cfn_init_status "$failure_msg"
fi
tar -xvf openshift-client-linux.tar.gz
chmod 755 oc
mv oc /usr/local/bin/oc
rm -rf kubectl
rm -f openshift-client-linux.tar.gz

# Installing Red Hat Openshift 4.8 installer
qs_retry_command 10 wget https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.8/openshift-install-linux.tar.gz
rc=$?
if [ "$rc" != "0" ]; then
  failure_msg="[ERROR] Couldn't download Red Hat Openshift installer."
  cfn_init_status "$failure_msg"
fi
tar -xvf openshift-install-linux.tar.gz
chmod 755 openshift-install
mv openshift-install /ibm
rm -f openshift-install-linux.tar.gz

cd ..

# Installing Docker CLI 19.x.x
wget https://download.docker.com/linux/static/stable/x86_64/docker-19.03.9.tgz
rc=$?
if [ "$rc" != "0" ]; then
  failure_msg="[ERROR] Couldn't download Docker CLI."
  cfn_init_status "$failure_msg"
fi
tar -xvf docker-19.03.9.tgz 
cp docker/* /usr/local/bin/
dockerd &> /dev/null &
rm -f ./docker-19.03.9.tgz

# Testing Docker
ps -ef | grep docker
docker run hello-world

# Installing Cloud Pak CLI latest version
curl -L https://github.com/IBM/cloud-pak-cli/releases/latest/download/cloudctl-linux-amd64.tar.gz -o cloudctl-linux-amd64.tar.gz
rc=$?
if [ "$rc" != "0" ]; then
  failure_msg="[ERROR] Couldn't download Cloud Pak CLI."
  cfn_init_status "$failure_msg"
fi
tar -xvf cloudctl-linux-amd64.tar.gz
chmod 755 cloudctl-linux-amd64
mv cloudctl-linux-amd64 /usr/local/bin/cloudctl
rm -f cloudctl-linux-amd64.tar.gz

# Installing jq
wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O /usr/local/bin/jq
rc=$?
if [ "$rc" != "0" ]; then
  failure_msg="[ERROR] Couldn't download jq."
  cfn_init_status "$failure_msg"
fi
chmod 755 /usr/local/bin/jq

# Installing yq
wget https://github.com/mikefarah/yq/releases/download/3.4.0/yq_linux_386 -O /usr/local/bin/yq
rc=$?
if [ "$rc" != "0" ]; then
  failure_msg="[ERROR] Couldn't download yq."
  cfn_init_status "$failure_msg"
fi
chmod 755  /usr/local/bin/yq

# Installed boto3
qs_retry_command 10 pip install boto3 &> /var/log/userdata.boto3_install.log

# Downloading Quick Start assets from S3 bucket

if [ -n "$CP4S_QS_S3URI" ]; then
  # Downloading Quick Start scripts from S3 bucket
  aws s3 cp ${CP4S_QS_S3URI}scripts/ /ibm/ --recursive
  rc=$?
  if [ "$rc" != "0" ]; then
    failure_msg="[ERROR] Quick Start scripts couldn't be downloaded from S3 bucket. Invalid S3 endpoint URI."
    cfn_init_status "$failure_msg"
  fi
fi

if [ -n "$DOMAIN_CERTIFICATE_S3URI" ]; then
  # Downloading TLS certificate from S3 bucket
  aws s3 cp ${DOMAIN_CERTIFICATE_S3URI} /ibm/tls/tls.crt
  rc=$?
  if [ "$rc" != "0" ]; then
    failure_msg="[ERROR] TLS certificate couldn't be downloaded from S3 bucket. Invalid S3 endpoint URI."
    cfn_init_status "$failure_msg"
  fi
fi

if [ -n "$DOMAIN_CERTIFICATE_KEY_S3URI" ]; then
  # Downloading TLS certificate key from S3 bucket
  aws s3 cp ${DOMAIN_CERTIFICATE_KEY_S3URI} /ibm/tls/tls.key
  rc=$?
  if [ "$rc" != "0" ]; then
    failure_msg="[ERROR] TLS certificate key couldn't be downloaded from S3 bucket. Invalid S3 endpoint URI."
    cfn_init_status "$failure_msg"
  fi
fi

if [ -n "$CUSTOM_CA_FILE_S3URI" ]; then
  # Downloading custom TLS certificate from S3 bucket
  aws s3 cp ${CUSTOM_CA_FILE_S3URI} /ibm/tls/ca.crt
  rc=$?
  if [ "$rc" != "0" ]; then
    failure_msg="[ERROR] Custom TLS certificate couldn't be downloaded from S3 bucket. Invalid S3 endpoint URI."
    cfn_init_status "$failure_msg"
  fi
fi

if [ -n "$SOAR_ENTITLEMENT" ]; then
  # Downloading SOAR entitlement from S3 bucket
  aws s3 cp ${SOAR_ENTITLEMENT} /ibm/license.key
  rc=$?
  if [ "$rc" != "0" ]; then
    failure_msg="[ERROR] SOAR entitlement couldn't be downloaded from S3 bucket. Invalid S3 endpoint URI."
    cfn_init_status "$failure_msg"
  fi
fi

cd /ibm
if [ ! -d "${PWD}/logs" ]; then
  mkdir logs
  rc=$?
  if [ "$rc" != "0" ]; then
    failure_msg="[ERROR] Couldn't create ${PWD}/logs directory."
    cfn_init_status "$failure_msg"
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

LOGFILE="${PWD}/logs/bootstrap.log"
echo $HOME
export KUBECONFIG=/root/.kube/config
echo $KUBECONFIG
echo $PATH
python /ibm/cp4s_install.py --region "${AWS_REGION}" --stackid "${AWS_STACKID}" --stack-name ${AWS_STACKNAME} --logfile $LOGFILE --loglevel "*=all"