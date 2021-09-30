#!/usr/bin/env bash

#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020,2021. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

#----- LOGS -------
log_file="/tmp/cp4s.log-`date +'%Y-%m-%d_%H-%M-%S'`"
exec &> >(tee -a "$log_file")
# ***** GLOBALS *****
# ----- DEFAULTS -----
export kubernetesCLI="oc"
export scriptName=$(basename "$0")
export scriptDir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CS_NAMESPACE="ibm-common-services"
dryRun=""
namespace=""
repositoryType=""
appName="ibm-cp-security"
# Script invocation defaults for parms populated via cloudctl
action=""
uninstall=""
caseJsonFile=""
export casePath="${scriptDir}/../../.."
foundations_release_name="ibm-security-foundations"
solutions_release_name="ibm-security-solutions"
inventory=""
airgapInstall=""
license="not accepted"
configFile="${scriptDir}/values.conf"
pullPolicy=""
enableAdapter=""
setsupGroup=""
setfsGroup=""
setbackrestGroup=""
setbackrestsupGroup=""
setbackupStorage=""
cases_images="${casePath}"/inventory/installProduct/files/cases_images.yaml
DOMAIN_SET=0
function parse_dynamic_args() {
    _IFS=$IFS
    IFS=" "
    read -ra arr <<<"${1}"
    IFS="$_IFS"
    arr+=("")
    idx=0
    v="${arr[${idx}]}"

    while [ "$v" != "" ]; do
        case $v in
        # Enable debug from cloudctl invocation
        --debug)
            idx=$((idx + 1))
            set -x
            ;;
        --dryRun)
            dryRun="--dry-run"
            ;;
        --airgap)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            export airgapInstall=1
            ;;
        --license)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            license="$v"
            ;;
        --chartsDir)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            export chartsDir="$v"
            ;;
        --devmode)
            dev=1
            ;;
        --registry)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            export registry="$v"
            ;;
        --user)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            export user="$v"
            ;;
        --pass)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            export pass="$v"
            ;;
        --inputDir)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            export inputcasedir="$v"
            ;;
        --helm3)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            helm_3="$v"
            ;;
        --helm2)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            helm_2="$v"
            ;;
        --image)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            connectorImage="$v"
            ;;
        --type)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            connectorType="$v"
            ;;
        --name)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            connectorName="$v"
            ;;
        --help)
            $scriptDir/support/usage.sh
            sleep 2
            exit
            ;;
        --force)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            forceInstall="true"
            ;;
        *)
            $scriptDir/support/usage.sh
            err_exit "Invalid Option ${v}" >&2
            ;;
        esac
        idx=$((idx + 1))
        v="${arr[${idx}]}"
    done
}
# Error reporting functions
function err() {
    echo >&2 "[ERROR] $1"
}
function err_exit() {
    echo >&2 "[ERROR] $1"
    exit 1
}

# Parse CLI parameters
while [ "${1-}" != "" ]; do
    case $1 in
    # Supported parameters for cloudctl & direct script invocation
    --casePath | -c)
        shift
        casePath="${1}"
        ;;
    --caseJsonFile)
        shift
        caseJsonFile="${1}"
        ;;
    --inventory | -e)
        shift
        inventory="${1}"
        ;;
    --action | -a)
        shift
        action="${1}"
        ;;
    --namespace | -n)
        shift
        export namespace="${1}"
        ;;
    --instance | -i)
        shift
        instance="${1}"
        ;;
    --args | -r)
        shift
        parse_dynamic_args "${1}"
        ;;
    # Additional supported parameters for direct script invocation ONLY
    --help)
        $scriptDir/support/usage.sh
        exit
        ;;
    --debug)
        set -x
        ;;

    *)
        echo "Invalid Option ${1}" >&2
        exit 1
        ;;
    esac
    shift
done

function setup_namespace() {
 local name=$1
 local install_type=$2
 check_ns=$($kubernetesCLI get namespace "$name" 2>/dev/null | awk '{print $1}')
 if [[ "X$check_ns" != "X" ]]; then
    echo "INFO - Found namespace $name"
 else
    if [[ $install_type != "-clean-install" ]]; then
        err_exit "Unable to retrieve namespace $name"
    else
       if ! $kubernetesCLI create namespace "$name" 2>/dev/null; then
        err_exit "Failed to create namespace $name"
       fi
    fi
 fi
  $kubernetesCLI project "$name"  >/dev/null 2>&1

}

function verify_registry() {
     local reg="$1"
     local user="$2"
     local pass="$3"
     local cli="docker"
     echo "INFO - Verifying registry credentials"

    if [[  $user != "demo" && $pass != "demo" ]]; then

      echo $cli
      $cli login -u "$user" -p "$pass" "$reg" >/dev/null 2>&1
      if [ $? -ne 0 ]; then 
         err_exit " Registry validation failed"
      else
         echo "Registry validation complete" 
      fi
   fi 
  }

function check_kube_connection() {
    # Check if default oc CLI is available and if not fall back to kubectl
    command -v $kubernetesCLI >/dev/null 2>&1 || { kubernetesCLI="kubectl"; }
    command -v $kubernetesCLI >/dev/null 2>&1 || { err_exit "No kubernetes cli found - tried oc and kubectl";}

    # Query apiservices to verify connectivity
    if ! $kubernetesCLI get apiservices >/dev/null 2>&1; then
        err_exit "Verify that $kubernetesCLI is installed and you are connected to a Kubernetes cluster."
    fi

}
function run(){
    cm=$1
    message=$2
    bash $cm
    status=$?
    if [ $status -ne 0 ]; then err_exit "$message has failed";fi
}
function check_helm() {
  local binary="$1"
  local alias="$2"
  local version="$3"
  local flags="$4"

  if [ "X$binary" == "X" ]; then
     binary=$(which "$alias")
     if [ "X$binary" == "X" ]; then
        binary=$(which helm)
     fi
  fi

  if [ "X$binary" == "X" ]; then
      err_exit "$alias is not set"
  fi

  vcheck=$($binary version $flags 2>/dev/null)
  if [ "X$vcheck" == "X" ]; then
      err_exit "$binary has incorrect version"
  fi
  echo "$binary"
}

function set_domain() {
   if [ ! -z "${domain}" ]; then
     return
   fi
   if [[ "${cloudType}" != "ibmcloud" && $cloudType != "aws" ]]; then
        err_exit "The application domain was not specified in values.conf."
    fi
   domain="cp4s.$(oc get -n openshift-console route console -o jsonpath="{.spec.host}" | sed -e 's/^[^\.]*\.//')"
   if [ "$domain" == "cp4s." ]; then
      err_exit "Failed to discover domain"
   fi
}

function checkStorage() {
  sc="$1"
  SetDefault="$2"
  
  check_storage=$($kubernetesCLI get sc | grep "$sc"| awk '{print $1;exit;}')  
       
    
  if [ "X$check_storage" == "X" ]; then
          available_storage=$($kubernetesCLI get sc | awk '{print $1}')
          err "Storage class $sc not found"
          echo "################################"
          err "Select from available storage"
          echo "###############################"
          err_exit "$available_storage"
  fi
  
  if [ $SetDefault -eq 1 ]; then
          $kubernetesCLI  patch storageclass $check_storage  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
  fi
}

