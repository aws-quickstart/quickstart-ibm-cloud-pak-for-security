# CP4S QuickStart

#### Required items

- RedHat pull-secret
- IBM private registry (cp.icr.io) password (Entitlement key)
- Key pair for EC2

**Where can I get my RedHat pull-secret from?**
Visit: https://cloud.redhat.com/openshift/install/aws/installer-provisioned

**Where can I get my IBM private registry password?**
Visit: https://myibm.ibm.com/products-services/containerlibrary

#### Part 1. Setup resources

**Set-up EC2 Key pair**
From your AWS dashboard (ensure you're in the correct region)
Find Services: EC2 > Network & Security > Key Pairs > Create key pair

**How do I use my key pair to SSH into the BootNode instance?**
When you generate a key pair you should recieve a *\*.pem* file containing the private key. With this you can simply use the *-i* option with *ssh* to login.

```bash
ssh -i path_to_key/key.pem ec2-user@BootNode_instance_ip
```

Where the *path_to_key/key.pem* is where you downloaded your private key and *BootNode_instance_ip* is the public IPv4 address of the BootNode instance.

#### Part 2. Stack deployment

There are 3 stacks involved with this QuickStart.

1. Root stack - Takes in user input from parameters
2. VPC stack - Creates VPC infrastructure for OpenShift
3. Pak stack - Creates EC2 instance, downloads resources, and runs bootstrap.sh

#### Part 3. Bootstrap

The *bootstrap.sh* script is essentially the entrypoint for the QuickStart deployment of the product. It's responsible for installing all dependecies onto the BootNode, modifying permissions and file system, and finally calling the installation of the product.

#### Part 4. Installation of the product

When bootstrapping is complete all depndencies needed to run automation to deploy the desired product should be in place. From here the bootstrap will run the products automation to deploy. First OpenShift is installed using the openshift-install IPI followed by CP4S using in-house built automation.

#### Part 5. Logging

Various log files are generated and it's good to have a reference on where/what they are.

**/s3_logs.txt** - Initial CloudFormation S3 Bucket copy of resources to run the QuickStart

**/bootstrap_logs.txt** - STDOUT from the bootstrap.sh script

**/ibm/i.log** - STDOUT from the install of the product

**/ibm/openshift_install.log** - STDOUT of the openshift-install IPI

**/ibm/cp4s_install.log** - STDOUT of the CP4S install scripts

**/ibm/cp4s_install_logs.log** - STDOUT of the CP4S install scripts
