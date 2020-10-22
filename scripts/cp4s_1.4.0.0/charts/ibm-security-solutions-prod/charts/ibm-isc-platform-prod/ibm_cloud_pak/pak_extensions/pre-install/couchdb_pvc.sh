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

INSTANCE="default"
NAMESPACE="isc"
STORAGE="10Gi"
STORAGECLASS="nfs-client"
REPLICAS=3

source $(dirname $0)/pvc_args.sh

parse_args $*

for ndx in $(seq 0 $(($REPLICAS - 1)))
do
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  annotations:
  labels:
    app: couchdb
    release: couchdb-${INSTANCE}
  name: database-storage-${INSTANCE}-couchdb-${ndx}
  namespace: ${NAMESPACE}
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: ${STORAGE}
  storageClassName: ${STORAGECLASS}
EOF

done
