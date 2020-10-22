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

dir="$(dirname $0)"
oldVersion="1300"
newVersion="1400"
appName='car'
jobName='car-migration'
imageName='isc-car'
configname="car-version"
FORCE=0
START=0
CHECK=0

getCM() {
  kubectl get configmap $configname -o jsonpath="{.data['version\.cfg']}" 2>/dev/null 
}

createCM() {
  ver="$1"
  ex=$(kubectl get configmap $configname -o name 2>/dev/null)
  if [ "X$ex" != "X" ]; then
    if [ $FORCE -eq 0 ]; then
       echo "ERROR: configmap $configname already exists"
       exit 1
    fi
    kubectl delete configmap $configname --ignore-not-found=true
  fi
  kubectl create configmap $configname --from-literal=version.cfg=$ver
}

checkJob() {
  blocking="$1"
  
  jobExists=$(kubectl get job $jobName -o name 2>/dev/null)
  if [ -z "$jobExists" ]; then
     exit 0
  fi
  
  completed=0
  failed=$(kubectl get job $jobName -o jsonpath='{.status.failed}' 2>/dev/null)
  succeeded=$(kubectl get job $jobName -o jsonpath='{.status.succeeded}' 2>/dev/null)

  if [ "X$succeeded" == "X1" ]; then
     echo "INFO: Upgrade for CAR has been completed successfully"
     FORCE=1
     createCM $newVersion
     kubectl delete pod -l name=$appName --ignore-not-found=true
     exit 0
  fi

  if [ "X$failed" != "X" ]; then
     echo "ERROR: job $jobName has failed"
     echo "Log output:"
     kubectl logs $(kubectl get pod -ljob-name=$jobName)
     exit 1
  fi

  if [ "X$blocking" == "Xfalse" ]; then
# continue waiting
     exit 2
  fi
}

startJOB() {
  arangohost=$(kubectl get deployment ${appName} -o 'jsonpath={.spec.template.spec.containers[0].env[?(@.name=="ARANGO_HOST")].value}')
  img=$(kubectl get deployment ${appName} -o 'jsonpath={.spec.template.spec.containers[0].image}')
  cat $dir/job/${appName}.yaml |\
   sed -e "s!IMAGENAME!$img!" -e "s|ARANGOHOST|$arangohost|" |\
   kubectl apply -f -
}

startUpgrade() {
  kubectl delete job $jobName --ignore-not-found=true
  kubectl delete pod -ljob-name=$jobName --ignore-not-found=true

  cv=$(getCM)
  case "X$cv" in
    X$newVersion)
     if [ $FORCE -eq 0 ]; then
       echo "INFO: the $configname has been already updated"
       exit 0
     fi
     createCM $oldVersion
     startJOB
     return
     ;;
    X$oldVersion)
     startJOB
     return
     ;;
    X)
     createCM $oldVersion
     startJOB
     return
     ;;
    *)
     echo "ERROR: the configmap $configname is in invalid state"
     exit 1
     ;;
  esac
}

usage() {
cat << "EOF"
Usage: postUpgrade.sh [ args ]
where args may be
no arguments or -force: start the upgrade and wait completion
-start [ -force ]: start the upgrade
-check: check upgrade completion
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
    -start)
      START=1
      ;;
    -check)
      CHECK=1
      ;;
    *)
      echo "Invalid argument: $arg"
      usage
      exit 1
  esac
done

if [ $START -eq 1 ]; then
  startUpgrade
  exit 0
fi
if [ $CHECK -eq 1 ]; then
  checkJob "false"
  exit 0
fi

startUpgrade
while sleep 30
do
  checkJob "true"
done
exit 0
