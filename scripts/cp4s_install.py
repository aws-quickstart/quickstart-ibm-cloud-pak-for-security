#!/usr/bin/python

# standard library imports
import base64
import json
import os.path
from os import chmod, environ
import shutil
import socket
import stat
from subprocess import check_call, check_output, CalledProcessError #nosec
import sys
import time

# third party imports
import boto3
from botocore.exceptions import ClientError

# local library imports
import yapl.Utilities as Utilities
from yapl.Trace import Trace, Level
from yapl.LogExporter import LogExporter
from yapl.Exceptions import MissingArgumentException

TR = Trace(__name__)
StackParameters = {}
StackParameterNames = []


class CP4SecurityInstall(object):
    ArgsSignature = {
                    '--region': 'string',
                    '--stack-name': 'string',
                    '--stackid': 'string',
                    '--logfile': 'string',
                    '--loglevel': 'string',
                    '--trace': 'string'
                   }

    def __init__(self):
        """
        NOTE: Some instance variable initialization happens
        in self._init() which is invoked early in main() at some
        point after _getStackParameters().
        """
        object.__init__(self)
        self.home = os.path.expanduser("/ibm")
        self.logsHome = os.path.join(self.home, "logs")
    # endDef

    def _getArg(self, synonyms, args, default=None):
        """
        Return the value from the args dictionary that may be specified with
        any of the argument names in the list of synonyms.
        The synonyms argument may be a Jython list of strings or it may be a
        string representation of a list of names with a comma or space
        separating each name.
        The args is a dictionary with the keyword value pairs that are the
        arguments that may have one of the names in the synonyms list.
        If the args dictionary does not include the option that may be named
        by any of the given synonyms then the given default value is returned.

        NOTE: This method has to be careful to make explicit checks for value
        being None rather than something that is just logically false.
        If value gets assigned 0 from the get on the args (command line args)
        dictionary, that appears as false in a condition expression.
        However 0 may be a legitimate value for an input parameter in the args
        dictionary.  We need to break out of the loop that is checking
        synonyms as well as avoid assigning the default value if 0 is the
        value provided in the args dictionary.
        """
        value = None
        if type(synonyms) != type([]):
            synonyms = Utilities.splitString(synonyms)
        # endIf

        for name in synonyms:
            value = args.get(name)
            if value is not None:
                break
            # endIf
        # endFor

        if value is None and default is not None:
            value = default
        # endIf

        return value
    # endDef

    def _configureTraceAndLogging(self, traceArgs):
        """
        Return a tuple with the trace spec and logFile if trace is set based
        on given traceArgs.

        traceArgs is a dictionary with the trace configuration specified.
            loglevel|trace <tracespec>
            logfile|logFile <pathname>

        If trace is specified in the trace arguments then set up the trace.
        If a log file is specified, then set up the log file as well.
        If trace is specified and no log file is specified, then the log file
        is set to "trace.log" in the current working directory.
        """
        logFile = self._getArg(['logFile', 'logfile'], traceArgs)
        if logFile:
            TR.appendTraceLog(logFile)
        # endIf

        trace = self._getArg(['trace', 'loglevel'], traceArgs)

        if trace:
            if not logFile:
                TR.appendTraceLog('trace.log')
            # endIf

        TR.configureTrace(trace)
        # endIf
        return (trace, logFile)
    # endDef

    def getStackParameters(self, stackId):
        """
        Return a dictionary with stack parameter name-value pairs from the
        CloudFormation stack with the given stackId.
        """
        result = {}
        stack = self.cfnResource.Stack(stackId)
        stackParameters = stack.parameters
        for parm in stackParameters:
            parmName = parm['ParameterKey']
            parmValue = parm['ParameterValue']
            result[parmName] = parmValue
        # endFor

        return result

    def __getattr__(self, attributeName):
        """
        Support for attributes that are defined in the StackParameterNames
        list and with values in the StackParameters dictionary.
        """
        attributeValue = None
        if attributeName in StackParameterNames:
            attributeValue = StackParameters.get(attributeName)
        else:
            raise AttributeError("%s isn't a stack parameter" % attributeName)
        # endIf

        return attributeValue
    # endDef

    def __setattr__(self, attributeName, attributeValue):
        """
        Support for attributes that are defined in the StackParameterNames
        list and with values in the StackParameters dictionary.

        NOTE: The StackParameters are intended to be read-only.  It's not
        likely they would be set in the Bootstrap instance once they are
        initialized in getStackParameters().
        """
        if attributeName in StackParameterNames:
            StackParameters[attributeName] = attributeValue
        else:
            object.__setattr__(self, attributeName, attributeValue)
        # endIf
    # endDef

    def printTime(self, beginTime, endTime, text):
        """
        Method to capture time elapsed for each event during installation.
        """
        methodName = "printTime"
        elapsedTime = (endTime - beginTime)/1000
        etm, ets = divmod(elapsedTime, 60)
        eth, etm = divmod(etm, 60)
        TR.info(methodName, "Elapsed time (hh:mm:ss): %d:%02d:%02d for %s" % (eth, etm, ets, text))
    # endDef

    def updateTemplateFile(self, source, placeHolder, value):
        """
        Method to update placeholder values in templates
        """
        source_file = open(source).read()
        source_file = source_file.replace(placeHolder, value)
        updated_file = open(source, 'w')
        updated_file.write(source_file)
        updated_file.close()
    # endDef

    def readFileContent(self, source):
        file = open(source, mode='r')
        content = file.read()
        file.close()
        return content.rstrip()
    # endDef

    def __init(self, stackId, stackName, ocpInstallLogFile):
        methodName = "_init"
        global StackParameters, StackParameterNames
        boto3.setup_default_session(region_name=self.region)
        self.cfnResource = boto3.resource('cloudformation', region_name=self.region)
        self.cf = boto3.client('cloudformation', region_name=self.region)
        self.ec2 = boto3.client('ec2', region_name=self.region)
        self.s3 = boto3.client('s3', region_name=self.region)
        self.iam = boto3.client('iam', region_name=self.region)
        self.secretsmanager = boto3.client('secretsmanager', region_name=self.region)
        self.ssm = boto3.client('ssm', region_name=self.region)

        StackParameters = self.getStackParameters(stackId)
        StackParameterNames = StackParameters.keys()
        TR.info(methodName, "self.stackParameters %s" % StackParameters)
        TR.info(methodName, "self.stackParameterNames %s" % StackParameterNames)
        self.logExporter = LogExporter(
            region=self.region,
            bucket=self.CP4SDeploymentLogsBucketName,
            keyPrefix=stackName,
            fqdn=socket.getfqdn())

        TR.info(methodName, "Creating SSH keys")
        command = "ssh-keygen -P {}  -f /root/.ssh/id_rsa".format("''")
        try:
            check_call(['bash', '-c', command], stdout=ocpInstallLogFile)
            TR.info(methodName, "Created SSH keys")
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e
    # endDef

    def getSecret(self, ocpInstallLogFile):
        methodName = "getSecret"
        TR.info(methodName, "Retrieving secrets %s" % self.cp4sSecret)
        get_secret_value_response = self.secretsmanager.get_secret_value(SecretId=self.cp4sSecret)
        if 'SecretString' in get_secret_value_response:
            secret = get_secret_value_response['SecretString']
            secretDict = json.loads(secret)
            self.repositoryPassword = secretDict['repositoryPassword']
        TR.info(methodName, "Retrieved secrets")
    # endDef

    def updateSecret(self, ocpInstallLogFile):
        methodName = "updateSecret"
        TR.info(methodName, "Updating Openshift secret %s" % self.ocpSecret)
        secret_update_oc = '{"ocpPassword": "' + self.ocpassword + '"}'
        response = self.secretsmanager.update_secret(SecretId=self.ocpSecret, SecretString=secret_update_oc)
        TR.info(methodName, "Updated secret for %s with response %s" % (self.ocpSecret, response))
        TR.info(methodName, "End updating Openshift secret")
    # endDef

    def exportResult(self, name, parameterValue, ocpInstallLogFile):
        methodName = "exportResult"
        TR.info(methodName, "Start exporting result")
        self.ssm.put_parameter(
            Name=name,
            Value=parameterValue,
            Type='String',
            Overwrite=True)
        TR.info(methodName, "Value: %s put to: %s." % (parameterValue, name))
    # endDef

    def installOCP(self, ocpInstallLogFile):
        methodName = "installOCP"
        TR.info(methodName, "Starting installation of Openshift Container Platform")

        installConfigFile = "/ibm/installDir/install-config.yaml"
        autoScalerFile = "/ibm/templates/cp4s/machine-autoscaler.yaml"
        healthcheckFile = "/ibm/templates/cp4s/health-check.yaml"

        icf_1az = "/ibm/installDir/install-config-1AZ.yaml"
        icf_3az = "/ibm/installDir/install-config-3AZ.yaml"

        asf_1az = "/ibm/templates/cp4s/machine-autoscaler-1AZ.yaml"
        asf_3az = "/ibm/templates/cp4s/machine-autoscaler-3AZ.yaml"

        hc_1az = "/ibm/templates/cp4s/health-check-1AZ.yaml"
        hc_3az = "/ibm/templates/cp4s/health-check-3AZ.yaml"

        if self.no_of_zones == '1':
            shutil.copyfile(icf_1az, installConfigFile)
            shutil.copyfile(asf_1az, autoScalerFile)
            shutil.copyfile(hc_1az, healthcheckFile)
        # endIf

        if self.no_of_zones == '3':
            shutil.copyfile(icf_3az, installConfigFile)
            shutil.copyfile(asf_3az, autoScalerFile)
            shutil.copyfile(hc_3az, healthcheckFile)
        # endIf

        self.updateTemplateFile(installConfigFile, '${az1}', self.zones[0])
        self.updateTemplateFile(installConfigFile, '${baseDomain}', self.DomainName)
        self.updateTemplateFile(installConfigFile, '${master-instance-type}', self.MasterInstanceType)
        self.updateTemplateFile(installConfigFile, '${worker-instance-type}', self.ComputeInstanceType)
        self.updateTemplateFile(installConfigFile, '${worker-instance-count}', self.NumberOfCompute)
        self.updateTemplateFile(installConfigFile, '${master-instance-count}', self.NumberOfMaster)
        self.updateTemplateFile(installConfigFile, '${region}', self.region)
        self.updateTemplateFile(installConfigFile, '${subnet-1}', self.PrivateSubnet1ID)
        self.updateTemplateFile(installConfigFile, '${subnet-2}', self.PublicSubnet1ID)
        self.updateTemplateFile(installConfigFile, '${pullSecret}', self.readFileContent(self.pullSecret))
        self.updateTemplateFile(installConfigFile, '${sshKey}', self.readFileContent("/root/.ssh/id_rsa.pub"))
        self.updateTemplateFile(installConfigFile, '${clustername}', self.ClusterName)
        self.updateTemplateFile(installConfigFile, '${machine-cidr}', self.VPCCIDR)
        self.updateTemplateFile(autoScalerFile, '${az1}', self.zones[0])
        self.updateTemplateFile(healthcheckFile, '${az1}', self.zones[0])

        if self.no_of_zones == '3':
            self.updateTemplateFile(installConfigFile, '${az2}', self.zones[1])
            self.updateTemplateFile(installConfigFile, '${az3}', self.zones[2])
            self.updateTemplateFile(installConfigFile, '${subnet-3}', self.PrivateSubnet2ID)
            self.updateTemplateFile(installConfigFile, '${subnet-4}', self.PrivateSubnet3ID)
            self.updateTemplateFile(installConfigFile, '${subnet-5}', self.PublicSubnet2ID)
            self.updateTemplateFile(installConfigFile, '${subnet-6}', self.PublicSubnet3ID)
            self.updateTemplateFile(autoScalerFile, '${az2}', self.zones[1])
            self.updateTemplateFile(autoScalerFile, '${az3}', self.zones[2])
            self.updateTemplateFile(healthcheckFile, '${az2}', self.zones[1])
            self.updateTemplateFile(healthcheckFile, '${az3}', self.zones[2])

        TR.info(methodName, "Initiating installation of Openshift Container Platform")
        os.chmod("/ibm/openshift-install", stat.S_IEXEC)
        install_ocp = "sudo ./openshift-install create cluster --dir=/ibm/installDir --log-level=debug"
        TR.info(methodName, "Output File name: %s" % ocpInstallLogFile)
        try:
            check_call(['bash', '-c', install_ocp], stdout=ocpInstallLogFile, stderr=ocpInstallLogFile)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}".format(e.cmd, e.returncode))
            raise e
        TR.info(methodName, "Installed Openshift Container Platform")
        time.sleep(30)
        destDir = "/root/.kube"
        if not os.path.exists(destDir):
            os.makedirs(destDir)
        # endIf
        shutil.copyfile("/ibm/installDir/auth/kubeconfig", "/root/.kube/config")

        self.ocpassword = self.readFileContent("/ibm/installDir/auth/kubeadmin-password").rstrip("\n\r")
        self.logincmd = "oc login -u kubeadmin -p " + self.ocpassword
        try:
            check_call(['bash', '-c', self.logincmd])
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}".format(e.cmd, e.returncode))
            raise e

        get_clusterId = r"oc get machineset -n openshift-machine-api -o jsonpath='{.items[0].metadata.labels.machine\.openshift\.io/cluster-api-cluster}'"
        TR.info(methodName, "Cluster ID %s" % get_clusterId)
        try:
            self.clusterID = check_output(['bash', '-c', get_clusterId])
            TR.info(methodName, "Cluster ID %s" % self.clusterID)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e

        self.updateTemplateFile(autoScalerFile, 'CLUSTERID', self.clusterID)
        create_machine_as_cmd = "oc create -f " + autoScalerFile
        TR.info(methodName, "Creating Machine Autoscaler")
        try:
            retcode = check_output(['bash', '-c', create_machine_as_cmd])
            TR.info(methodName, "Created Machine Autoscaler %s" % retcode)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e

        self.updateTemplateFile(healthcheckFile, 'CLUSTERID', self.clusterID)
        create_healthcheck_cmd = "oc create -f " + healthcheckFile
        TR.info(methodName, "Creating Machine Health Check")
        try:
            retcode = check_output(['bash', '-c', create_healthcheck_cmd])
            TR.info(methodName, "Created Machine Health Check %s" % retcode)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e

        TR.info(methodName, "Creating OCP registry")

        registry_mc = "/ibm/templates/cp4s/insecure-registry.yaml"
        registries = "/ibm/templates/cp4s/registries.conf"
        crio_conf = "/ibm/templates/cp4s/crio.conf"
        crio_mc = "/ibm/templates/cp4s/crio-mc.yaml"

        route = "default-route-openshift-image-registry.apps." + self.ClusterName + "." + self.DomainName
        self.updateTemplateFile(registries, '${registry-route}', route)

        config_data = base64.b64encode(self.readFileContent(registries))
        self.updateTemplateFile(registry_mc, '${config-data}', config_data)

        crio_config_data = base64.b64encode(self.readFileContent(crio_conf))
        self.updateTemplateFile(crio_mc, '${crio-config-data}', crio_config_data)

        route_cmd = "oc patch configs.imageregistry.operator.openshift.io/cluster --type merge -p '{\"spec\":{\"defaultRoute\":true,\"replicas\":"+self.NumberOfAZs+"}}'"
        TR.info(methodName, "Creating route with command %s" % route_cmd)
        try:
            retcode = check_output(['bash', '-c', route_cmd])
            TR.info(methodName, "Created route with command %s returned %s" % (route_cmd, retcode))
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e
        destDir = "/etc/containers/"
        if not os.path.exists(destDir):
            os.makedirs(destDir)
        # endIf
        shutil.copyfile(registries, "/etc/containers/registries.conf")
        create_registry = "oc create -f " + registry_mc
        create_crio_mc = "oc create -f " + crio_mc

        TR.info(methodName, "Creating registry mc with command %s" % create_registry)
        try:
            reg_retcode = check_output(['bash', '-c', create_registry])
            TR.info(methodName, "Creating crio mc with command %s" % create_crio_mc)
            crio_retcode = check_output(['bash', '-c', create_crio_mc])
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e
        TR.info(methodName, "Created regsitry with command %s returned %s" % (create_registry, reg_retcode))
        TR.info(methodName, "Created Crio mc with command %s returned %s" % (create_crio_mc, crio_retcode))

        create_cluster_as_cmd = "oc create -f /ibm/templates/cp4s/cluster-autoscaler.yaml"
        TR.info(methodName, "Applying autoscaling to an OpenShift Container Platform cluster")
        try:
            retcode = check_output(['bash', '-c', create_cluster_as_cmd])
            TR.info(methodName, "Applied autoscaling to an OpenShift Container Platform cluster %s" % retcode)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e

        sysctl_cmd = "oc create -f /ibm/templates/cp4s/wkc-sysctl-mc.yaml"
        TR.info(methodName, "Creating SystemCtl Machine config")
        try:
            retcode = check_output(['bash', '-c', sysctl_cmd])
            TR.info(methodName, "Created SystemCtl Machine config %s" % retcode)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e

        secLimits_cmd = "oc create -f /ibm/templates/cp4s/security-limits-mc.yaml"
        TR.info(methodName, "Create Security Limits Machine config")
        try:
            retcode = check_output(['bash', '-c', secLimits_cmd])
            TR.info(methodName, "Created Security Limits Machine config %s" % retcode)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e
        time.sleep(600)

        oc_route_cmd = "oc get route console -n openshift-console | grep 'console' | awk '{print $2}'"
        TR.info(methodName, "Retrieving OpenShift Container Platform URL")
        try:
            self.openshiftURL = check_output(['bash', '-c', oc_route_cmd])
            TR.info(methodName, "Retrieved OpenShift Container Platform URL %s" % self.openshiftURL)
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e
        TR.info(methodName, "Completed installation of Openshift Container Platform")
    # endDef

    def installCP4S(self, ocpInstallLogFile):
        methodName = "installCP4S"

        TR.info(methodName, "Starting installation of IBM Cloud Pak for Security %s" % self.CP4SVersion)
        self.ocpServerURL = "api." + self.ClusterName + "." + self.DomainName + ":6443"  #nosec
        if self.CP4SFQDN == "":
            self.CP4SFQDN = "-"
        if self.StorageClass == "":
            self.StorageClass = "-"
        if self.BackupStorageClass == "":
            self.BackupStorageClass = "-"
        if self.BackupStorageSize == "":
            self.BackupStorageSize = "-"
        install_cp4s = (
            "bash install.sh " +
            self.CP4SFQDN + " " +
            self.ocpServerURL + " " +
            self.ocpassword + " " +
            self.AdminUser + " " +
            self.StorageClass + " " +
            self.BackupStorageClass + " " +
            self.BackupStorageSize + " " +
            self.ImagePullPolicy + " " +
            self.repositoryPassword + " " +
            self.DeployDRC + " " +
            self.DeployRiskManager + " " +
            self.DeployThreatInvestigator + " " +
            self.CP4SVersion + " " +
            self.Namespace)
        try:
            TR.info(methodName, "Initiating installation of IBM Cloud Pak for Security %s" % self.CP4SVersion)
            check_call(['bash', '-c', install_cp4s])
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}".format(e.cmd, e.returncode))
            raise e
        TR.info(methodName, "Completed installation of IBM Cloud Pak for Security %s" % self.CP4SVersion)

        TR.info(methodName, "Start getting IBM Cloud Pak for Security platform FQDN")
        get_route = "oc get route -n " + self.Namespace + " isc-route-default -o jsonpath='{.spec.host}'"
        try:
            self.icp4sFQDN = check_output(['bash', '-c', get_route])
        except CalledProcessError as e:
            TR.error(methodName, "[ERROR] Command '{}' returned non-zero exit status {}: {}".format(e.cmd, e.returncode, e.output))
            raise e
        TR.info(methodName, "IBM Cloud Pak for Security platform FQDN: %s" % self.icp4sFQDN)
        TR.info(methodName, "End getting IBM Cloud Pak for Security platform FQDN")
    # endDef

    def main(self, argv):
        methodName = "main"
        self.rc = 0
        try:
            beginTime = Utilities.currentTimeMillis()
            cmdLineArgs = Utilities.getInputArgs(self.ArgsSignature, argv[1:])
            trace, logFile = self._configureTraceAndLogging(cmdLineArgs)
            self.region = cmdLineArgs.get('region')
            if logFile:
                TR.appendTraceLog(logFile)
            if trace:
                TR.info(methodName, "Tracing with specification: '%s' to log file: '%s'" % (trace, logFile))
            logFilePath = os.path.join(self.logsHome, "ocp_install.log")

            with open(logFilePath, "a+") as ocpInstallLogFile:
                self.stackId = cmdLineArgs.get('stackid')
                self.stackName = cmdLineArgs.get('stack-name')
                self.amiID = environ.get('AMI_ID')
                self.cp4sSecret = environ.get('CP4S_SECRET')
                self.ocpSecret = environ.get('OCP_SECRET')
                self.ICP4SInstallationCompletedURL = environ.get('ICP4SInstallationCompletedURL')
                TR.info(methodName, "AMI ID %s " % self.amiID)
                TR.info(methodName, "ICP4SInstallationCompletedURL %s " % self.ICP4SInstallationCompletedURL)
                TR.info(methodName, "CP4S Secret %s " % self.cp4sSecret)
                TR.info(methodName, "OCP Secret %s " % self.ocpSecret)
                self.__init(self.stackId, self.stackName, ocpInstallLogFile)
                self.no_of_zones = self.NumberOfAZs
                self.zones = Utilities.splitString(self.AvailabilityZones)
                TR.info(methodName, "Number of Availability Zones: %s" % self.no_of_zones)
                TR.info(methodName, "Availability Zones: %s" % self.zones)

                # copy Red Hat pull secret from Amazon S3
                TR.info(methodName, "Red Hat pull secret S3 URI %s" % self.RedhatPullSecret) #nosec
                self.pullSecret = "/ibm/pull-secret"  #nosec
                s3_cp_cmd = "aws s3 cp " + self.RedhatPullSecret + " " + self.pullSecret #nosec
                TR.info(methodName, "Copying Red Hat Pull Secret %s" % s3_cp_cmd)
                try:
                    check_call(['bash', '-c', s3_cp_cmd], stdout=ocpInstallLogFile)
                except CalledProcessError as e:
                    TR.error(methodName, "[ERROR] Couldn't copy Red Hat pull secret from S3 bucket. Invalid S3 endpoint URI.")
                    raise e

                # retrieve the secrets from AWS Secrets Manager
                self.getSecret(ocpInstallLogFile)

                # install OpenShift Container Platform
                ocp_start = Utilities.currentTimeMillis()
                self.installOCP(ocpInstallLogFile)
                ocp_end = Utilities.currentTimeMillis()
                self.printTime(ocp_start, ocp_end, "Installing OpenShift Container Platform")

                # install IBM Cloud Pak for Security
                cp4s_start = Utilities.currentTimeMillis()
                self.installCP4S(ocpInstallLogFile)
                cp4s_end = Utilities.currentTimeMillis()
                self.printTime(cp4s_start, cp4s_end, "Installing IBM Cloud Pak for Security")
                time.sleep(30)

                # export OpenShift Container Platform web console URL.
                self.exportResult(self.stackName+"-OpenShiftURL", "https://"+self.openshiftURL, ocpInstallLogFile)
                # export IBM Cloud Pak for Security platform URL.
                self.exportResult(self.stackName+"-CP4SURL", "https://"+self.icp4sFQDN+"/console", ocpInstallLogFile)

                # update the contents of secrete resource in AWS Secrets Manager
                self.updateSecret(ocpInstallLogFile)
            # endWith

        except Exception as e:
            TR.error(methodName, "Exception with message %s" % e)
            self.rc = 1
        finally:
            try:
                # copy logs to the CP4S deployment logs S3 bucket.
                self.logExporter.exportLogs("/var/log/")
                self.logExporter.exportLogs("%s" % self.logsHome)
            except Exception as e:
                TR.error(methodName, "[ERROR] Can't copy logs to CP4S deployment logs S3 bucket: %s" % e, e)
                self.rc = 1
        endTime = Utilities.currentTimeMillis()
        elapsedTime = (endTime - beginTime)/1000
        etm, ets = divmod(elapsedTime, 60)
        eth, etm = divmod(etm, 60)

        if self.rc == 0:
            success = 'true'
            status = 'SUCCESS'
            TR.info(methodName, "SUCCESS END CP4S Install AWS IBM Cloud Pak for Security Quick Start.  Elapsed time (hh:mm:ss): %d:%02d:%02d" % (eth, etm, ets))
        else:
            success = 'false'
            status = 'FAILURE: Check logs in the CP4S deployment logs S3 bucket or on the Boot node EC2 instance in /ibm/logs/bootstrap.log, /ibm/logs/ocp_install.log and /ibm/logs/cp4s_install.log.'
            TR.info(methodName, "FAILED END CP4S Install AWS IBM Cloud Pak for Security Quick Start.  Elapsed time (hh:mm:ss): %d:%02d:%02d" % (eth, etm, ets))
        # endIf

        try:
            data = "%s: IBM Cloud Pak installation elapsed time: %d:%02d:%02d" % (status, eth, etm, ets)
            check_call([
                'cfn-signal',
                '--success', success,
                '--id', self.stackId,
                '--reason', status,
                '--data', data,
                self.ICP4SInstallationCompletedURL])   
        except CalledProcessError as e:
            TR.error(methodName, "ERROR return code: %s, Exception: %s" % (e.returncode, e), e)
            raise e                                              
    # endDef
# endClass
if __name__ == '__main__':
    mainInstance = CP4SecurityInstall()
    mainInstance.main(sys.argv)
# endIf
