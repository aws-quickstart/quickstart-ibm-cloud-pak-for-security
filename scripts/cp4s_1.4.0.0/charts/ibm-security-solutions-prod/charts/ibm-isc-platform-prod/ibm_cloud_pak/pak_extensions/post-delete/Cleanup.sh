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
# You need to run this once per cluster
#
# Example:
#     ./cleanup.sh --all --force
#

FORCE="no"
ALL="no"

wait_crs() {
   sort="$1"
   operator="$2"
   echo "Wait for $sort resources to be finalized:"
   for iteration in 1 2 3 4 5 6 7 8 9 10
   do
     found=$(kubectl get $sort -o name) 
     if [ "X$found" == "X" ]; then
        echo "All resources of sort $sort were deleted"
        return
     fi
     echo "Wait until some resources of sort $sort would be removed"
     echo $found
     sleep 15
   done
   echo "The following resources of sort $sort are not removed by some reason"
   echo $found
   if [ "X$FORCE" == "Xyes" ]; then
     echo "Force removing the resources"
     for cr in $found
     do
       kubectl patch $cr --type json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
     done
     found=$(kubectl get $sort -o name) 
     if [ "X$found" != "X" ]; then
        echo "The following resources are still not deleted"
        echo $found
        exit 1
     fi
     return
   fi
   echo "Restarting $operator operator"
   kubectl delete pod -lapp=$operator
   exit 1
}

for arg in $*
do
  case $arg in
  --force)
     FORCE="yes"
     ;;
  --all)
     ALL="yes"
     ;;
  esac
done

echo "Removing iscsequence resources:"
kubectl delete iscsequence --all --wait=false
wait_crs 'iscsequence' 'sequences'

echo "Removing iscguard resources:"
kubectl delete iscguard --all --wait=false
echo "Removing iscinventory resources:"
kubectl delete iscinventory --all --wait=false
      
# delete middleware custom resources
echo "Removing redis resources:"
kubectl delete redis --all --wait=false
echo "Removing couchdb resources:"
kubectl delete couchdb --all --wait=false
echo "Removing etcd resources:"
kubectl delete etcd --all --wait=false
echo "Removing minio resources:"
kubectl delete minio --all --wait=false
echo "Removing oidcclient resources"
kubectl delete oidcclient --all --wait=false
echo "Removing elastic resources"
kubectl delete elastic --all --wait=false
echo "Removing openwhisk resources"
kubectl delete iscopenwhisk --all --wait=false


wait_crs 'redis' 'middleware'
wait_crs 'couchdb' 'middleware'
wait_crs 'etcd' 'middleware'
wait_crs 'minio' 'middleware'
wait_crs 'iscopenwhisk' 'middleware'
wait_crs 'elastic' 'middleware'
wait_crs 'oidcclient' 'middleware'

# check that 
echo "Deleting ibm-redis helm charts"
for redis in $(helm ls --tls -a | awk '{print $1}' | grep '^ibm-redis-')
do
  echo "Chart $redis has not been deleted by the middleware operator"
  helm delete --tls --purge $redis
done

echo "Deleting ibm-etcd helm charts"
for etcd in $(helm ls --tls -a | awk '{print $1}' | grep '^ibm-etcd-')
do
  echo "Chart $etcd has not been deleted by the middleware operator"
  helm delete --tls --purge $etcd
  # Etcd service account is not deleted
  instance=$(echo $etcd | sed -e 's/^ibm-etcd-//')
  echo "Deleting $etcd serviceaccount"
  kubectl delete serviceaccount "ibm-etcd-${instance}-ibm-etcd-serviceaccount"
  kubectl delete rolebinding "ibm-etcd-${instance}-ibm-etcd-rolebinding"
  kubectl delete role "ibm-etcd-instance-ibm-etcd-role"
done

# Couchdb instances are not deleted by middleware operator
echo "Deleting couchdb helm charts"
for couch in $(helm ls --tls -a | awk '{print $1}' | grep '^couchdb-')
do
  echo "Deleting $couch"
  helm delete --tls --purge $couch
done

dchart=$(helm ls --tls -a | awk '{print $1}' | grep '^isc-openwhisk-openwhisk$')
if [ "X$dchart" != "X" ]; then
  echo "Deleting openwhisk chart as its not removed"
  helm delete --tls --purge isc-openwhisk-openwhisk
fi

dchart=$(helm ls --tls -a | awk '{print $1}' | grep '^ibm-dba-ek$')
if [ "X$dchart" != "X" ]; then
  echo "Deleting elastic chart as its not removed"
  helm delete --tls --purge ibm-dba-ek
fi

echo "Delete deployments:"
kubectl delete deploy -lplatform=isc
echo "Delete secrets:"
kubectl delete secret -lplatform=isc
echo "Delete configmaps:"
kubectl delete configmap -lplatform=isc
echo "Delete services:"
kubectl delete service -lplatform=isc
echo "Delete pvc:"
kubectl delete pvc -lplatform=isc

### Delete PVC for etcd
echo "Deleting pvc for ibm-etcd:"
for pvc in $(kubectl get pvc -o name|grep 'persistentvolumeclaim/data-ibm-etcd-')
do
  kubectl delete $pvc
done

### Delete PVC for Elastic
echo "Deleting pvc for ibm-dba-ek:"
for pvc in $(kubectl get pvc -o name|grep 'persistentvolumeclaim/data-ibm-dba-ek-')
do
  kubectl delete $pvc
done

echo "Deleting pvc for couchdb:"
for pvc in $(kubectl get pvc -o name|grep 'persistentvolumeclaim/database-storage-')
do
  kubectl delete $pvc
done

echo "Delete pvc for minio:"
for pvc in $(kubectl get pvc -o name|grep 'persistentvolumeclaim/export-ibm-minio-ow-minio-ibm-minio-')
do
  kubectl delete $pvc
done
if [ "X$ALL" == "Xyes" ]; then
  echo "Delete platform secret:"
  kubectl delete secret platform-secret-default
  echo "Delete default ingress TLS secret:"
  kubectl delete secret isc-ingress-default-secret 
fi
