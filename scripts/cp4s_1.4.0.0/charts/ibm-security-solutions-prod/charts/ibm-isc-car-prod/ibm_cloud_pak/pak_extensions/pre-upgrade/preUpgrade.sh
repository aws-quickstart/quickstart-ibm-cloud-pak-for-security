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
configname="car-version"
FORCE=0

createCM() {
  ex=$(kubectl get configmap $configname -o jsonpath="{.data['version\.cfg']}" 2>/dev/null)
  case "X$ex" in
    X) ;;
    X1300) echo "INFO: Configmap $configname already exist"
           return
           ;;
    X1400) echo "INFO: CAR is already upgraded"
           return
           ;;
    *)
    if [ $FORCE -eq 0 ]; then
       echo "ERROR: configmap $configname already exists"
       exit 1
    fi
    kubectl delete configmap $configname
    ;;
  esac
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
    *)
      echo "Invalid argument: $arg"
      usage
      exit 1
  esac
done

createCM

exit 0