function check_cli_args() {
    # Verify required parameters were specifed and are valid (including environment setup)
    # - case path
    [[ -z "${casePath}" ]] && { err_exit "The case path parameter was not specified."; }
    if [[ $action != *"Connector"* ]]; then
        [[ -z "${inputcasedir}" ]] && { err_exit "The extract case path was not specified."; }
    fi
    if ! ls "${casePath}"  >/dev/null ; then
        err_exit "Failed to find case dir."
    fi
    export chartsDir="${inputcasedir}/charts"
    untar_chart(){
        local chart=$1
        if [[ $chart == "foundations" ]]; then
           foundations=$(ls "${chartsDir}"/ibm-security-foundations-prod-*)
           if ! tar -xvf "$foundations" -C "${chartsDir}" >/dev/null 2>&1; then 
              err_exit "Failed to extract $foundations_release_name chart"; 
            fi
        elif [[ $chart == "solutions" ]]; then
             solutions=$(ls "${chartsDir}"/ibm-security-solutions-prod-*)
             if ! tar -xvf "$solutions" -C  "${chartsDir}" >/dev/null 2>&1 ; then 
               err_exit "Failed to extract $solutions_release_name"; 
             fi
       fi
 }
    ## check config file
    validate_file_exists "$configFile"
    source "$configFile"
    # - set parameters
    entitledRegistry="$entitledRegistryUrl"
    entitledPass="$entitledRegistryPassword"
    entitledUser="$entitledRegistryUsername"
    localUsername="$localDockerRegistryUsername"
    localPassword="$localDockerRegistryPassword"
    localRegistry="$localDockerRegistry"
    certFile="$cp4sdomainCertificatePath"
    keyFile="$cp4sdomainCertificateKeyPath"
    customCA="$cp4scustomcaFilepath"
    openshiftAuth="$cp4sOpenshiftAuthentication"
    cloudType="$cloudType"
    domain="$cp4sapplicationDomain"
    storage="$storageClass"
    sharedStorage="$fileStorageClass"
    repositoryType="$registryType"
    userId="$adminUserId"
    defaultAccount="$defaultAccountName"
    securityAdvisor="$enableCloudSecurityAdvisor"
    fsGroup="$storageClassFsGroup"
    supplementalGroups="$storageClassSupplementalGroups"
    backupStorage="$backupStorageClass"
    backupStorageSize="$backupStorageSize"
    imagepullPolicy="$cp4simagePullPolicy"
    deleteDelayDays="$accountDeleteDelayDays"
    # Verify namespace
    [[ -z "${namespace}" ]] && { err_exit "The namespace parameter was not specified."; }
    
    if [ "X$openshiftAuth" != "Xtrue" ]; then
       openshiftAuth="false"
    else
        if [ "$cloudType" != "ibmcloud" ]; then
            err_exit "OpenShift Authentication is only supported for ROKS clusters."
        fi
    fi

    if [[ $action == "installServiceability" ]]; then 
        if ! ls "${inputcasedir}/charts" | grep -Eo "ibm-.*.tgz" >/dev/null  2>&1; then
             err_exit "No charts .tgz in the root of the specified case directory path."

        fi
        ## Untar the charts
         untar_chart "foundations"
         untar_chart "solutions"
    fi

    if [[ $action == "installFoundations" ]] || [[ $action == "installSolutions" ]] || [[ $action == "install" ]] || [[ $action == "upgradeAll" ]] || [[ $action == "upgradeFoundations" ]] || [[ $action == "upgradeSolutions" ]] || [[ $action == "validate" ]] || [[ $action == "upgradeCommonServices" ]] || [[ $action == "postUpgrade" ]]; then 
        ### check for license only when actions is set
        if [[ -z  "${license}" ]] || [[ "${license}" != "accept" ]]; then
            err_exit "license not accepted, please read license in ibm-cp-security/licenses directory and accept by adding --license accept as part of the install args"
        fi
        
        if  [[ -z "$helm_3" ]]; then
          err_exit "Path to helm3 binary not set"
        fi

        # Check helm binary
        check_helm "$helm_3" "helm3" 'Version:"v3.2'
        export helm3="$helm_3"
        
        if ! ls "${inputcasedir}/charts" | grep -Eo "ibm-.*.tgz" >/dev/null  2>&1; then
             err_exit "No charts .tgz in the root of the specified case directory path."

        fi
        ## Untar the charts
         untar_chart "foundations"
         untar_chart "solutions"
         
        case "X$imagepullPolicy" in
          X|XIfNotPresent) 
             pullPolicy="--set global.imagePullPolicy=IfNotPresent"
             ;;
          XAlways)         
             pullPolicy="--set global.imagePullPolicy=Always"
             ;;
          *) echo "Warning - Unknown imagepullPolicy $imagepullPolicy set in values.conf, installation will be done using default value IfNotPresent"
             pullPolicy="--set global.imagePullPolicy=IfNotPresent"
             ;;
        esac

        if [[ $cloudType != "aws" && $cloudType != "ibmcloud" && $cloudType != "azure" && $cloudType != "ocp" ]]; then
           ## set default cloudtype
           echo "Warning - Unknown cloudtype $cloudType set in values.conf, installation will be done using default value ocp"
           cloudType="ocp"
        fi

               
        ##check if deploying security advisor
        if [[ "$securityAdvisor" == "true" ]]; then
            enableAdapter="--set global.ibm-isc-csaadapter-prod.enabled=true"
        fi

        ## check storagefs group
        if [[ -n $fsGroup ]]; then
           setfsGroup="--set global.postgres.cases.installOptions.primary.fsGroup=$fsGroup"
           setbackrestGroup="--set global.postgres.cases.installOptions.backrest.fsGroup=$fsGroup"
        fi
        if [[ -n $supplementalGroups ]]; then
           setsupGroup="--set global.postgres.cases.installOptions.primary.supplementalGroups=$supplementalGroups"
           setbackrestsupGroup="--set global.postgres.cases.installOptions.backrest.supplementalGroups=$supplementalGroups"
        fi

        if [[  -n $backupStorage ]];then 
            which_storage=$($kubernetesCLI get sc | grep "$backupStorage" | awk '{print $1;exit;}')  
            [[ -z "${which_storage}" ]] && { err_exit "The backup storage class specified was not found ."; }
            setbackupStorage="--set global.backup.storageClass=$backupStorage"
        fi

        if [[ -n $backupStorageSize ]]; then
            setbackupSize="--set global.backup.size=$backupStorageSize"
        fi
        if [[ -n $deleteDelayDays ]]; then
            setdeletedelaydays="--set global.accountDeleteDelayDays=$deleteDelayDays"
        fi
        ### Check FQDN
        if [[ $action != *"Foundations"* ]]; then
           if [ -z "$domain" ]; then
             set_domain
             DOMAIN_SET=1
           elif [[ ! ${domain} =~ ^([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9])(.([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]))*$ ]]; then
                 err_exit "The application domain in values.conf is invalid."
                # validating certificates - required for when domain is set
                if [[ -z "${certFile}" ]] || [[ -z "${keyFile}" ]]; then
                    err_exit "Certificate and certificate key must be provided for the selected domain"
                fi             
           fi  
        fi
        
        [[ -z $userId ]] && { err_exit "An Admin userid was not specified in values.conf";}
        
        #### Check storage
       [[ -z $storage ]] && { err_exit "The storage class parameter was not specified in values.conf."; } 
    #    [[ -z $sharedStorage ]] && { err_exit "The file storage class parameter was not specified in values.conf."; } 

        ### Check Certificates
        if [ ! -z ${certFile} ]; then
            validate_file_exists "${certFile}"
        fi
        if [ ! -z ${keyFile} ]; then
           validate_file_exists "${keyFile}"
        fi
       
       ### Set default repositorytype if value is not set 
       if [[ $repositoryType != "entitled" && $repositoryType != "local" ]]; then 
            echo "Warning - Unknown repositoryType $repositoryType set in values.conf, installation will be done using default value entitled"
            repositoryType="entitled"
        fi

       checkStorage "$storageClass" 1
    #    checkStorage "$fileStorageClass" 0

        dsc=""
        for cl in $( $kubernetesCLI get storageclass -o name)
        do 
         def=$($kubernetesCLI get "$cl" -o jsonpath="{.metadata.annotations['storageclass\.kubernetes\.io/is-default-class']}")
         if [ "X$def" != "Xtrue" ]; then 
             continue
         fi
         if [ "X$dsc" != "X" ]; then
             err_exit "More than one default storage class: $dsc and $cl"
         fi
         dsc="$cl"
        done
    elif [[ $action == "uninstall" ]] || [[  $action == "uninstallFoundations" ]] || [[ $action == "uninstallSolutions"  ]]; then
        
       if  [[ -z "$helm_3" ]]; then
          err_exit "Path to helm3 binary not set"
       fi
       
        # Check helm binary
        check_helm "$helm_3" "helm3" 'Version:"v3.2'
        export helm3="$helm_3"
     
        if ! ls "${inputcasedir}/charts" | grep -Eo "ibm-.*.tgz" >/dev/null  2>&1; then
             err_exit "No charts .tgz in the root of the specified case directory path parameter."
        fi
        ## Untar the charts
        untar_chart "foundations"
        untar_chart "solutions"
    elif [[ $action == "deployConnector" ]]; then
        if [ "X$connectorImage" == "X" ]; then
            err_exit "--image must be specified with '--args' parameter"
        fi
        if [ "X$connectorType" == "X" ]; then
            err_exit "--type must be specified with '--args' parameter"
        fi
    elif [[ $action == "restoreConnectors" ]]; then
        if [ "X$inputcasedir" == "X" ]; then
            err_exit "--inputDir must be specified with '--args' parameter"
        fi
        if [ ! -d $inputcasedir ]; then
            err_exit "'inputDir' does not exist"
        fi
    elif [[ $action == "getConnector" ]] || [[ $action == "deleteConnector" ]]; then
        if [ "X$connectorName" == "X" ]; then
            err_exit "--name must be specified with '--args' parameter"
        fi
    fi
    

    ### Check if airgap install
    if [[ "X${airgapInstall}" != "X" ]]; then 
        if [[  "X${localRegistry}" != "X" ]]; then
           if [[ "${localRegistry}" == "${entitledRegistry}" ]]; then
                err_exit "Entitled registry and local registry cannot be same."
            elif [[ -z "${localUsername}" ]] || [[ -z "${localPassword}" ]]; then
                 err_exit "Local registry credentials not set." 
            else
                repo="$localRegistry"
                chart_url="$localRegistry/cp/cp4s"
                repo_user=$localUsername
                repo_pass=$localPassword
                repositoryType="entitled"

            fi
        else
             err_exit "Local registry creds must be set"
        fi

    elif [[ -z "${entitledRegistry}" ]] || [[ -z "${entitledUser}" ]] || [[ -z "${entitledPass}" ]]; then
       if [[ $action != *"Serviceability"* && $action != *"uninstall"* && $action != *"configureClusterAirgap"* && $action != *"Connector"* ]]; then
          err_exit " Entitled registry credentials was not set in values config file"
        fi
    else 
        ## add cp/cp4s to url when install is using entitled repo
        if [[ $repositoryType == "entitled" ]]; then
           chart_url="$entitledRegistry/cp/cp4s"
        else 
            chart_url="$entitledRegistry"
        fi
        verify_registry "$entitledRegistry" "$entitledUser" "$entitledPass"
        repo="$entitledRegistry"
        repo_user="$entitledUser"
        repo_pass="$entitledPass"
    fi
    # Verify dynamic args are valid (show as any issues on invocation as possible)
    check_kube_connection

}


