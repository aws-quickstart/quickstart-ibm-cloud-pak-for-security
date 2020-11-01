#!/usr/bin/env bash

#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
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
ent="ZXlKaGJHY2lPaUpJVXpJMU5pSjkuZXlKcGMzTWlPaUpKUWswZ1RXRnlhMlYwY0d4aFkyVWlMQ0pwWVhRaU9qRTJNREF6TkRVMU5ETXNJbXAwYVNJNklqQXhOakJsT0RsaFpqZ3hZalF4TnpnNVlUYzJOR1JqT0RReU1qVmtPRFE0SW4wLk5KaUxUbHFJbFhyLWVpeGR4M2Y1MjYwNUE3ZjV6dHJ4Ym9Jam13aW00RXM="
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
settoolboxStorage=""
csPatch="${casePath}"/inventory/ibmcloudEnablement/files/install/csPatch.sh
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
        --helm2)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            helm_2="$v"
            ;;
        --helm3)
            idx=$((idx + 1))
            v="${arr[${idx}]}"
            helm_3="$v"
            ;;
        --help)
            $scriptDir/support/usage.sh
            sleep 2
            exit
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
 check_ns=$($kubernetesCLI get namespace "$name" | awk '{print $1}' 2>/dev/null)
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
     
     echo "INFO - Verifying registry credentials"
     
    docker login -u "$user" -p "$pass" "$reg" >/dev/null 2>&1
     if [ $? -ne 0 ]; then 
        err_exit " Registry validation failed"
     else
        echo "Registry validation complete" 
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
        
        binary=$(which helm )
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


