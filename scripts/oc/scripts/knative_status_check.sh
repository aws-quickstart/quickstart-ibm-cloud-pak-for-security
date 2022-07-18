#!/bin/bash

#Waiting for the serverless operator CSV to be created
printf "\nValidating Knative Serving Installation...\n"
maxRetry=10
crd="knativeserving.operator.knative.dev/knative-serving"
namespace="knative-serving"
for ((retry=0;retry<=${maxRetry};retry++)); 
do
      DependenciesInstalled="$(oc get $crd -n $namespace -o jsonpath='{.status.conditions[0].status}')"
      DeploymentsAvailable="$(oc get $crd -n $namespace -o jsonpath='{.status.conditions[1].status}')"
      InstallSucceeded="$(oc get $crd -n $namespace -o jsonpath='{.status.conditions[2].status}')"
      Ready="$(oc get $crd -n $namespace -o jsonpath='{.status.conditions[3].status}')"
      VersionMigrationEligible="$(oc get $crd -n $namespace -o jsonpath='{.status.conditions[4].status}')"
  
      if [[ $DependenciesInstalled != "True" || $DeploymentsAvailable != "True" || $Ready != "True" || $VersionMigrationEligible != "True" ]]; then
        if [[ $retry -eq ${maxRetry} ]]; then 
          printf "\n[ERROR] Knative Serving Installation was not Complete.\n\n"
          exit 1
        else
          printf "[info] - Waiting for Knative Serving to be Installed...\n"
          sleep 60
          continue
        fi
      else
        printf "DependenciesInstalled=$DependenciesInstalled\nDeploymentsAvailable=$DeploymentsAvailable\nInstallSucceeded=$InstallSucceeded\nReady=$Ready\nVersionMigrationEligible=$VersionMigrationEligible\n"
        printf "\n[SUCCESS] Knative Serving Installation is Complete.\n\n"
        break
      fi
 done

sleep 10