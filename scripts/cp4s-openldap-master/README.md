### ICP OpenLDAP Installation

This repo contains details on steps to deploy [ICP OpenLDAP](https://github.com/ibm-cloud-architecture/icp-openldap) into ICP Common Services for AWS or Openshift.

### Deployment Steps

1. Clone the Repo

```
git clone git@github.ibm.com:security-secops/cp4s-openldap.git
```

2. Install required dependencies ( Skip if you have `Ansible` installed, tested with `2.8.4` ).

```
pip install -r requirements.txt
```

3. Update the Environment Variables in the `playbook.yaml` with:

**ICP Vars:** Contains details about the Cluster in which OpenLDAP should be deployed. These details will be used to login in the cluster and retrieving Cluster's identity management endpoints.

If Deploying OpenLDAP into an IBMCloud Cluster, `ibm_cloud_server` and `ibm_cloud_port` must also be set. This information is available in the Top Right Corner of the ICP Homepage UI, under `Profile >> Configure Client`.

**OpenLDAP Vars:** Contains details about the OpenLDAP deployment.

```
    icp:        
        console_url: ""
        ibm_cloud_server: "" # Only Applicable for IBMCloud Deployment
        ibm_cloud_port: ""   # Only Applicable for IBMCloud Deployment
        username: ""
        password: ""
        namespace: ""
    
    openldap:
        adminPassword: "isc-demo"
        initialPassword: "isc-demo"
        userlist: "isc-demo,isc-test"
```

-- The `initialPassword` parameter is used to set the default password for all users.

4. Export Tiller namespace

If installing OpenLDAP on a Cluster running CS 3.2.4 execute the following:
```
export TILLER_NAMESPACE=kube-system
```

If installing OpenLDAP on a Cluster running CS 3.4 execute the following
```
export TILLER_NAMESPACE=ibm-common-services
```

5. Install OpenLDAP with

```
ansible-playbook -i hosts playbook.yml
```
### Deploy on CP4S airgap environment

 Deploy the openldap on cp4s airgap environment using the following steps:

#### Mirror images

 Mirror the images required to the local docker registry of the bastion using the following command:

```bash
oc image mirror  docker.io/osixia/openldap:1.1.10 <local-docker-registry>:5000/library/osixia/openldap:1.1.10
```

```bash
oc image mirror  docker.io/busybox:1.3.0.1 <local-docker-registry>:5000/library/busybox:1.3.0.1
```

```bash
oc image mirror docker.io/osixia/openldap:1.1.10 <local-docker-registry>:5000/library/osixia/openldap:1.1.10
```
#### Update the values.yaml

1. Once the above images have been successfully mirrored to the local docker registry, proceed to update the path to the images in `roles/secops.ibm.icp.openldap.deploy/templates/values.yaml.j2` by replacing `docker.io` with `<local-docker-registry>:5000/library>`.

2. Update the Environment Variables in the `playbook.yaml`

3. Run the playbook:

  ```bash
    ansible-playbook -i hosts playbook.yml
  ```

### Known Limitations

This Chart release do not contain Persistent Volume. Impact: The available users are limited to the users added at installation time.
Any users included `post-intall` will not be persisted.

If wanting to add more users: 
1. Login in the Cluster
2. Delete the OpenLDAP Deployment with `helm3 delete icp-openldap -n <namespace>`. Replacing `namespace` with the namespace where you installed OpenLDAP.
3. Delete the `ICPOpenLDAP` Connection in the ICP Interface
4. Add new Users in the `playbook.yaml` definition
5. Deploy OpenLDAP
