import os
import stat
import sys
from subprocess import Popen
import boto3
import logging
import json

class OCPInstall():
    """Install OCP/PAK by initializing this class and calling the run_install()
    method with the object.
    """
    def __init__(self, region, stack_params, apikey):
        """Provide a region and stack ID to initialize boto3 and download
        stack parameters.
        """
        try:
            self.secret_id = secret_id
            self.region = region
            self.stack_params = stack_params
            self.sec = boto3.client('secretsmanager',
                                    region_name=self.region)
            self.s3 = boto3.client("s3",
                                   region_name=self.region)
        except Exception as e:
            logging.error(e)

    def run_install(self):
        """Configure machine, install-config, and runs openshift-install."""
        try:
            logging.info("STARTED OCP INSTALL")
            logging.info("GENERATE SSH KEY")
            os.popen("ssh-keygen -P {}  -f /root/.ssh/id_rsa".format("''"))
            ssh_key = open("/root/.ssh/id_rsa.pub", "r").read()

            logging.info("GATHERING PULL SECRET")
            pull_secret = open("/ibm/pull-secret", "r").read()

            logging.info("EDITING FILE PERMISSIONS FOR CLI TOOLS")
            os.chmod("/usr/local/bin/oc", stat.S_IEXEC)
            os.chmod("/usr/local/bin/kubectl", stat.S_IEXEC)
            os.chmod("/ibm/openshift-install", stat.S_IEXEC)

            logging.info("CONFIGURING INSTALL-CONFIG.YAML")
            install_config_template = open("/ibm/installDir/1AZ.yaml",
                                           "r").read()
            install_config_template = install_config_template.replace(
                "${az1}",
                self.stack_params["AvailabilityZones"])
            install_config_template = install_config_template.replace(
                "${baseDomain}",
                self.stack_params["DomainName"])
            install_config_template = install_config_template.replace(
                "${master-instance-type}",
                self.stack_params["MasterInstanceType"])
            install_config_template = install_config_template.replace(
                "${worker-instance-type}",
                self.stack_params["ComputeInstanceType"])
            install_config_template = install_config_template.replace(
                "${master-instance-count}",
                self.stack_params["NumberOfMaster"])
            install_config_template = install_config_template.replace(
                "${worker-instance-count}",
                self.stack_params["NumberOfCompute"])
            install_config_template = install_config_template.replace(
                "${region}",
                self.region)
            install_config_template = install_config_template.replace(
                "${subnet-1}",
                self.stack_params["PrivateSubnet1ID"])
            install_config_template = install_config_template.replace(
                "${subnet-2}",
                self.stack_params["PublicSubnet1ID"])
            install_config_template = install_config_template.replace(
                "${pullSecret}",
                pull_secret)
            install_config_template = install_config_template.replace(
                "${sshKey}",
                ssh_key)
            install_config_template = install_config_template.replace(
                "${clustername}",
                self.stack_params["ClusterName"])
            install_config_template = install_config_template.replace(
                "${FIPS}",
                self.stack_params["EnableFips"])
            install_config_template = install_config_template.replace(
                "${machine-cidr}",
                self.stack_params["VPCCIDR"])
            with open("/ibm/installDir/install-config.yaml",
                      "w+") as icfg_file:
                icfg_file.write(install_config_template)
                icfg_file.close()

            logging.info("STARTING OCP INSTALL")

            install_ocp = """cd /ibm; \
            sudo ./openshift-install create cluster \
            --dir=/ibm/installDir --log-level=debug"""

            logfile = open("openshift_install.log", "w+")
            process_ocp = Popen(install_ocp,
                                shell=True,
                                stdout=logfile,
                                stderr=logfile,
                                close_fds=True)
            stdoutdata, stderrdata = process_ocp.communicate()
            logging.info(stdoutdata)
            logging.info(stderrdata)

            logging.info("CONFIGURE KUBECONFIG")

            os.popen("cp /ibm/installDir/auth/kubeconfig /root/.kube/config")
            logging.info(os.popen("oc whoami").read())
            logging.info(os.popen("oc whoami -t").read())

            logging.info("INSTALL OCP COMPLETE - STARTING CP4S INSTALL")
            logging.info("GATHERING IBM REGISTRY ENTITLEMENT KEY")

            secrets_raw = self.sec.get_secret_value(SecretId=self.secret_id)
            if 'SecretString' in secrets_raw:
                secret = secrets_raw["SecretString"]
                secrets_dict = json.loads(secret)

            install_cps = ("bash install.sh " +
                           secrets_dict["apikey"] + " " +
                           self.stack_params["CPSFQDN"] + " " +
                           "api." + stack_params["ClusterName"] + "." +
                           stack_params["DomainName"] + ":6443" +
                           secrets_dict["adminPassword"])

            logging.info(install_cps)
            logging.info(os.popen(install_cps).read())
            logging.info("INSTALL CP4S COMPLETE")

        except Exception as e:
            raise Exception(e)

# Start logging
logging.basicConfig(level=logging.DEBUG,
                    filename="i.log", filemode="a+",
                    format="%(asctime)-15s %(levelname)-8s %(message)s",
                    stream=sys.stdout)

# Start installation of OCP
try:
    logging.info(sys.argv[1:])
    region = sys.argv[1]
    stack_id = sys.argv[2]
    secret_id = sys.argv[3]

    logging.info("LOAD STACK PARAMETERS")
    boto3.setup_default_session(region_name=region)
    cf = boto3.client("cloudformation", region_name=region)
    cfn_resource = boto3.resource("cloudformation", region_name=region)
    raw_stack_params = cfn_resource.Stack(stack_id).parameters
    stack_params = {}

    for param in raw_stack_params:
        stack_params[param["ParameterKey"]] = param["ParameterValue"]

    logging.info(stack_params)

    installer = OCPInstall(region, stack_params, secret_id)
    installer.run_install()

except Exception as e:
    logging.error(e)