function check_cli_args() {
    # Verify required parameters were specifed and are valid (including environment setup)
    # - case path
    [[ -z "${casePath}" ]] && { err_exit "The case path parameter was not specified."; }
    [[ -z "${inputcasedir}" ]] && { err_exit "The extract case path was not specified."; }
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
    cloudType="$cloudType"
    domain="$cp4sapplicationDomain"
    storage="$storageClass"
    repositoryType="$registryType"
    userId="$adminUserId"
    defaultAccount="$defaultAccountName"
    securityAdvisor="$enableCloudSecurityAdvisor"
    fsGroup="$storageClassFsGroup"
    supplementalGroups="$storageClassSupplementalGroups"
    toolboxStorage="$toolboxStorageClass"
    toolboxStorageSize="$toolboxStorageSize"
    imagepullPolicy="$cp4simagePullPolicy"
    # Verify namespace
    [[ -z "${namespace}" ]] && { err_exit "The namespace parameter was not specified."; }

    if [[ $action == "installFoundations" ]] || [[ $action == "installSolutions" ]] || [[ $action == "install" ]] || [[ $action == "upgradeAll" ]] || [[ $action == "upgradeFoundations" ]] || [[ $action == "upgradeSolutions" ]] || [[ $action == "validate" ]] || [[ $action == "upgradeCommonServices" ]] || [[ $action == "postUpgrade" ]]; then 
        ### check for license only when actions is set
        if [[ -z  "${license}" ]] || [[ "${license}" != "accept" ]]; then
            err_exit "license not accepted, please read license in ibm-cp-security/licenses directory and accept by adding --license accept as part of the install args"
       fi
       if  [[ -z "$helm_3" ]]; then
          err_exit "Path to helm3 binary not set"
       elif [[ $action == *"upgrade"* ]]; then
           if [[ -z "$helm_2" ]]; then
              err_exit "Path to helm2 binary must be set for upgrade action"
           else
              export helm2=$(check_helm "$helm_2" "helm2" 'SemVer:"v2.12' "--tls")
            fi
        fi
        export helm3=$(check_helm "$helm_3" "helm3" 'Version:"v3.2')
        
        if ! ls "${inputcasedir}/charts" | grep -Eo "ibm-.*.tgz" >/dev/null  2>&1; then
             err_exit "No charts .tgz in the root of the specified case directory path."

        fi
        ## Untar the charts
         untar_chart "foundations"
         untar_chart "solutions"

        if [[ $imagepullPolicy != "Always" && $imagepullPolicy != "IfNotPresent" ]]; then
            err_exit "Invalid ImagePullPolicy $imagepullPolicy. Available pull policy options: Always,IfNotPresent"
        else
           pullPolicy="--set global.imagePullPolicy=$imagepullPolicy"
        fi

        if [[ $cloudType != "aws" &&  $cloudType != "ocp" &&  $cloudType != "ibmcloud" ]]; then

           err_exit "Invalid cloudType $cloudType in values.conf. Available cloudtype options: aws,ibmcloud,ocp"
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

        if [[  -n $toolboxStorage ]];then 
            which_storage=$($kubernetesCLI get sc | grep "$toolboxStorage" | awk '{print $1;exit;}')  
            [[ -z "${which_storage}" ]] && { err_exit "The backup storage class specified was not found ."; }
            settoolboxStorage="--set global.toolbox.storageClass=$toolboxStorage"
        fi

        if [[ -n $toolboxStorageSize ]]; then
            settoolboxSize="--set global.toolbox.size=$toolboxStorageSize"
        fi
        ### Check FQDN
        if [[ -z "${domain}"  ]]; then
            if [[ $action != *"Foundations"* ]]; then
               err_exit "The application domain  was not specified in values.conf."
            fi
        fi
        [[ -z $userId ]] && { err_exit "An Admin userid was not specified in values.conf";}
        
        #### Check storage
       [[ -z $storage ]] && { err_exit "The storage class parameter was not specified in values.conf."; }    

        ### Check Certificates
        [[ -z ${certFile} ]] && { err_exit "cert.crt file parameter was not specified in values.conf."; }
        validate_file_exists "${certFile}" 
        [[ -z ${keyFile} ]] && { err_exit "cert.key file parameter was not specified in values.conf."; }
        validate_file_exists "${keyFile}"
       
       ### Check repoistorytype is set 
       [[ -z $repositoryType ]] && { err_exit "The repository type parameter was not set in values.conf"; }

       check_storage=$($kubernetesCLI get sc | grep "$storageClass"| awk '{print $1;exit;}')  
    
       if [ "X$check_storage" == "X" ]; then
          available_storage=$($kubernetesCLI get sc | awk '{print $1}')
          err "Storage class $storageClass not found"
          echo "################################"
          err "Select from available storage"
          echo "###############################"
           err_exit "$available_storage"
        else
          $kubernetesCLI  patch storageclass $check_storage  -p '{"metadata": {"annotations": {"storageclass.kubernetes.io/is-default-class": "true"}}}'
        fi
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
       export helm3=$(check_helm "$helm_3" "helm3" 'Version:"v3.2')
     
        if ! ls "${inputcasedir}/charts" | egrep -o "ibm-.*.tgz" >/dev/null  2>&1; then
             err_exit "No charts .tgz in the root of the specified case directory path parameter."
        fi
        ## Untar the charts
        untar_chart "foundations"
        untar_chart "solutions"
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
                chart_url=$localRegistry
                repo_user=$localUsername
                repo_pass=$localPassword
                repositoryType="local"

            fi
        else
             err_exit "Local registry creds must be set"
        fi

    elif [[ -z "${entitledRegistry}" ]] || [[ -z "${entitledUser}" ]] || [[ -z "${entitledPass}" ]]; then
       if [[ $action != *"uninstall"* ]]; then
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

    [[ -z "${inputcasedir}" ]] && {
        foundError=1
        err "'--inputDir' must be specified with the '--args' parameter"
    }

    # Print usgae if missing parameter
    [[ $foundError -eq 1 ]] && { print_usage 1; }
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

    # Create registry secret for user information provided
    if [[ "X$pass" == "Xppa" ]]; then
         user="cp"
         pass=$(echo -n "$ent" | base64 -d)
    fi

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

# Apply ImageContentSourcePolicy required for airgap
function configure_cluster_airgap() {

    echo "-------------Configuring cluster for airgap-------------"

    validate_configure_cluster_airgap_args

    configure_cluster_pull_secret

    configure_content_image_source_policy
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
         exit 0
      fi
     ((runs++))
    done

}
## Run chart prereq script
function chart_prereq(){
    local chart=$1
    local maxRetry=3
    local param=""
    if [[ $chart == "solutions" ]]; then
        param="--solutions"
    fi
    for ((retry=0;retry<maxRetry;retry++)); do
      echo "INFO - running prerequisite checks for $chart"
      if bash "${chartsDir}"/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-install/checkprereq.sh -n "${namespace}" $param; then
        return 0
      fi
      sleep 30
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
      tar xvf /ibm/charts/ibm-security-foundations-prod-1.0.8.tgz
      cd /ibm
  else
        echo "INFO - Running Preinstall of $solutions_release_name"
        
        if [ "X$customCA" != "X" ]; then
          
          run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n ${namespace} -cert $certFile  -key $keyFile -ca $customCA -force -resources" "Preinstall of $solutions_release_name"
        else
           
           run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/pre-install/preInstall.sh -n ${namespace}  -cert $certFile  -key $keyFile -force -resources" "Preinstall of $solutions_release_name"
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
       run "${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-upgrade/preUpgrade.sh -n $namespace -helm2 ${helm2}" "Preupgrade of $chart"
       
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
## Install of solutions and foundations chart
function install_charts(){
    local chart=$1
    if [[ $chart == "ibm-security-foundations" ]]; then
     
     isPresent=$(${helm3} ls --namespace "$namespace" | grep "$foundations_release_name" | awk '{print $1;exit;}')
     if [[ "X$isPresent" != "X" ]]; then preupgrade "$foundations_release_name"
     else
        pre_install "$foundations_release_name"
    fi
     echo "INFO - Installing CP4S $foundations_release_name Chart"
     
     if ! ${helm3} upgrade --install "$foundations_release_name" --namespace="$namespace" --set global.cloudType="${cloudType}" --set global.repositoryType="${repositoryType}" --set global.repository="${chart_url}" $pullPolicy --set global.license="$license" --values "${chartsDir}"/ibm-security-foundations-prod/values.yaml "${chartsDir}"/ibm-security-foundations-prod  --reset-values; then
     err_exit "$foundations_release_name installations has failed"
     fi
      ## Give time for pods to run before checking
     sleep 5
  else
     
     isPresent=$(${helm3} ls --namespace "$namespace" | grep "$solutions_release_name" | awk '{print $1;exit;}' )
     if [[ "X$isPresent" != "X" ]]; then 
       
        preupgrade "$solutions_release_name"; 
     else 
         pre_install "$solutions_release_name"   
     fi

     echo "INFO - Installing CP4S $solutions_release_name Chart"
         
    
    if ! $helm3 upgrade --install "$solutions_release_name" --namespace="${namespace}" --set global.repositoryType="${repositoryType}" --set global.repository="${chart_url}" --set global.cluster.icphostname="$CS_HOST" $settoolboxStorage $settoolboxSize $enableAdapter $setbackrestGroup $setbackrestsupGroup $setfsGroup $setsupGroup $pullPolicy --set global.csNamespace="$CS_NAMESPACE" --set global.storageClass="$storageClass" --set global.license="$license"  --set global.adminUserId="${userId}" --set global.defaultAccountName="${defaultAccount}" --set global.domain.default.domain="${domain}" --values "${chartsDir}"/ibm-security-solutions-prod/values.yaml "${chartsDir}"/ibm-security-solutions-prod --reset-values; then 
    err_exit "$solutions_release_name installation has Failed"
    fi
    sleep 5

  fi
  }

function loginCS() {
    CS_HOST=$($kubernetesCLI get route --no-headers -n "$CS_NAMESPACE" | grep "cp-console" | awk '{print $2}')
    CS_PASS=$($kubernetesCLI -n "$CS_NAMESPACE" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_password}' | base64 --decode)
    CS_USER=$($kubernetesCLI -n "$CS_NAMESPACE" get secret platform-auth-idp-credentials -o jsonpath='{.data.admin_username}' | base64 --decode)
    if ! cloudctl login -a "$CS_HOST" -u "$CS_USER" -p "$CS_PASS" -n "$namespace" --skip-ssl-validation; then 
      err_exit "Failure on Common Services Login. Exiting."
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

    local inventoryOfOperator="ibmCommonServiceOperatorSetup"

    local online_catalog_source="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/online_catalog_source.yaml
    
    $kubernetesCLI create namespace "$CS_NAMESPACE"  >/dev/null 2>&1
    
    $kubernetesCLI project "$CS_NAMESPACE"  >/dev/null 2>&1
    
    echo "INFO - Installing Common Services"

    if [[ "X$airgapInstall" != "X" ]]; then
    
        url="$repo"
    else
       url="quay.io"

    fi

    if ! cloudctl case launch --case "${casePath}" --namespace "$CS_NAMESPACE" --inventory "$inventoryOfOperator" --action install-catalog --args "--registry $url" --tolerance 1 >/dev/null 2>&1; then 
         err_exit "Failed to install Common services catalog"
    fi

    if ! cloudctl case launch --case "${casePath}" --namespace "$CS_NAMESPACE" --inventory "$inventoryOfOperator" --action  install-operator  --tolerance 1 >/dev/null  2>&1; then 
    err_exit "Failed to install Common services operator"
    fi
    sleep 40
    run "$scriptDir/support/validate.sh -cs" "Common Services Validation has failed"
    run "${csPatch}" "Common Services resource reduction"
}

function upgrade_charts(){
  export TILLER_NAMESPACE="${CS_NAMESPACE}"
  local chart="$1"
  local force=""
  local skip_preupgrade="$2"
  if [[ $chart == "ibm-security-foundations" ]]; then
     ### Check if previous version of cp4s is installed
     isPresent=$(${helm2} ls --namespace "$namespace" --tls | grep "$foundations_release_name" | awk '{print $1;exit;}' 2>/dev/null)
     if [ -z "$isPresent" ]; then
        
        echo  "INFO - No 1.3.0.1 version of $foundations_release_name found,checking if 1.4.0.0 release exist of $foundations_release_name for preupgrade"
    else
          ## Re-use existing release name in cluster
          foundations_release_name="$isPresent"
     fi  
     isPresen=$(${helm3} status --namespace "$namespace" "$foundations_release_name"| grep -m1 "STATUS" 2>/dev/null) 
     if [ -z "$isPresen" ]; then
           echo "No current version of $foundations_release_name found"
           force="--force" 
     elif [[ "$isPresen" =~ "failed" ]]; then
          err_exit "$foundations_release_name helm3 has a failed release,please contact your administrator"
    elif [[ "$isPresen" =~ "deployed" ]]; then
         echo "Found deployed 1.4.0.0 version of $foundations_release_name"
          
     fi
        
     echo "INFO - starting preupgrade..."
    
    if [[ $skip_preupgrade != "--skip-preupgrade" ]]; then
         preupgrade "$chart"
    fi

     echo "INFO - Installing CP4S $foundations_release_name Chart"
     
     if ! ${helm3} upgrade --install "$foundations_release_name" --namespace="$namespace" --set global.cloudType="${cloudType}" --set global.repositoryType=${repositoryType} $pullPolicy --set global.repository="${chart_url}" --set global.license="$license" --set global.helmUser="${CS_USER}" --values "${chartsDir}"/ibm-security-foundations-prod/values.yaml "${chartsDir}"/ibm-security-foundations-prod --reset-values $force --timeout 1000s; then
        err_exit "$foundations_release_name upgrade has failed"
     fi
    elif [ "$chart" == "ibm-security-solutions" ]; then
        isPresent=$(${helm2} ls --namespace "$namespace" --tls | grep "$solutions_release_name" | awk '{print $1;exit;}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
            
            echo  "INFO - No 1.3.0.1 version of $solutions_release_name found,checking if 1.4.0.0 release exist of $solutions_release_name for preupgrade"
        else
            ## Re-use existing release name in cluster
            solutions_release_name="$isPresent"
        fi
        isPresen=$(${helm3} status --namespace "$namespace" "$solutions_release_name" | grep -m1 "STATUS" 2>/dev/null)  
        if [ -z "$isPresen" ]; then
           echo "No current version of $solutions_release_name found"
           force="--force" 
        elif [[ "$isPresen" =~ "failed" ]]; then
            err_exit "$solutions_release_name helm3 has a failed release,please contact your administrator"
        elif [[ "$isPresen" =~ "deployed" ]]; then
            echo "Found deployed 1.4.0.0 version of $solutions_release_name"
        fi
         
        echo "INFO - starting preupgrade..."
        
        preupgrade "$chart"
           
        if ! ${helm3} upgrade --install "$solutions_release_name" --namespace="${namespace}" --set global.repositoryType="${repositoryType}" --set global.repository="${chart_url}" $settoolboxStorage $settoolboxSize $enableAdapter $setbackrestGroup $setbackrestsupGroup $setfsGroup $setsupGroup $pullPolicy --set global.cluster.icphostname="$CS_HOST" --set global.csNamespace="$CS_NAMESPACE" --set global.storageClass="$storageClass" --set global.adminUserId="${userId}" --set global.license="$license" --set global.domain.default.domain="${domain}" --values "${chartsDir}"/ibm-security-solutions-prod/values.yaml "${chartsDir}"/ibm-security-solutions-prod --reset-values $force --timeout 1000s; then
          err_exit "$solutions_release_name upgrade has failed"
        fi
        sleep 5
        run "$scriptDir/support/validate.sh -chart ibm-security-solutions" "ibm-security-solutions validation"
        
        ## run postupgrade
        echo "INFO - Initiating post-upgrade"
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $namespace -helm3 ${helm3}" "Post upgrade of ibm-security-solutions"
        # cleanup run
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $namespace -helm3 ${helm3} -cleanup" "Post upgrade cleanup of ibm-security-solutions"
   
    fi
}

function upgrade_cs(){
    
    local migration_file="${casePath}"/inventory/ibmcloudEnablement/files/install/csMigration.sh
    icpIssuer=$($kubernetesCLI get cert management-ingress-cert -o jsonpath='{.spec.issuerRef.name}' -n "${CS_NAMESPACE}" 2>/dev/null)
    if [[ -z $icpIssuer ]]; then
     ## check if doing airgap install to update image
     if [ "X$airgapInstall" != "X" ]; then
        local image_find=$(grep "image:" "${migration_file}" | awk '{print $2}')
        for image in ${image_find[*]}; 
        do
          local image_replace="${repo}/$(echo "$image" | sed -e "s/[^/]*\///" | sed -e "s/[^/]*\///" | sed -e "s/[^/]*\///")"
          sed <"${migration_file}" "s|${image}|${image_replace}|g"
        done
     fi
     echo "INFO - initiating upgrade of common services"
     run "${chartsDir}/ibm-security-foundations-prod/ibm_cloud_pak/pak_extensions/pre-upgrade/preUpgrade.sh -n $namespace -helm2 ${helm2}" "Preupgrade of ibm-security-foundations"
     run "$migration_file --chartsDir ${chartsDir} --n ${namespace}" "Common Services Upgrade"
     run "$scriptDir/support/validate.sh -cs" "Common Services Validation"
     run "${csPatch}" "Common Services resource reduction"
    else
       echo "INFO - Previous version of Common Services 3.2.4 not found"
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
    local maxRetry=6
    if [ "X$airgapInstall" == "X" ]; then
       echo "INFO - Restarting certified and community operator pod "
       cert_op=$($kubernetesCLI get pod -lmarketplace.operatorSource=certified-operators -n openshift-marketplace --no-headers 2>/dev/null)
       comm_op=$($kubernetesCLI get pod -lmarketplace.operatorSource=community-operators -n openshift-marketplace --no-headers 2>/dev/null)
       if [[ "X$cert_op" != "X" ]]; then
          if ! $kubernetesCLI delete pod -lmarketplace.operatorSource=certified-operators -n openshift-marketplace 2>/dev/null; then
            err "Failed to restart certified-operators pod"
          fi
        fi
        if [[ "X$comm_op" != "X" ]]; then
          if ! $kubernetesCLI delete pod -lmarketplace.operatorSource=community-operators -n openshift-marketplace 2>/dev/null; then
            err "Failed to restart community-operators pod"
          fi
        fi
        for ((retry=0;retry<=${maxRetry};retry++)); do   
        
        echo "INFO - Waiting for Community and certified operators pod initialization"         
        
        iscertReady=$($kubernetesCLI get pod -lmarketplace.operatorSource=certified-operators -n openshift-marketplace --no-headers 2>/dev/null | awk '{print $3}' | grep "Running")

        iscommReady=$($kubernetesCLI get pod -lmarketplace.operatorSource=community-operators -n openshift-marketplace --no-headers 2>/dev/null | awk '{print $3}' | grep "Running")
        
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
    local offline_name="couchdb-operator"
    local online_name="couchdb-operator-certified"
    local catsrc_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/catalog_source.yaml
    local sub_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/subscription.yaml
    local operator_group="${casePath}"/inventory/"${inventoryOfOperator}"/files/subscription.yaml
    
    validate_file_exists "$catsrc_file"
    validate_file_exists "$sub_file"
    validate_file_exists "$operator_group"

    echo "-------------Installing couchDB operator via OLM-------------"


    if [ "X$airgapInstall" != "X" ]; then
        

        local catsrc_image_orig=$(grep "image:" "${catsrc_file}" | awk '{print$2}')
       
       # replace original registry with local registry
        local catsrc_image_mod="${repo}/$(echo "${catsrc_image_orig}" | sed -e "s/[^/]*\///")"
       # apply catalog source
        sed <"${catsrc_file}" "s|${catsrc_image_orig}|${catsrc_image_mod}|g" | $kubernetesCLI apply -f -

       if ! sed <"$sub_file" "s|REPLACE_NAMESPACE|${namespace}|g; s|REPLACE_SOURCE|$offline_source|g; s|REPLACE_NAME|$offline_name|g" | $kubernetesCLI apply -n "${namespace}" -f - ;then
        err_exit "CouchDB Operator Subscription creation failed"
       else
          echo "CouchDB Operator Subscription Created"
       fi

    else
      if ! sed <"$sub_file" "s|REPLACE_NAMESPACE|${namespace}|g; s|REPLACE_SOURCE|$online_source|g; s|REPLACE_NAME|$online_name|g" |  $kubernetesCLI apply -n "${namespace}" -f - ;then
      err_exit "CouchDB Operator Subscription creation failed"
      else
         echo "CouchDB Operator Subscription Created"
       fi
    fi
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
    
}

function install_redis() {

    local inventoryOfOperator="redisOperator"
    local online_source="ibm-operator-catalog"
    local offline_source="ibm-cloud-databases-redis-operator-catalog"

    local catsrc_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/catalog_source.yaml
    local sub_file="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/subscription.yaml
    local operator_group="${casePath}"/inventory/"${inventoryOfOperator}"/files/op-olm/operator_group.yaml

    validate_file_exists "$catsrc_file"
    validate_file_exists "$sub_file"
    validate_file_exists "$operator_group"

    
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
    #  local redis_case="${inputcasedir}/ibm-cloud-databases-redis-1.0.0.tgz"
    #  validate_file_exists $redis_case
     ### handle repository to be used by catalog
    #  if [ "X$airgapInstall" != "X" ]; then
    #     reg="$repo"
    #  else
    #     reg="docker.io"
    #  fi
    #  cloudctl case launch --case $redis_case --inventory redisOperator --namespace $namespace --action installCatalog --args "--registry $reg " --tolerance 1 
    #  if [ $? -ne 0 ]; then err_exit "Redis Operator catalog install has failed";fi
    
    # cloudctl case launch --case $redis_case --inventory redisOperator --namespace $namespace --action installOperator --args "--registry $rep --secret ibm-entitlement-key --user $usr --pass $key" --tolerance 1 
    # if [ $? -ne 0 ]; then err_exit "Redis Operator install has failed";fi
    echo "-------------Installing Redis operator via OLM-------------"
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
}
## check what is installed and remove them if they exist
function check_remove(){
    local flag=$1
    if [[ $flag == "solutions" ]]; then
      isPresent=$(${helm3} ls --namespace "$namespace" | grep "$solutions_release_name" | awk '{print $1}' 2>/dev/null)
      if [ -z "$isPresent" ]; then
        echo "INFO - No previous release of $solutions_release_name found"
      else
        run "$scriptDir/support/uninstall.sh -uninstall_chart $solutions_release_name" "$solutions_release_name uninstall"
      fi

    elif [[ $flag == "foundations" ]]; then

        isPresent=$(${helm3} ls --namespace "$namespace" | grep "$foundations_release_name" | awk '{print $1}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
         echo "INFO - No previous release of $foundations_release_name found"
        else
          run "$scriptDir/support/uninstall.sh -uninstall_chart $foundations_release_name" "$foundations_release_name uninstall"
        fi

    elif [[ $flag == "couchdboperator" ]]; then

        isPresent=$($kubernetesCLI get pod -n "$namespace" -lname=couchdb-operator --no-headers | awk '{print $1}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
         echo "INFO - No previous release of couchdboperator found"
        else
          run "$scriptDir/support/uninstall.sh -uninstall_couchdb" "Couchdb operator uninstall"
        fi

    elif [[ $flag == "redisoperator" ]]; then
        
        isPresent=$($kubernetesCLI get pod -n "$namespace" -lname=ibm-cloud-databases-redis-operator --no-headers | awk '{print $1}' 2>/dev/null)
        if [ -z "$isPresent" ]; then
           echo "INFO - No previous release of redisoperator found"
        else
          run "$scriptDir/support/uninstall.sh -uninstall_redis" "redis operator uninstall"
        fi
    elif [[ $flag == "commonservices" ]]; then

        if ! $kubernetesCLI get namespace ibm-common-services >/dev/null 2>&1; then
            echo "INFO - Common services deployment not found"
        else
           isPresent=$($kubernetesCLI  get cert management-ingress-cert -o jsonpath='{.spec.issuerRef.name}' -n ibm-common-services 2>/dev/null)
           csPods=$($kubernetesCLI  get pod -n ibm-common-services --no-headers 2>/dev/null)
           if [[ -z "$isPresent" ]] || [[ -z "$csPods" ]]; then
             echo "INFO - Common services deployment not found"
           else
              run "$scriptDir/support/uninstall.sh -uninstall_cs" "Common Services uninstall"
           fi

        fi
    fi
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

function run_action() {
    echo "Executing inventory item ${inventory}, action ${action} : ${scriptName}"
    case $action in
    install)
        check_cli_args
        setup_namespace "${namespace}" "-clean-install"
        backup_pvc "uninstall"
        check_remove "solutions"
        check_remove "foundations"
        check_remove "couchdboperator"
        check_remove "redisoperator"
        check_remove "commonservices"
        install_cs
        loginCS
        echo "INFO - Cloudctl login credentials user name: $CS_USER, password: $CS_PASS, host: $CS_HOST"
        sleep 6
        restart_community_operators
        install_couchdb
        install_redis
        run "$scriptDir/support/validate.sh -couchdb" "Couchdb operator validation"
        run "$scriptDir/support/validate.sh -redis" "Redis operator validation"
        install_charts "$foundations_release_name"
        run "$scriptDir/support/validate.sh -chart $foundations_release_name" "$foundations_release_name validation"
        backup_pvc "install"
        install_charts "$solutions_release_name"
        run "$scriptDir/support/validate.sh -chart $solutions_release_name" "$solutions_release_name validation"
        ;;
    uninstall)
        check_cli_args
        setup_namespace "${namespace}"
        backup_pvc "uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_chart $solutions_release_name" "$solutions_release_name uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_chart $foundations_release_name" "$foundations_release_name uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_redis" "Redis operator uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_couchdb" "Couchdb operator uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_operatorgroup" "Operator group uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_generic_catalog" "Ibm operator catalog uninstall"
        run "$scriptDir/support/uninstall.sh -uninstall_cs" "Common Services uninstall"
        run "$scriptDir/support/uninstall.sh -contentsourcepolicy" "Deletion of ibm-cp-security image source policy"
        $kubernetesCLI delete namespace "${namespace}" >/dev/null 2>&1
        ;;
    upgradeAll)
        check_cli_args
        setup_namespace "${namespace}"
        upgrade_cs
        loginCS
        restart_community_operators
        install_redis
        install_couchdb
        run "$scriptDir/support/validate.sh -couchdb" "Couchdb operator validation"
        run "$scriptDir/support/validate.sh -redis" "Redis operator validation"
        upgrade_charts "$foundations_release_name" "--skip-preupgrade"
        run "$scriptDir/support/validate.sh -chart ibm-security-foundations" "$foundations_release_name validation"
        upgrade_charts "$solutions_release_name"
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
        echo "INFO - Initiating post-upgrade"
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $namespace -helm3 ${helm3}" "Post upgrade of ibm-security-solutions"
        # cleanup run
        run "${chartsDir}/ibm-security-solutions-prod/ibm_cloud_pak/pak_extensions/post-upgrade/postUpgrade.sh -n $namespace -helm3 ${helm3} -cleanup" "Post upgrade cleanup of ibm-security-solutions"
        run "$scriptDir/support/validate.sh -chart ibm-security-solutions" "ibm-security-solutions validation"
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
        upgrade_charts "$solutions_release_name"
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
        run "$scriptDir/support/uninstall.sh -uninstall_cs" "Common Services uninstall"
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
        run "$scriptDir/support/uninstall.sh -uninstall_couchdb" "Couchdb operator uninstall"
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
    *)
        err "Invalid Action ${action}" >&2
        run "$scriptDir/support/usage.sh"
        ;;
    esac
}
run_action