function validate_configure_cluster_airgap_args() {
    # Verify arguments required to create secret were provided
    local foundError=0
    [[ -z "${registry}" ]] && {
        foundError=1
        err "'--registry' must be specified with the '--args' parameter"
    }

    # Print usage if missing parameter
    [[ $foundError -eq 1 ]] && { 
        run "$scriptDir/support/usage.sh"
        exit 1
    }
}

function validate_file_exists() {
    local file=$1
    [[ ! -f ${file} ]] && { err_exit "${file} not found, exiting deployment."; }
}

# ***** END ARGUMENT CHECKS *****

# ***** ACTIONS *****

# ----- CONFIGURE ACTIONS -----

# Add / update local authentication store with user/password specified (~/.airgap/secrets/<registy>.json)
function configure_creds_airgap() {
    echo "-------------Configuring authentication secret-------------"
    
    "${scriptDir}"/support/airgap.sh registry secret -c -u "${user}" -p "${pass}" "${registry}"
}

# Append secret to Global Cluster Pull Secret (pull-secret in openshif-config)
function configure_cluster_pull_secret() {

    echo "-------------Configuring cluster pullsecret-------------"

    # configure global pull secret if an authentication secret exists on disk
    if "${scriptDir}"/support/airgap.sh registry secret -l | grep "${registry}"; then
        "${scriptDir}"/support/airgap.sh cluster update-pull-secret --registry "${registry}" "${dryRun}"
    else
        echo "Skipping configuring cluster pullsecret: No authentication exists for ${registry}"
    fi
}

function configure_content_image_source_policy() {

    echo "-------------Configuring imagecontentsourcepolicy-------------"

    "${scriptDir}"/support/airgap.sh cluster apply-image-policy \
        --name "${appName}" \
        --dir "${inputcasedir}" \
        --registry "${registry}" "${dryRun}"
}

generate_auth_json() {
    path=$(find $HOME -type d -name ".airgap" 2>/dev/null)
    if [[ -z $path ]]; then
       err_exit "Failed to find path to registry credentials"
    fi
    # path="/root/.airgap"
    echo "[INFO] Generating auth.json"
    printf "{\n  \"auths\": {" > "$path/auth.json"

    if [ -d "$path/secrets" ]; then
        all_registry_auths=
        for secret in $(find "$path/secrets" -name "*.json"); do
            registry_auth=$(cat ${secret} | sed -e "s/^{\"auths\":{//" | sed -e "s/}}$//")
            if [[ "$?" -eq 0 ]]; then
                if [ ! -z "${all_registry_auths}" ]; then
                    printf ",\n    ${registry_auth}" >> "$path/auth.json"
                else
                    printf "\n    ${registry_auth}" >> "$path/auth.json"
                fi
                all_registry_auths="${all_registry_auths},${registry_auth}"
            fi
        done
    else
        err_exit "Failed to get credentials for image mirroring"
    fi

    printf "\n  }\n}\n" >> "$path/auth.json"
}

# Apply ImageContentSourcePolicy required for airgap
function configure_cluster_airgap() {

    echo "-------------Configuring cluster for airgap-------------"

    validate_configure_cluster_airgap_args

    configure_cluster_pull_secret

    if [ "X$inputcasedir" != "X" ]; then
        configure_content_image_source_policy
    fi
    
}

# ----- MIRROR ACTIONS -----

# Mirror required images
function mirror_images() {
    echo "-------------Mirroring images-------------"

    validate_configure_cluster_airgap_args
    runs=0
    while [ $runs -lt 3 ]; do
      "${scriptDir}"/support/airgap.sh image mirror \
        --dir "${inputcasedir}" \
        --to-registry "${registry}" "${dryRun}"
      if [[ "$?" -eq 0 ]]; then
         echo "Mirroring complete"
      fi
     ((runs++))
    done
    ## Retag the Foundational services catalog with latest, to be removed in 1.7.2.0 release
    if ! tar -xf ${inputcasedir}/ibm-cp-common-services-*.tgz -C /tmp/; then
        err_exit "Failed to extract Foundational services bundle"
    fi
    image=$(cat < /tmp/ibm-cp-common-services/inventory/ibmCommonServiceOperatorSetup/files/op-olm/catalog_source.yaml | grep "image:" | awk '{print $2}')
    if [ -z $image ]; then
      err_exit "Failed to fetch Foundational services catalog image"
    else
        generate_auth_json
        oc image mirror $image ${registry}/ibmcom/ibm-common-service-catalog:latest -a $path/auth.json --insecure=true 
    fi

}


function cases_images() {
    echo "-------------Mirroring resilient images-------------"
    validate_file_exists "${cases_images}"
    image_list=()
    if [[ "$dev" -eq 1 ]]; then
          image_entitled_repo="cp.stg.icr.io"
    else
        image_entitled_repo="cp.icr.io"
    fi
    ## merge creds for mirroring
    generate_auth_json
    while read -r line; do

        if [[ $line == *"image:"* ]]; then
            msv="$(echo $line | awk '{print $2}')"
            echo "$msv"
             image_list+=("$msv")
        fi
        if [[ $line == *"tag:"* ]]; then
           tag="$(echo $line | awk '{print $2}')"
        fi
    done < "${cases_images}"
    for image in ${image_list[*]}; do
        if ! oc image mirror $image_entitled_repo/cp/cp4s/solutions/$image:$tag ${registry}/$image:$tag -a $path/auth.json --insecure=true "${dryRun}"; then
         err_exit "Failed to mirror $image"
        fi
    done

}

function list_connectors(){
    $kubernetesCLI get connectors
}

function get_connector(){
    $kubernetesCLI get connector $connectorName -o yaml
}

