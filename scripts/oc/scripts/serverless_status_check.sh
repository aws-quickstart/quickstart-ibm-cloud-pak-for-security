#!/bin/bash

#Waiting for the serverless operator CSV to be created
printf "\nWaiting for the serverless operator CSV to be created.\n"
maxRetry=10
serverlessNamespace="openshift-serverless"
for ((retry=0;retry<=${maxRetry};retry++)); 
do
      csv="$(oc get csv -o name -n $serverlessNamespace | { grep serverless || true; })"
      if [[ -n $csv ]]; then
        status="$( oc get $csv -n $serverlessNamespace -o jsonpath='{.status.phase}')"
      fi
      if [[ $status != "Succeeded" ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
          printf "\n[ERROR] Openshift-serverless CSV was not created.\n\n"
          exit 1
        else
          sleep 60
          printf "[info] - Waiting for openshift-serverless CSV to be created.\n"
          continue
        fi
      else
        printf "\n[SUCCESS] CSV openshift-serverless is created.\n\n"
        break
      fi
 done

sleep 30