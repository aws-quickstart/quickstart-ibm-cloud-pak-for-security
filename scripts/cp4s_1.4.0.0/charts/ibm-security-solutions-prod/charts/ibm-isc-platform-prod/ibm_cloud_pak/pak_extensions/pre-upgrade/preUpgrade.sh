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
version="1300"
targetversion="1400"
configname="isc-entitlements-version"
FORCE=0

createCM() {
  ex=$(kubectl get configmap $configname -o "jsonpath={.data.version\.cfg}" 2>/dev/null)
  if [ "X$ex" != "X" ]; then
    if [ $FORCE -eq 1 ]; then
      kubectl delete configmap $configname
    elif [ "X$ex" == "X$version" ]; then 
      echo "configmap/$configname already exists"
      exit 0
    elif [ "X$ex" == "X$targetversion" ]; then 
      echo "Upgrade already complete, rerun this script with -force if you need to retry the ugrade"
      exit 0
    fi
  fi
  kubectl create configmap $configname --from-literal=version.cfg=$version
  exit 0
}


usage() {
cat << "EOF"
Usage: preUpgrade.sh [ -force ]
EOF
}


while true
do
  arg="$1"
  if [ "X$1" == "X" ]; then
    break
  fi
  shift
  case $arg in
    -force)
      FORCE=1
      ;;
  esac
done

createCM

exit 0
