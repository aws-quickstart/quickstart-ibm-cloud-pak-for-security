#! /bin/bash

########################################################################
#                                                                      #
#  Destroys all resources prior to deleting CloudFormation Stack       #
#                                                                      #
#                                                                      #
#  Contributors:                                                       #
#  Tyler Stednara/IBM - Cloud Pak Acceleration Team                    #
#  Andrew Campagna/IBM - Cloud Pak Acceleration Team                   #
#                                                                      #
#  See README.md for guide.                                            #
#                                                                      #
########################################################################

cd ibm

./openshift-install destroy cluster \
--dir=installDir \
--log-level=info

aws ssm put-parameter \
    --name $2"_CleanupStatus" \
    --type "String" \
    --value "READY" \
    --overwrite