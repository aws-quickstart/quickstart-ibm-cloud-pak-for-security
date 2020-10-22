#!/bin/bash
# 
#################################################################
# Licensed Materials - Property of IBM
# (C) Copyright IBM Corp. 2018.  All Rights Reserved.
#
# US Government Users Restricted Rights - Use, duplication or
# disclosure restricted by GSA ADP Schedule Contract with
# IBM Corp.
#################################################################
#
#

usage() {
if [ "X$arg" != "X--help" ]; then
echo "Invalid argument $arg"
fi
cat <<EOF
usage: $0 ([ <option> <value> ])*
where valid options are
--instance: name of instance to create, e.g. default
--storageSize: storage size e.g. 1Gi
--storageClass: storage class e.g. nfs-client
--replicas: number of replicas to create PVC for e.g. 3
--namespace: namespace to create PVC in e.g. isc
EOF
}


parse_args() {
  while true
  do
    arg=$1
    shift
    if [ "X$arg" == "X--help" ]; then
      usage
      exit 0
    fi
    if [ "X$arg" == "X" ]; then
      return
    fi

    value=$1
    shift
    if [ "X$value" == "X" ]; then 
       usage
       exit 1
    fi

    case $arg in
    --instance)
       INSTANCE="$value"
       continue
       ;;
    --storageSize)
       STORAGE="$value"
       continue
       ;;
    --storageClass)
       STORAGECLASS="$value"
       continue
       ;;
    --namespace)
       NAMESPACE="$value"
       continue
       ;;
    --replicas)
       REPLICAS="$value"
       continue
       ;;
    *)
       usage
       exit 1
  esac
  done
}
