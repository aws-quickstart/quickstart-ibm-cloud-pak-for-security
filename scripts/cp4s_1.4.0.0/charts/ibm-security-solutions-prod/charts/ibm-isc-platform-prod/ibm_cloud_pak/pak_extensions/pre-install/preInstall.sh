#!/bin/bash
# 
#################################################################
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2019.  All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
#################################################################
#
#

root="$(dirname $0)/../../.."
version="1400"
configname="isc-entitlements-version"
FORCE=0

usage() {
cat << "EOF"
Usage: preInstall.sh [options]
where options are one or more of the following options
-n NAMESPACE              - to use provided namespace instead of current
-force                    - to replace existing secrets  
EOF
}


set_namespace()
{
  NAMESPACE="$1"
  ns=$(kubectl get namespace $NAMESPACE -o name 2>/dev/null) 
  if [ "X$ns" == "X" ]; then
    echo "ERROR: Invalid namespace $NAMESPACE"
    exit 1
  fi
}


createCM() {
  ex=$(kubectl get configmap $configname -o jsonpath="{.data['version\.cfg']}" 2>/dev/null)
  case "X$ex" in
    X1400)
       echo "INFO: version is already set"
       ;;
    X) kubectl create configmap $configname --from-literal=version.cfg=$version
       ;;
    *)
       if [ $FORCE -eq 0 ]; then
          echo "ERROR: configmap $configname already exists"
          exit 1
       fi
       kubectl delete configmap $configname
       kubectl create configmap $configname --from-literal=version.cfg=$version
       ;;
  esac
}

FORCE=0
NAMESPACE=$(oc project | sed -e 's/^[^"]*"//' -e 's/".*$//')

while true
do
  arg="$1"
  if [ "X$1" == "X" ]; then
    break
  fi
  shift
  case $arg in
    -n)
      set_namespace "$1"
      shift
      ;;
    -force)
      FORCE=1
      ;;
    *) echo "ERROR: invalid argument $arg"
       usage
       exit 1
       ;;
  esac
done

createCM

exit 0