function deploy_connector(){
    crType=$( echo $connectorType | tr A-Z a-z)
   
    if [[ $crType =~ "udi" ]]; then
        FILE_PREFIX="stix_shifter_modules_"
    elif [[ $crType =~ "car" ]]; then
        FILE_PREFIX="isc-car-connector-"
    else
        err_exit "Unknown connector type $crType"
    fi

    imageNameTag=${connectorImage##*/}
    crSpecType=$( echo $connectorType | tr a-z A-Z)
    crName=$imageNameTag
    crName=${crName:${#FILE_PREFIX}}
    crName=${crName%%:*}
    crModuleName=${crName//_/-}
    crVersion=$imageNameTag
    crVersion=${crVersion:${#FILE_PREFIX}}
    crVersion=${crVersion:${#crName}+1}

    if [ "X${registry}" != "X" ]; then
        ## merge creds for mirroring
        generate_auth_json
        crImage=${registry}/${imageNameTag}
        if ! oc image mirror $connectorImage ${registry}/${imageNameTag} -a $path/auth.json --insecure=true "${dryRun}"; then
            err_exit "Failed to mirror $image"
        fi
    else
        crImage=$connectorImage
    fi

    # Prepare new connector CR yaml
    local cr="${casePath}"/inventory/installProduct/files/connectors/connector-cr.yaml
    preparedCr=$(sed <"$cr" "s|REPLACE_NAMESPACE|${namespace}|g; s|REPLACE_TYPE|$crType|g; s|REPLACE_SPEC_TYPE|$crSpecType|g; s|REPLACE_MODULE|$crModuleName|g; s|REPLACE_VERSION|$crVersion|g; s|REPLACE_IMAGE|$crImage|g;")
    echo ""
    echo "${preparedCr}"
    echo ""

    # Backup existing old connector CR
    timestamp=`date '+%Y%m%d%H%M%S'`
    backupDir=/tmp/cp4s/connector_backup_${timestamp}/
    mkdir -p $backupDir
    echo "Backing up current connectors state..."
    $kubernetesCLI get connector --no-headers -o=custom-columns=NAME:.metadata.name | xargs -I{} -n 1 bash -c "${kubernetesCLI} get connector {} -o yaml > ${backupDir}{}.yaml"
    echo "Current connectors state has been backed up, to restore it execute:"
    echo "cloudctl case launch --case ./ibm-cp-security --inventory installProduct --namespace cp4s --action restoreConnectors --args \"--inputDir $backupDir\" -t 1"

    # Replace connector CR
    if ! echo "$preparedCr" | $kubernetesCLI delete -n "${namespace}" -f - ;then 
      echo "Failed to delete Connector CR"
    fi
    echo "Applying CR..."
    if ! echo "$preparedCr" | $kubernetesCLI apply -n "${namespace}" -f - ;then 
      err_exit "Failed to Apply Connector CR"
    fi
}

function delete_connector(){
    $kubernetesCLI delete connector $connectorName
}

function restore_connectors(){
    echo "Restoring connectors.."
    $kubernetesCLI get connector --no-headers -o=custom-columns=NAME:.metadata.name | xargs $kubernetesCLI delete connector
    ls -1 ${inputcasedir}/*.yaml | xargs -n 1 kubectl apply -f
}

## Run Cases CR

function deploy_cases(){

    local cr="${casePath}"/inventory/installProduct/files/cases-cr.yaml
    local resource_file="${casePath}"/inventory/ibmSecuritySolutions/resources.yaml
    validate_file_exists "${cases_images}"
    validate_file_exists "$cr"
    validate_file_exists "$resource_file"
    version=$(cat "$resource_file" | grep -E "version:" | awk '{print $2}'| tr -d '""')
    tag=$(cat $cases_images | grep "tag:" | awk '{print $2}')
    regx="4.[3-4].[0-9]*"
    oc_version=$(oc version | grep "Server Version:")
    if [[ $oc_version =~ $regx ]]; then
       storage_class_name=$($kubernetesCLI get cases cases -o yaml  -n "${namespace}" |grep "storage_class_name:" | awk '{print $2 }')
       postgres_image=$($kubernetesCLI get cases cases -o yaml -n "${namespace}" |grep "crunchy_image_tag:" | awk '{print $2 }')
    else
       storage_class_name=$($kubernetesCLI get cases cases -o yaml  -n "${namespace}" |grep "storage_class_name:" | awk 'NR==2{print $2}')
       postgres_image=$($kubernetesCLI get cases cases -o yaml -n "${namespace}" |grep "crunchy_image_tag:" | awk 'NR==2{print $2}')
    fi
    if [[ -z ${airgapInstall}  ]]; then
       repo="${registry}/cp/cp4s/solutions"
    else
       repo="${registry}"
    fi
    check_cases_cr=$($kubernetesCLI get cases cases  -n "${namespace}" 2>/dev/null)

    [[ -z "$check_cases_cr" ]] && { err_exit "Cases CR not found in ${namespace} namespace."; }

    appmanager_image=$($kubernetesCLI get cases cases -o yaml -n "${namespace}" |grep "apps-manager:" | awk 'NR==2{print $2}'| sed 's/.*://')
    if [[ -n $version && -n $storage_class_name && -n $appmanager_image && -n $postgres_image ]]; then
     if ! sed <"$cr" "s|REPLACE_NAMESPACE|${namespace}|g; s|REPLACE_TAG|$tag|g; s|REPLACE_VERSION|$version|g; s|REPLACE_REPOSITORY|$repo|g; s|REPLACE_POSTGRES_IMAGE|$postgres_image|g; s|REPLACE_APP_MANAGER_TAG|$appmanager_image|g; s|REPLACE_STORAGE|$storage_class_name|g" |  $kubernetesCLI apply -n "${namespace}" -f - ;then 
      err_exit "Failed to Update Cases CR"
     fi
    else
       err_exit "Failed to fetch Cases values to apply CR"
    fi
}
## Run chart prereq script
function chart_prereq(){
    local chart=$1
    local maxRetry=4
    local param=""
    if [[ $chart == "solutions" ]]; then
        param="--solutions"
    fi
    for ((retry=0;retry<maxRetry;retry++)); do
      echo "INFO - running prerequisite checks for $chart"
      if bash "${chartsDir}"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/checkprereq.sh -n "${namespace}" $param; then
        return 0
      fi
      sleep 60
    done
    err_exit "$chart prereq check has failed"  
}
### Preinstall for foundations and solutions 
function pre_install() {
 
 local release="$1"
  if [[ $release  == "ibm-security-foundations" ]]; then
     echo "INFO - Running preinstall of $foundations_release_name"
     if [[ $cloudType =~ "ibmcloud" ]]; then
           local flag="-ibmcloud"
      fi
      run "${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n ${namespace} -repo $repo $repo_user $repo_pass -force $flag" "Foundations preinstall"
      echo "INFO - Preinstall of $foundations_release_name complete"
      
      ## run foundations checkprereq.sh
      chart_prereq "foundations"
      
      sudo rm -r /ibm/charts/ibm-security-foundations-prod
      helm3 repo add entitled https://raw.githubusercontent.com/IBM/charts/master/repo/entitled
      cd /ibm/charts
      tar xvf /ibm/charts/ibm-security-foundations-prod-1.0.17.tgz
      cd /ibm
  else
        echo "INFO - Running Preinstall of $solutions_release_name"
        if [ ${DOMAIN_SET} -eq 1 ] ; then
            if [ "X${cloudType}" == "Xaws" ]; then
                cert_flag="-aws"
            else
                cert_flag="-roks"
            fi
           run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n ${namespace} $cert_flag -resources" "Preinstall of $solutions_release_name"
        else
           if [ "X$customCA" != "X" ]; then
              run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n ${namespace} -cert $certFile  -key $keyFile -ca $customCA -force -resources" "Preinstall of $solutions_release_name"
           else
             run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n ${namespace}  -cert $certFile  -key $keyFile -force -resources" "Preinstall of $solutions_release_name"
           fi
        fi
        ## Run solutions checkprereq.sh
        chart_prereq "solutions"
        
        
        echo "INFO - Preinstall of $solutions_release_name complete"
  fi
}
function preupgrade(){
    
    local chart="$1"
    if [[ $chart == "ibm-security-foundations" ]]; then
       chart_prereq "foundations"
       echo "INFO - Running Preupgrade of $chart"
       run "${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-upgrade/preUpgrade.sh -n $namespace" "Preupgrade of $chart"
       ## delete and create pull secret if its an airgap install
       if [[ "X$airgapInstall" != "X" ]]; then
          set_custom_secrets ibm-isc-pull-secret "$repo" "$repo_user" "$repo_pass"
       fi
    
    elif [[ $chart == "ibm-security-solutions" ]]; then
        chart_prereq "solutions"
        echo "INFO - Running Preupgrade of $chart"
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-upgrade/preUpgrade.sh -n $namespace" "Preupgrade of $chart"

    fi

}

function check_cs_version() {
    
    # CS_VERSION="$( cat $casePath/inventory/ibmCommonServiceOperatorSetup/resources.yaml |  grep -A 1 'displayName: common-service-operator' | grep tag | awk '{print $2;}')"
    CS_VERSION="3.7.4"
    echo "INFO - Checking if Foundational Services is already installed"

    CURRENT_CS_VERSION=$($kubernetesCLI get csv -n $CS_NAMESPACE --ignore-not-found=true | grep ibm-common-service | awk '{print $7;}') 
    CS_HOST=$($kubernetesCLI get route --no-headers -n "$CS_NAMESPACE" --ignore-not-found=true | grep "cp-console" | awk '{print $2}')  
    CS_PASS=$($kubernetesCLI -n "$CS_NAMESPACE" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' 2>/dev/null | base64 --decode)
    CS_USER=$($kubernetesCLI -n "$CS_NAMESPACE" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' 2>/dev/null | base64 --decode)
    cs_version_check="false"

    if [[ "${CURRENT_CS_VERSION}" == "${CS_VERSION}" ]] || [[ "${CURRENT_CS_VERSION}" > "${CS_VERSION}" ]]; then
        echo "Foundational Services $CURRENT_CS_VERSION is already installed"
        if ! cloudctl login -a "$CS_HOST" -u "$CS_USER" -p "$CS_PASS" -n "$CS_NAMESPACE" --skip-ssl-validation; then 
            echo "Foundational services login isn't working"
            echo "Reinstalling Foundational services"
            cs_version_check="true"
        fi
    else 
        cs_version_check="true"
    fi
    
}

function check_charts_version() {
    local flag="$1"
    CP4S_VERSION="$( cat $casePath/case.yaml  | grep appVersion | awk '{print $2;}' | sed -r 's/"//g' | sed -r 's/-/./g' )"
    foundations_version_check=""
    solutions_version_check=""

    if [[ $flag == "foundations" ]]; then

        echo "Checking if Foundations $CP4S_VERSION is already installed"

        CURRENT_FOUNDATIONS_VERSION=$(${helm3} ls --namespace $namespace | grep foundations | awk '{print $10;}'| sed -r 's/-/./g')
        CURRENT_FOUNDATIONS_STATUS=$(${helm3} ls --namespace $namespace | grep foundations | awk '{print $8;}')
        if [[ "${forceInstall}" == "true" ]]; then
            foundations_version_check="true"
        else
            if [[ "${CURRENT_FOUNDATIONS_VERSION}" == "${CP4S_VERSION}" ]]; then
                echo "$foundations_release_name $CP4S_VERSION is already installed"
                if [[ "${CURRENT_FOUNDATIONS_STATUS}" == "deployed" ]]; then
                    echo "Foundations chart is deployed successfully."
                    foundations_version_check="false"
                else 
                    echo "Foundations chart install failed, reinstalling."
                    foundations_version_check="true"
                fi
            else 
                echo "Uninstalling existing version of Foundations Chart"
                foundations_version_check="true"
            fi
        fi
    else
        echo "Checking if Solutions $CP4S_VERSION is already installed"

        CURRENT_SOLUTIONS_VERSION=$(${helm3} ls --namespace $namespace | grep solutions | awk '{print $10;}'| sed -r 's/-/./g') 
        CURRENT_SOLUTIONS_STATUS=$(${helm3} ls --namespace $namespace | grep solutions | awk '{print $8;}')
       if [[ "${forceInstall}" == "true" ]]; then
            solutions_version_check="true"
        else

           if [[ "${CURRENT_SOLUTIONS_VERSION}" == "${CP4S_VERSION}" ]]; then
               echo "$solutions_release_name $CP4S_VERSION is already installed"
               if [[ "${CURRENT_SOLUTIONS_STATUS}" == "deployed" ]]; then
                   echo "Solutions chart is deployed successfully."
                   solutions_version_check="false"
                else 
                   echo "Solutions chart install failed, reinstalling."
                   solutions_version_check="true"
                fi
            else 
                echo "Uninstalling existing version of Solutions Chart"
                solutions_version_check="true"
            fi
        fi
    fi
    
}

function check_couch_version() {
    
    couch_version_check=""

    echo "Checking if CouchDB Operator is already installed"

    CURRENT_COUCHDB_VERSION=$($kubernetesCLI get csv -n $namespace | grep couchdb | awk '{print $6;}') 
    if [[ "${forceInstall}" == "true" ]]; then
            couch_version_check="true"
    else  
        if [[ "${CURRENT_COUCHDB_VERSION}" == [1-9].[4-9].[1-9] ]]; then
            echo "CouchDB Operator $CURRENT_COUCHDB_VERSION is already installed"
            couch_version_check="false"
        else 
            couch_version_check="true"
        fi
    fi
}

function check_redis_version() {
    redis_version_check=""

    echo "Checking if Redis Operator is already installed"

    CURRENT_REDIS_VERSION=$($kubernetesCLI get csv -n $namespace | grep redis | awk '{print $6;}') 
    if [[ "${forceInstall}" == "true" ]]; then
            redis_version_check="true"
    else 
        if [[ "${CURRENT_REDIS_VERSION}" == [1-9].[2-9].[2-9] ]]; then
            redis_version_check="false"
            echo "Redis Operator $CURRENT_REDIS_VERSION is already installed"
        else
            redis_version_check="true"
        fi
    fi
}
## Install of solutions and foundations chart
function install_charts(){
    local chart=$1
    

    if [[ $chart == "ibm-security-foundations" ]]; then
        check_charts_version "foundations"
        if [[ "$foundations_version_check" == "true" ]]; then
            isPresent=$(${helm3} ls --namespace "$namespace" | grep "$foundations_release_name" | awk '{print $1;exit;}')
            if [[ "X$isPresent" != "X" ]]; then preupgrade "$foundations_release_name"
            else
                pre_install "$foundations_release_name"
            fi
            echo "INFO - Installing CP4S $foundations_release_name Chart"
     
            if ! ${helm3} upgrade --install "$foundations_release_name" --namespace="$namespace" --set global.cloudType="${cloudType}" --set global.repositoryType="${repositoryType}" --set global.repository="${chart_url}" $pullPolicy --set global.license="$license" --values "${chartsDir}"/ibm-security-foundations-prod/values.yaml "${chartsDir}"/ibm-security-foundations-prod  --timeout 1000s --reset-values; then
                err_exit "$foundations_release_name installations has failed"
            fi
            ## Give time for pods to run before checking
            sleep 5
        fi
    else
        check_charts_version "solutions"
        if [[ "$solutions_version_check" == "true" ]]; then
            isPresent=$(${helm3} ls --namespace "$namespace" | grep "$solutions_release_name" | awk '{print $1;exit;}' )
            if [[ "X$isPresent" != "X" ]]; then 
       
                preupgrade "$solutions_release_name"; 
            else 
                pre_install "$solutions_release_name"   
            fi

            echo "INFO - Installing CP4S $solutions_release_name Chart"
         
    
            if ! $helm3 upgrade --install "$solutions_release_name" --namespace="${namespace}" --set global.repositoryType="${repositoryType}" --set global.repository="${chart_url}" --set global.cluster.icphostname="$CS_HOST" $setbackupStorage $setbackupSize $enableAdapter $setbackrestGroup $setbackrestsupGroup $setfsGroup $setsupGroup $pullPolicy $setdeletedelaydays --set global.csNamespace="$CS_NAMESPACE" --set global.storageClass="$storageClass"  --set global.license="$license"  --set global.adminUserId="${userId}" --set global.defaultAccountName="${defaultAccount}" --set global.domain.default.domain="${domain}" --set global.roks="${openshiftAuth}" --values "${chartsDir}"/ibm-security-solutions-prod/values.yaml "${chartsDir}"/ibm-security-solutions-prod --timeout 1000s --reset-values; then 
                err_exit "$solutions_release_name installation has Failed"
            fi
    
            sleep 10
        fi
    fi
  }

function loginCS() {
    local maxRetry=5

    CS_HOST=$($kubernetesCLI get route --no-headers -n "$CS_NAMESPACE" | grep "cp-console" | awk '{print $2}')

    if [[ -z $CS_HOST ]]; then
        for ((retry=0;retry<=${maxRetry};retry++)); 
        do
            $kubernetesCLI delete pod -l name=ibm-management-ingress-operator -n $CS_NAMESPACE
            echo "INFO - Waiting for Management Ingress and Common Web UI pods to start running"
            $kubernetesCLI wait --for=condition=Ready pod -l name=ibm-management-ingress-operator -n $CS_NAMESPACE --timeout=60s >/dev/null 2>&1
            $kubernetesCLI wait --for=condition=Ready pod -l app.kubernetes.io/name=common-web-ui -n $CS_NAMESPACE --timeout=120s >/dev/null 2>&1
            $kubernetesCLI wait --for=condition=Ready pod -l app.kubernetes.io/name=management-ingress -n $CS_NAMESPACE --timeout=60s >/dev/null 2>&1
            CS_HOST=$($kubernetesCLI get route --no-headers -n "$CS_NAMESPACE" | grep "cp-console" | awk '{print $2}')
            if [[ -z $CS_HOST ]]; then
                if [[ $retry -eq ${maxRetry} ]]; then 
                    err_exit "Failed to retrieve Foundational Services cp-console route"
                else
                    sleep 60
                    continue
                fi
            else
                break
            fi
        done
    fi

    CS_PASS=$($kubernetesCLI -n "$CS_NAMESPACE" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode)
    CS_USER=$($kubernetesCLI -n "$CS_NAMESPACE" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode)
    if ! cloudctl login -a "$CS_HOST" -u "$CS_USER" -p "$CS_PASS" -n "$namespace" --skip-ssl-validation; then 
      err_exit "Failure on Foundational Services Login. Exiting."
    fi 
}

function apply_online_catalog (){
    local inventoryOfcatalog="installProduct"

    local generic_catalog_source="${casePath}"/inventory/"${inventoryOfcatalog}"/files/olm/catalog_source.yaml

    validate_file_exists "$generic_catalog_source"

    if $kubernetesCLI get catalogsource -n openshift-marketplace | grep ibm-operator-catalog; then
        echo "Found ibm operator catalog source"
        
    else
        if ! $kubernetesCLI apply -f "$generic_catalog_source" ; then
            err_exit "Generic Operator catalog source creation failed"
        fi
        echo "ibm operator catalog source created"
        

    fi

}

function install_cs(){  

    check_cs_version
    if [[ "$cs_version_check" == "true" ]]; then
        local cs_install_file="${casePath}"/inventory/ibmcloudEnablement/files/install/cs.sh
        if [ "X$airgapInstall" != "X" ]; then
            run "$cs_install_file -cp4sns $namespace ${inputcasedir} -airgap $repo" "Foundational Services Install"
        else
            run "$cs_install_file -cp4sns $namespace ${inputcasedir}" "Foundational Services Install"
        fi
    fi
}

function post_upgrade(){
    local chart=$1
    local old_solutions_version=$2
    if [[ "$old_solutions_version" =~ "1.5.0" ]] || [[ -z "$old_solutions_version" ]]; then
        echo "INFO - Initiating post-upgrade..."
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $namespace -helm3 ${helm3}" "Post upgrade of $chart"
        # cleanup run
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $namespace -helm3 ${helm3} -cleanup" "Post upgrade cleanup of $chart"
    else
        echo "INFO - skipping postupgrade..."
    fi
}

function upgrade_charts(){
  export TILLER_NAMESPACE="${CS_NAMESPACE}"
  local chart="$1"
  local force=""
  local existing_release_name=""
  ## Fetch existing release name
  existing_release_name=$(${helm3} ls --namespace "$namespace" | grep "$chart" | awk '{print $1;exit;}' 2>/dev/null)
  if [[ $chart == "ibm-security-foundations" ]]; then
     ### Check if previous version of cp4s is installed
     if [[ -n "$existing_release_name" ]]; then
        foundations_release_name=$existing_release_name
     fi
        
     isPresen=$(${helm3} status --namespace "$namespace" "$foundations_release_name"| grep -m1 "STATUS" 2>/dev/null) 
     if [ -z "$isPresen" ]; then
           echo "No current version of $foundations_release_name found"
           force="--force" 
     elif [[ "$isPresen" =~ "failed" ]]; then
          err_exit "$foundations_release_name helm3 has a failed release,please contact your administrator"
    elif [[ "$isPresen" =~ "deployed" ]]; then
         deployed_version=$(${helm3} ls --namespace="$namespace" | grep "$chart" | awk '{print $NF}')
         echo "Found deployed $deployed_version version of $foundations_release_name"
          
     fi

     # Call the preUpgrade script
     preupgrade "$chart"

     echo "INFO - Installing CP4S $foundations_release_name Chart"
     
     if ! ${helm3} upgrade --install "$foundations_release_name" --namespace="$namespace" --set global.cloudType="${cloudType}" --set global.repositoryType=${repositoryType} $pullPolicy --set global.repository="${chart_url}" --set global.license="$license" --set global.helmUser="${CS_USER}" --values "${chartsDir}"/ibm-security-foundations-prod/values.yaml "${chartsDir}"/ibm-security-foundations-prod --reset-values $force --timeout 1000s; then
        err_exit "$foundations_release_name upgrade has failed"
     fi
    elif [ "$chart" == "ibm-security-solutions" ]; then
         if [[ -n "$existing_release_name" ]]; then
             solutions_release_name=$existing_release_name
         fi     
        isPresen=$(${helm3} status --namespace "$namespace" "$solutions_release_name" | grep -m1 "STATUS" 2>/dev/null)  
        if [ -z "$isPresen" ]; then
           echo "No current version of $solutions_release_name found"
           force="--force" 
        elif [[ "$isPresen" =~ "failed" ]]; then
            err_exit "$solutions_release_name helm3 has a failed release,please contact your administrator"
        elif [[ "$isPresen" =~ "deployed" ]]; then
            deployed_version=$(${helm3} ls --namespace="$namespace" | grep "$chart" | awk '{print $NF}')
            echo "Found deployed $deployed_version version of $solutions_release_name"
        fi
        
        # Call the preUpgrade script
        preupgrade "$chart"
        
        echo "INFO - Installing CP4S $solutions_release_name Chart"
           
        if ! ${helm3} upgrade --install "$solutions_release_name" --namespace="${namespace}" --set global.repositoryType="${repositoryType}" --set global.repository="${chart_url}" $setbackupStorage $setbackupSize $enableAdapter $setbackrestGroup $setbackrestsupGroup $setfsGroup $setsupGroup $pullPolicy $setdeletedelaydays --set global.cluster.icphostname="$CS_HOST" --set global.csNamespace="$CS_NAMESPACE" --set global.storageClass="$storageClass" --set global.adminUserId="${userId}" --set global.license="$license" --set global.domain.default.domain="${domain}" --set global.roks="${openshiftAuth}" --values "${chartsDir}"/ibm-security-solutions-prod/values.yaml "${chartsDir}"/ibm-security-solutions-prod --reset-values $force --timeout 1000s; then
          err_exit "$solutions_release_name upgrade has failed"
        fi
        sleep 5
    fi
}

function upgrade_cs(){
    echo "INFO - initiating upgrade of Foundational services"
    local upgrade_file="${casePath}"/inventory/ibmcloudEnablement/files/install/csUpgrade.sh     

    if [ "X$airgapInstall" != "X" ]; then
        run "$upgrade_file -cp4sns $namespace ${inputcasedir} -airgap $repo" "Foundational Services Upgrade"
    else
        run "$upgrade_file -cp4sns $namespace ${inputcasedir}" "Foundational Services Upgrade"
    fi    
}

function set_custom_secrets() {
  local secret="$1"
  local reg="$2"
  local user="$3"
  local pass="$4"
 
  secretexist=$($kubernetesCLI get secret "$secret" -n "${namespace}" --no-headers | awk '{print $1}' 2>/dev/null)
  if [ "X$secretexist" != "X" ]; then
     err "$secret already exist, It will be deleted and recreated"
     
     $kubernetesCLI delete secret "$secretexist" -n "${namespace}" 2>/dev/null
  fi
  if ! $kubernetesCLI create secret docker-registry "$secret" -n "${namespace}" \
  "--docker-server=$reg" "--docker-username=$user" \
  "--docker-password=$pass"; then 
   err_exit "Failed to create secret $secret."
  fi
  if ! $kubernetesCLI patch secret "$secret" -n "${namespace}" --type merge --patch \
     '{"metadata":{"labels":{"app.kubernetes.io/instance":"isc-security-foundations","app.kubernetes.io/managed-by":"isc-security-foundations","app.kubernetes.io/name":"'$secret'"}}}'; then
     err "Failed to patch $secret."
  fi 
}
## Temporary workaround to restart certified and community operators to have latest of couchdboperator
restart_community_operators(){
    local maxRetry=10
    cert_filter="-lolm.catalogSource=certified-operators"
    comm_filter="-lolm.catalogSource=community-operators"
    if [ "X$airgapInstall" == "X" ]; then
       echo "INFO - Restarting certified and community operator pod "

       cert_op=$($kubernetesCLI get pod $cert_filter -n openshift-marketplace --no-headers 2>/dev/null)
       comm_op=$($kubernetesCLI get pod $comm_filter -n openshift-marketplace --no-headers 2>/dev/null)
       if [[ "X$cert_op" != "X" ]]; then
          if ! $kubernetesCLI delete pod $cert_filter -n openshift-marketplace 2>/dev/null; then
            err "Failed to restart certified-operators pod"
          fi
        fi
        if [[ "X$comm_op" != "X" ]]; then
          if ! $kubernetesCLI delete pod $comm_filter -n openshift-marketplace 2>/dev/null; then
            err "Failed to restart community-operators pod"
          fi
        fi
        if [[ "X$comm_op" != "X" ]]; then
          if ! $kubernetesCLI delete pod $comm_filter -n openshift-marketplace 2>/dev/null; then
            err "Failed to restart community-operators pod"
          fi
        fi
        for ((retry=0;retry<=${maxRetry};retry++)); do   
        
        echo "INFO - Waiting for Community and certified operators pod initialization"         
        
        iscertReady=$($kubernetesCLI get pod $cert_filter -n openshift-marketplace --no-headers 2>/dev/null | awk '{print $3}' | grep "Running")

        iscommReady=$($kubernetesCLI get pod $comm_filter -n openshift-marketplace --no-headers 2>/dev/null | awk '{print $3}' | grep "Running")
        
        if [[ "${iscertReady}${iscommReady}" != "RunningRunning" ]]; then
            if [[ $retry -eq ${maxRetry} ]]; then 
              err_exit "Timeout Waiting for certified-operators and community operators to start"
            else
              sleep 30
              continue
            fi
        else
            echo "INFO - certified-operators and community operators are running"
            break
        fi
        done 
   fi


}
function install_couchdb() {
    local inventoryOfOperator="couchdbOperatorSetup"
    local online_source="certified-operators"
    local offline_source="couchdb-operator-catalog"
    local sub="couchdb-operator-catalog-subscription"
    local couch_case="${inputcasedir}/ibm-couchdb-1.0.8.tgz"
    local channelName="v1.4"
    local catsrc_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/catalog_source.yaml
    local sub_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/subscription.yaml
    local operator_group="${casePath}"/inventory/"${inventoryOfOperator}"/files/operator_group.yaml
    validate_file_exists "$operator_group"
    validate_file_exists "$couch_case"

    check_couch_version

    if [[ "$couch_version_check" == "true" ]]; then

        echo "-------------Installing couchDB operator via OLM-------------"

        if [[ $($kubernetesCLI get og -n "${namespace}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
            echo "Found operator group"
            $kubernetesCLI get og -n "${namespace}" -o yaml
    
        else

            if ! sed <"${casePath}"/inventory/"${inventoryOfOperator}"/files/operator_group.yaml "s|REPLACE_NAMESPACE|${namespace}|g" |  $kubernetesCLI apply -n "${namespace}" -f -; then
                err_exit "CP4S Operator Group creation failed"
        
            else
                echo "CP4S Operator Group Created"
            fi
        fi

        if [ "X$airgapInstall" != "X" ]; then
            reg="${repo}"
            if ! cloudctl case launch --case "$couch_case" --inventory couchdbOperatorSetup --namespace "${namespace}" --action installCatalog --args "--registry $reg" --tolerance 1; then     
                err_exit "Couchdb Operator catalog install has failed"
            fi
            if ! cloudctl case launch --case "$couch_case" --inventory couchdbOperatorSetup --namespace "${namespace}" --action installOperator --args "--catalogSource $offline_source --channelName $channelName" --tolerance 1; then 
            err_exit "Couchdb Operator install has failed";
            fi
        else
            apply_online_catalog
            if ! cloudctl case launch --case "$couch_case" --inventory couchdbOperatorSetup --namespace "${namespace}" --action installOperator --args "--catalogSource $online_source --channelName $channelName" --tolerance 1; then 
                err_exit "Couchdb Operator install has failed";
            fi
        fi
    fi

}

function install_redis() {

    local inventoryOfOperator="redisOperator"
    local online_source="ibm-operator-catalog"
    local offline_source="ibm-cloud-databases-redis-operator-catalog"
    local sub="ibm-cloud-databases-redis-operator-subscription"
    local catsrc_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/catalog_source.yaml
    local sub_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/subscription.yaml
    local operator_group="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/operator_group.yaml

    validate_file_exists "$catsrc_file"
    validate_file_exists "$sub_file"
    validate_file_exists "$operator_group"

    check_redis_version
    if [[ "$redis_version_check" == "true" ]]; then
        echo "Installing Redis Operator $REDIS_VERSION"
        if [[ "$dev" -eq 1 ]]; then
            # verify_registry $registry $user $pass
            set_custom_secrets ibm-entitlement-key "$registry" "$user" "$pass"
        else
            set_custom_secrets ibm-entitlement-key "$repo" "$repo_user" "$repo_pass"
        fi
        # create entitlement key based on condition
        # if [[ "$dev" -eq 1 ]]; then
        #     usr=$user
        #     key=$pass
        #     rep=$registry
        # else
        #    usr=$repo_user
        #    key=$repo_pass
        #    rep=$repo
        # fi
        # local redis_case="${inputcasedir}/ibm-cloud-databases-redis-1.1.3.tgz"
        # validate_file_exists $redis_case
        ## handle repository to be used by catalog

        ## check if redis redis subscription exist,delete before applying new sub
        # local isPresent=$($kubernetesCLI get sub "$sub" -n "${namespace}"  --no-headers | awk '{print $4}' 2>/dev/null)
        # if [[ $isPresent == "v1.0" ]]; then
             
        #     if ! $kubernetesCLI delete sub "$sub" -n "${namespace}"; then

        #        err_exit "Failed to delete old redisoperator subscription"
        #     fi
        # fi

        # if [ "X$airgapInstall" != "X" ]; then
        #     reg="$repo"
        #     if ! cloudctl case launch --case "$redis_case" --inventory redisOperator --namespace "${namespace}" --action installCatalog --args "--registry $reg" --tolerance 1; then     
        #       err_exit "Redis Operator catalog install has failed"
        #     fi
        #     if ! cloudctl case launch --case "$redis_case" --inventory redisOperator --namespace "${namespace}" --action installOperator --args "--catalogSource $offline_source" --tolerance 1; then 
        #    err_exit "Redis Operator install has failed";
        #    fi
        # else
        #     reg="$repo"
        #     apply_online_catalog
        #    if ! cloudctl case launch --case "$redis_case" --inventory redisOperator --namespace "${namespace}" --action installOperator --args "--catalogSource $online_source" --tolerance 1; then 
        #    err_exit "Redis Operator install has failed";
        #   fi
        # fi
        # echo "-------------Installing Redis operator via OLM-------------"
        if [ "X$airgapInstall" != "X" ]; then

            local catsrc_image_orig=$(grep "image:" "${catsrc_file}" | awk '{print$2}')
       
        # replace original registry with local registry
            local catsrc_image_mod="${repo}/$(echo "${catsrc_image_orig}" | sed -e "s/[^/]*\///")"
        # apply catalog source
            sed <"${catsrc_file}" "s|${catsrc_image_orig}|${catsrc_image_mod}|g" | $kubernetesCLI apply -f -
        
            sed <"$sub_file" "s|REPLACE_SOURCE|$offline_source|g" | $kubernetesCLI apply -n "${namespace}" -f -

        else
            apply_online_catalog
            if ! sed <"$sub_file" "s|REPLACE_SOURCE|$online_source|g" | $kubernetesCLI apply -n "${namespace}" -f - ; then
                err_exit "Redis Operator Subscription creation failed"
            else
            echo "Redis Operator Subscription Created"
            fi
        fi
    
    
        if [[ $($kubernetesCLI get og -n "${namespace}" -o=go-template --template='{{len .items}}' ) -gt 0 ]]; then
            echo "Found operator group"
            $kubernetesCLI get og -n "${namespace}" -o yaml
    
        else

            if ! sed <"$operator_group" "s|REPLACE_NAMESPACE|${namespace}|g" | $kubernetesCLI apply -n "${namespace}" -f - ;then
                err_exit "CP4S Operator Operator Group creation failed"
            else
                echo "CP4S Operator Group Created"
            fi

        fi
    fi
}
## check what is installed and remove them if they exist
function check_remove(){
    local flag=$1
    CP4S_VERSION="$( cat $casePath/case.yaml  | grep appVersion | awk '{print $2;}' | sed -r 's/"//g' | sed -r 's/-/./g' )"

    if [[ $flag == "solutions" ]]; then
        isPresent=$(${helm3} ls --namespace "$namespace" | grep "$solutions_release_name" | awk '{print $1}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
            echo "INFO - No previous release of $solutions_release_name found"
        else
            check_charts_version "solutions"
            if [[ "${solutions_version_check}" == "true" ]]; then
                echo "Uninstalling existing version of Solutions Chart"
                run "$scriptDir/support/uninstall.sh -uninstall_chart $solutions_release_name" "$solutions_release_name uninstall"
            fi
        fi

    elif [[ $flag == "foundations" ]]; then

        isPresent=$(${helm3} ls --namespace "$namespace" | grep "$foundations_release_name" | awk '{print $1}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
         echo "INFO - No previous release of $foundations_release_name found"
        else
            check_charts_version "foundations"
            if [[ "${foundations_version_check}" == "true" ]]; then
                echo "Uninstalling existing version of Foundations Chart"
                run "$scriptDir/support/uninstall.sh -uninstall_chart $foundations_release_name" "$foundations_release_name uninstall"
            fi
        fi

    elif [[ $flag == "couchdboperator" ]]; then
        isPresent=$($kubernetesCLI get pod -n "$namespace" -lname=couchdb-operator --no-headers | awk '{print $1}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
         echo "INFO - No previous release of couchdboperator found"
        else
            check_couch_version
            if [[ "${couch_version_check}" == "true" ]]; then
                run "$scriptDir/support/uninstall.sh -uninstall_couchdb ${inputcasedir}" "Couchdb operator uninstall"
            fi
        fi

    elif [[ $flag == "redisoperator" ]]; then
        
        isPresent=$($kubernetesCLI get pod -n "$namespace" -lname=ibm-cloud-databases-redis-operator --no-headers | awk '{print $1}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
            echo "INFO - No previous release of redisoperator found"
        else
            check_redis_version
            if [[ "${redis_version_check}" == "true" ]]; then
                run "$scriptDir/support/uninstall.sh -uninstall_redis" "redis operator uninstall"
            fi
        fi

    elif [[ $flag == "commonservices" ]]; then

        if ! $kubernetesCLI get namespace ibm-common-services >/dev/null 2>&1; then
            echo "INFO - Foundational services deployment not found"
        else
            isPresent=$($kubernetesCLI  get cert management-ingress-cert -o jsonpath='{.spec.issuerRef.name}' -n ibm-common-services 2>/dev/null)
            csPods=$($kubernetesCLI  get pod -n ibm-common-services --no-headers 2>/dev/null)
            if [[ -z "$isPresent" ]] || [[ -z "$csPods" ]]; then
                echo "INFO - Foundational services deployment not found"
            else
                check_cs_version
                if [[ "${cs_version_check}" == "true" ]]; then
                    run "$scriptDir/support/uninstall.sh -uninstall_cs case ${inputcasedir} ${repo}" "Foundational Services uninstall"
                fi
           fi

        fi
    fi
}

#===  FUNCTION  ================================================================
#   NAME: solutions_postinstall
#   DESCRIPTION:  executes solution post_install when applicable
# ===============================================================================
function solutions_postinstall() {
    if [ "${openshiftAuth}" == "true" ]; then
        if [ "${solutions_version_check}" == "true" ] || [ $action == "upgradeAll" ] || [ $action == "upgradeSolutions" ]; then
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-install/postInstall.sh -n ${namespace} -roks" "Configuring Openshift Authentication"
        fi
    fi    
}

#===  FUNCTION  ================================================================
#   NAME: install_serviceability
#   DESCRIPTION:  install cp-serviceability pod and its dependencies
# ===============================================================================
function install_serviceability() {
    
    if [ -z "${airgapInstall}" ]; then
      bash "${chartsDir}"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/common/installServiceability.sh -n ${namespace}
    else 
      bash "${chartsDir}"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/common/installServiceability.sh -n ${namespace} -airgap "$repo"
    fi
    if [ $? -ne 0 ]; then
      exit 1
    fi
    echo "[INFO] cp-serviceability SA, Pod and CronJob created"
}

# Move backup pvc for uninstall and install scenario 
backup_pvc(){
    local flag=$1
    if [[ $flag == "install" ]];then
       if ! $kubernetesCLI get pvc cp4s-backup-pv-claim -n kube-system 2>/dev/null;then
          echo "INFO - cp4s-backup-pv-claim not found in kube-system,skipping restore of pvc into ${namespace} namespace"
          return
        fi 
        run "${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/resources/move_pvc.sh -fromnamespace kube-system -tonamespace ${namespace} cp4s-backup-pv-claim" "Restore of pvc cp4s-backup-pv-claim"
    elif [[ $flag == "uninstall" ]]; then
        if ! $kubernetesCLI get pvc cp4s-backup-pv-claim -n ${namespace} 2>/dev/null;then
          echo "INFO - cp4s-backup-pv-claim not found in ${namespace} namespace,skipping backup"
          return
        fi 
        run "${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/support/resources/move_pvc.sh -fromnamespace ${namespace} -tonamespace kube-system cp4s-backup-pv-claim" "Backup of pvc cp4s-backup-pv-claim"
    fi
}

#Measure Progress
function measure_progress()
{  
    total_jobs=$1
    finished_jobs=$2 
    remaining_jobs=$(( $total_jobs - $finished_jobs ))
    finish_percentage=$(( ($finished_jobs * 100) /$total_jobs ))
    remaining_percentage=$(( (($remaining_jobs * 100) /$total_jobs) + 2 )) 
    h=$(printf '%0.s#' $(seq 1 ${finish_percentage}))
    d=$(printf '%0.s-' $(seq 1 ${remaining_percentage}) )
    echo "[Progress: ${h// /*}${d// /*} | Step $finished_jobs of $total_jobs, Task Completed: $stage_name]"
    printf "\n"
}
function status()
{
    exit_code=$1
    stage_name=$2
    total_stages=$3
    if [[ ${exit_code} == 0 ]]; then
        list1+=($stage_name)
    fi
    measure_progress $total_stages ${#list1[@]} $stage_name
}
function run_action() {
    echo "Executing inventory item ${inventory}, action ${action} : ${scriptName}"
    case $action in
    install)
        stages=("Validate-CP4S-Install-PreReqs" "Install-Common-Services" "Install-Foundations" "Install-Solutions" "Post-Install-Validation")
        list1=()
        check_cli_args
         ##check status
        status $? Validate-CP4S-Install-PreReqs ${#stages[@]}
        
        setup_namespace "${namespace}" "-clean-install"
        
        backup_pvc "uninstall"
        
        check_remove "solutions"
        check_remove "foundations"
        check_remove "couchdboperator"
        check_remove "redisoperator"
        check_remove "commonservices"
        
        install_cs
        ##check status
        status $? Install-Common-Services ${#stages[@]}
        
        loginCS
        echo "INFO - Cloudctl login credentials user name: $CS_USER, password: $CS_PASS, host: $CS_HOST"
        sleep 6
        restart_community_operators
        
        install_couchdb
        install_redis
        run "$scriptDir/support/validate.sh -couchdb" "Couchdb operator validation"
        run "$scriptDir/support/validate.sh -redis" "Redis operator validation"
        
        install_charts "$foundations_release_name"
        ##check status
        status $? Install-Foundations ${#stages[@]}

        install_serviceability
        run "$scriptDir/support/validate.sh -chart $foundations_release_name" "$foundations_release_name validation"
        backup_pvc "install"
        
        install_charts "$solutions_release_name"
        ##check status
        status $? Install-Solutions ${#stages[@]} 
        solutions_postinstall
        run "$scriptDir/support/validate.sh -chart $solutions_release_name" "$solutions_release_name validation"
        ##check status
        status $? Post-Install-Validation ${#stages[@]}
        ;;
    uninstall)
        stages=("Validate-CP4S-PreReqs" "Uninstall-Solutions" "Uninstall-Foundations" "Uninstall-Common-Services")
        list1=()
        check_cli_args
        ##check status
        status $? Validate-CP4S-PreReqs ${#stages[@]}
        
        setup_namespace "${namespace}"
        
        backup_pvc "uninstall"
        
        run "$scriptDir/support/uninstall.sh -uninstall_chart $solutions_release_name" "$solutions_release_name uninstall"
        ##check status
        status $? Uninstall-Solutions ${#stages[@]}
        
        run "$scriptDir/support/uninstall.sh -uninstall_chart $foundations_release_name" "$foundations_release_name uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_redis" "Redis operator uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_couchdb ${inputcasedir}" "Couchdb operator uninstall"
        ##check status
        status $? Uninstall-Foundations ${#stages[@]}
        
        run "$scriptDir/support/uninstall.sh -uninstall_operatorgroup" "Operator group uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_generic_catalog" "Ibm operator catalog uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_cs case ${inputcasedir} ${repo}" "Foundational Services uninstall"
        run "$scriptDir/support/uninstall.sh -contentsourcepolicy" "Deletion of ibm-cp-security image source policy"
        $kubernetesCLI delete namespace "${namespace}" >/dev/null 2>&1
        
        ##check status
        status $? Uninstall-CommonServices ${#stages[@]}
        ;;
    installServiceability)
        check_cli_args
        install_serviceability
        ;;
    upgradeAll)
        stages=("Validate-CP4S-PreReqs" "Upgrade-Common-Services" "Upgrade-Foundations" "Upgrade-Solutions" "Post-Upgrade-Validation")
        list1=()
        
        check_cli_args
        ##check status
        status $? Validate-CP4S-PreReqs ${#stages[@]}
        
        setup_namespace "${namespace}"

        upgrade_cs
        ##check status
        status $? Upgrade-Common-Services ${#stages[@]}
        loginCS
        restart_community_operators
        install_redis
        install_couchdb
        run "$scriptDir/support/validate.sh -couchdb" "Couchdb operator validation"
        run "$scriptDir/support/validate.sh -redis" "Redis operator validation"
        
        
        install_serviceability

        upgrade_charts "$foundations_release_name"
        run "$scriptDir/support/validate.sh -chart ibm-security-foundations" "$foundations_release_name validation"
        ##check status
        status $? Upgrade-Foundations ${#stages[@]}
        
        # Save old version of Solutions if any
        old_solutions_version=$(${helm3} ls --namespace="$namespace" | grep "$solutions_release_name" | awk '{print $NF}')
        upgrade_charts "$solutions_release_name"
        ##check status
        status $? Upgrade-Solutions ${#stages[@]}
                
        solutions_postinstall
        run "$scriptDir/support/validate.sh -chart ibm-security-solutions" "ibm-security-solutions validation"

        ## run postupgrade
        post_upgrade "$solutions_release_name" "$old_solutions_version"

        ##check status
        status $? Post-Upgrade-Validation ${#stages[@]}
        ;;
    validate)
        check_cli_args
        setup_namespace "${namespace}"
        run "$scriptDir/support/validate.sh -chart $foundations_release_name -helmtest" "$foundations_release_name validation"
        run "$scriptDir/support/validate.sh -chart $solutions_release_name -helmtest" "$solutions_release_name validation"
        ;;
    postUpgrade)
        check_cli_args
        setup_namespace "${namespace}"
        run "$scriptDir/support/validate.sh -chart ibm-security-solutions" "ibm-security-solutions validation"
        ## run postupgrade
        post_upgrade "$solutions_release_name"
        ;;
    upgradeFoundations)
        check_cli_args
        setup_namespace "${namespace}"
        loginCS
        restart_community_operators
        install_redis
        install_couchdb
        run "$scriptDir/support/validate.sh -redis"
        run "$scriptDir/support/validate.sh -couchdb"
        upgrade_charts "$foundations_release_name"
        run "$scriptDir/support/validate.sh -chart $foundations_release_name" "$foundations_release_name validation"
        ;;
    upgradeSolutions)
        check_cli_args
        setup_namespace "${namespace}"
        loginCS

        # Save old version of Solutions if any
        old_solutions_version=$(${helm3} ls --namespace="$namespace" | grep "$solutions_release_name" | awk '{print $NF}')
        upgrade_charts "$solutions_release_name"
        
        solutions_postinstall
        run "$scriptDir/support/validate.sh -chart ibm-security-solutions" "ibm-security-solutions validation"
        
        ## run postupgrade
        post_upgrade "$solutions_release_name" "$old_solutions_version"
        ;;
    upgradeCommonServices)
        check_cli_args
        upgrade_cs
        loginCS
        echo "INFO - Cloudctl login credentials username: $CS_USER, password: $CS_PASS, host: $CS_HOST"
        sleep 6
        ;;
    installCommonServices)
       install_cs
       setup_namespace "ibm-common-services" "-clean-install"
       loginCS
        echo "INFO - Cloudctl login credentials username: $CS_USER, password: $CS_PASS, host: $CS_HOST"
        sleep 6
        ;; 
    uninstallCommonServices)
        setup_namespace "ibm-common-services"
        run "$scriptDir/support/uninstall.sh -uninstall_cs case ${inputcasedir} ${repo}" "Foundational Services uninstall"
        ;;
    installRedisOperator)
        setup_namespace "${namespace}" "-clean-install"
        restart_community_operators
        install_redis
        run "$scriptDir/support/validate.sh -redis" "Redis operator validation"
        ;;
    installCouchdbOperator)
        setup_namespace "${namespace}" "-clean-install"
        restart_community_operators
        install_couchdb
        run "$scriptDir/support/validate.sh -couchdb" "Couchdb operator validation"
        ;;
    uninstallCouchdbOperator)
        setup_namespace "${namespace}"
        run "$scriptDir/support/uninstall.sh -uninstall_couchdb ${inputcasedir}" "Couchdb operator uninstall"
        ;;
    uninstallRedisOperator)
        setup_namespace "${namespace}"
        run "$scriptDir/support/uninstall.sh -uninstall_redis" "Redis operator uninstall"
        ;;
    installFoundations)
        check_cli_args
        setup_namespace "${namespace}" "-clean-install"
        loginCS
        run "$scriptDir/support/validate.sh -redis"
        run "$scriptDir/support/validate.sh -couchdb"
        install_charts "$foundations_release_name"
        run "$scriptDir/support/validate.sh -chart $foundations_release_name" "$foundations_release_name validation"
        ;;
    installSolutions)
        check_cli_args
        setup_namespace "${namespace}"
         backup_pvc "install"
        loginCS
        install_charts "$solutions_release_name"
        solutions_postinstall       
        run "$scriptDir/support/validate.sh -chart $solutions_release_name" "$solutions_release_name validation"
        ;;
    uninstallSolutions)
        check_cli_args
        setup_namespace "${namespace}"
        backup_pvc "uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_chart $solutions_release_name" "$solutions_release_name uninstall"
        ;;
    uninstallFoundations)
        check_cli_args
        setup_namespace "${namespace}"
        run "$scriptDir/support/uninstall.sh -uninstall_chart $foundations_release_name" "$foundations_release_name uninstall"
        ;;
    configureCredsAirgap)
       configure_creds_airgap
        ;;
    configureClusterAirgap)
       configure_cluster_airgap
        ;; 
    mirrorImages)
       mirror_images
        ;;
    mirrorCasesImages)
       cases_images
        ;;
    updateCases)
       setup_namespace "${namespace}"
       deploy_cases
        ;;
    listConnectors)
        check_cli_args
        list_connectors
        ;;
    getConnector)
        check_cli_args
        get_connector
        ;;
    deployConnector)
        check_cli_args
        deploy_connector
        ;;
    deleteConnector)
        check_cli_args
        delete_connector
        ;;
    restoreConnectors)
        check_cli_args
        restore_connectors
        ;;
    *)
        err "Invalid Action ${action}" >&2
        run "$scriptDir/support/usage.sh"
        ;;
    esac
}
run_action
