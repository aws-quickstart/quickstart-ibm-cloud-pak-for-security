#! /bin/bash

########################################################################
#                                                                      #
#  Configures and starts logging.                                      #
#  Calls install.py script to deploy OpenShift Container Platform,     #
#+ IBM Common Services, and Cloud Pak for Security.                    #
#                                                                      #
#  Version: 1.0-beta                                                   #
#  OpenShift Version: 4.4.21                                           #
#  IBM Common Services Version: 3.2.4                                  #
#  Helm chart entitled/ibm-security-foundations-prod Version: 1.0.7    #
#  Helm chart entitled/ibm-security-solutions-prod Version: 1.0.7      #
#  Cloud Pak for Security Version: 1.3.01                              #
#                                                                      #
#  Contributors:                                                       #
#  Tyler Stednara/IBM - Cloud Pak Acceleration Team                    #
#  Andrew Campagna/IBM - Cloud Pak Acceleration Team                   #
#                                                                      #
#  See README.md for guide.                                            #
#                                                                      #
#                                                                      #
#  QA TESTING BOOTSTRAP - DO NOT USE FOR PRODUCTION                    #
########################################################################

SCRIPT="${0##*/}"
echo "Bootstrap started... ${SCRIPT}"

#  Install command-line JSON program called jq
brew install jq

#  Install command-line YAML program called yq
brew install yq

#  Install certauth module
pip3 install certauth

#  Deploy installation of OpenShift, IBM Common Services, and Cloud Pak for Security
bash install.sh
