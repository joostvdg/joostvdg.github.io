title: OpenShift 3.11 on GCP (Minimal)
description: Installing RedHat OpenShift 3.11 on GCP in the most minimal way
Hero: OpenShift 3.11 on GCP - Minimal

# RedHat OpenShift 3.11 on GCP - Minimal

Why am I writing this guide? Well, to document my own steps taken. Also, I think the guide from Google [^1] is to abstract to be useful, and the guide from RedHat[^2] contains such number of options and digressions its hard to focus on what you require.

!!! note
    This guide is written early March 2020, using `jx` version `2.0.1212` and OpenShift version `v3.11.170`.

## Pre-requisites

What do we need to get started?

* active GCP account with billing enabled
* GCP project
* gcloud tool installed
* terraform `0.12`+  installed
* active RedHat account
    * which hasn't used its 60 day trial license of OpenShift yet

## Process

* create Terraform configuration for GCP VM's
* create the VM's in GCP with RedHat Enterprise Linux v7
* install OpenShift pre-requisites on each VM
* create OpenShift Ansible configuration
* install OpenShift via Ansible

## GCP Terraform

### What Do We Need

Having gone through the process of installing RHOS 3.11 once, I ran into an issue. The documentation makes it seems you only need `master` nodes, `compute` nodes and VM's for `etcd` (can be the same as `Master`). However, you also need at least one `infra` node.

You can opt for a HA cluster, with three `master` nodes, or a single `master` node for a test cluster. I'm going with the latter.
The `master` node will house the Kubernetes Control Plane, the `infra` node will house the OpenShift infra.
As we won't have cluster autoscaling - a bit fancy for a manual test cluster - we have to make sure the machines are beefy to take the entire workload.

Another thing we need for OpenShift, is having DNS that works between the nodes. For example, you should be able to say `node1` and end up at the correct machine. Due to GCP networking, this internal DNS works out-of-the-box for any machine with our network/project. 

!!!! important
    Our machines need to have unique names!

So I ended up with the following:

* 1x  `master` node -> `n1-standard-8`: 8 cores, 30gb mem
* 1x `infra` node ->  `n1-standard-8`: 8 cores, 30gb mem
* 2x `compute` node -> `n1-standard-4`: 4 cores, 15gb mem (each)

!!! caution
    For a first iteration, I've ignored creating a separate VPC and networking configuration.
    This to avoid learning too many things at once. You probably do want that for a more secure cluster.
    Read [the medium effort guide](/openshift/rhos311-gcp-medium/) in case you want to.

### VM Image

Of course, if you want to run RedHat OpenShift Enterprise (RHOS), your VM's need to run a RedHat Enterprise Linux distribution(RHEL).

In order to figure out which vm images are currently available, you can issue the following command via `gcloud`.

```bash
gcloud compute images list --project rhel-cloud
```

Which should give a response like this:

```bash
NAME                                                  PROJECT            FAMILY                            DEPRECATED  STATUS
rhel-6-v20200205                                      rhel-cloud         rhel-6                                        READY
rhel-7-v20200205                                      rhel-cloud         rhel-7                                        READY
rhel-8-v20200205                                      rhel-cloud         rhel-8                                        READY
```

For the VM image in our Terraform configuration, we will use the `NAME` of the image.
For RHOS 3.11, RedHat strongly recommends using RHEL 7, so we use `rhel-7-v20200205`.

### Terraform Configuration

We have the following files:

* **main.tf**: contains the main configuration for the provider, in this case `google`
* **variables.tf**: the variables and their defaults
* **master-node.tf**: the `master` node configuration
* **infra-node.tf**: the `infra` node configuration
* **compute-nodes.tf**: the two `compute` node configurations

!!! important
    We need to ssh into the VMs. To make this easy, I'm using a local `ssh` key and make sure it is configured on the VMs.
    See ` ssh-keys = "joostvdg:${file("~/.ssh/id_rsa.pub")}"` in the `metadata` block.

    The first part of the value  `joostvdg` is my desired username. Change this if you want.

??? example "main.tf"

    ```json
    terraform {
        required_version = "~> 0.12"
    }

    provider "google" {
        version   = "~> 2.18.1"
        project   = var.project
        region    = var.region
        zone      = var.main_zone
    }
    ```

??? example "variables.tf"

    ```json
    variable "project" { }

    variable "name" {
        default     = "jx-openshift-311"
    }

    variable "compute_machine_type" {
        default = "n1-standard-4"
    }

    variable "master_machine_type" {
        default = "n1-standard-8"
    }

    variable "vm_image" {
        default ="rhel-7-v20200205"
    }

    variable "master_zone" {
        default = "europe-west4-a"
    }
    ```

??? example "master-node.tf"

    ```json
    resource "google_compute_instance" "master" {
        name         = "master"
        machine_type = var.master_machine_type
        zone         = var.master_zone
        allow_stopping_for_update = true

        boot_disk {
            initialize_params {
                image = var.vm_image
                size = 100
            }
        }

        // Local SSD disk
        scratch_disk {
            interface = "SCSI"
        }

        network_interface {
            network = "default"
            # network_ip = google_compute_address.masterip.address
            access_config {
                # external address
            }
        }

        metadata = {
            ssh-keys = "joostvdg:${file("~/.ssh/id_rsa.pub")}"
        }
        service_account {
            scopes = [
                "https://www.googleapis.com/auth/compute",
                "https://www.googleapis.com/auth/devstorage.read_only",
                "https://www.googleapis.com/auth/logging.write",
                "https://www.googleapis.com/auth/monitoring",
                "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
                "https://www.googleapis.com/auth/cloud-platform"
            ]
        }
    }
    ```


??? example "infra-node.tf"

    ```json
    resource "google_compute_instance" "infra1" {
        name         = "infra1"
        machine_type = var.master_machine_type
        zone         = var.master_zone
        allow_stopping_for_update = true

        boot_disk {
            initialize_params {
                image = var.vm_image
                size = 100
            }
        }

        // Local SSD disk
        scratch_disk {
            interface = "SCSI"
        }

        network_interface {
            network = "default"
            # network_ip = google_compute_address.node2ip.address
            access_config {
                # external address
            }
        }
        metadata = {
            ssh-keys = "joostvdg:${file("~/.ssh/id_rsa.pub")}"
        }

        service_account {
            scopes = [
                "https://www.googleapis.com/auth/compute",
                "https://www.googleapis.com/auth/devstorage.read_only",
                "https://www.googleapis.com/auth/logging.write",
                "https://www.googleapis.com/auth/monitoring",
                "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
                "https://www.googleapis.com/auth/cloud-platform"
            ]
        }
    }
    ```

??? example "compute-node.tf"

    ```json
    resource "google_compute_instance" "node1" {
        name         = "node1"
        machine_type = var.compute_machine_type
        zone         = var.master_zone
        allow_stopping_for_update = true

        boot_disk {
            initialize_params {
                image = var.vm_image
                size = 100
            }
        }

        // Local SSD disk
        scratch_disk {
            interface = "SCSI"
        }

        network_interface {
            network = "default"
            # network_ip = google_compute_address.node1ip.address
            access_config {
                # external address
            }
        }
        metadata = {
            ssh-keys = "joostvdg:${file("~/.ssh/id_rsa.pub")}"
        }

        service_account {
            scopes = [
                "https://www.googleapis.com/auth/compute",
                "https://www.googleapis.com/auth/devstorage.read_only",
                "https://www.googleapis.com/auth/logging.write",
                "https://www.googleapis.com/auth/monitoring",
                "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
                "https://www.googleapis.com/auth/cloud-platform"
            ]
        }
    }

    resource "google_compute_instance" "node2" {
        name         = "node2"
        machine_type = "n1-standard-4"
        zone         = var.master_zone
        allow_stopping_for_update = true

        boot_disk {
            initialize_params {
                image = var.vm_image
                size = 100
            }
        }

        // Local SSD disk
        scratch_disk {
            interface = "SCSI"
        }

        network_interface {
            network = "default"
            # network_ip = google_compute_address.node2ip.address
            access_config {
                # external address
            }
        }
        metadata = {
            ssh-keys = "joostvdg:${file("~/.ssh/id_rsa.pub")}"
        }

        service_account {
            scopes = [
                "https://www.googleapis.com/auth/compute",
                "https://www.googleapis.com/auth/devstorage.read_only",
                "https://www.googleapis.com/auth/logging.write",
                "https://www.googleapis.com/auth/monitoring",
                "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
                "https://www.googleapis.com/auth/cloud-platform"
            ]
        }
    }
    ```

We should end up with four nodes:

1. `master`
1. `infra`
1. `node1`
1. `node2`

### Create VMs with Terraform

```bash
terraform init
```

```bash
terraform validate
```

```bash
terraform plan -out plan.out
```

```bash
terraform apply "plan.out"
```

### Verify VMs

Before we can install the OpenShift pre-requisites, we verify if the VMs are ready to use.
To verify the VMs, we will do the following:

1. confirm we can `ssh` into each VM
1. confirm we can use `sudo` in each VM
1. confirm the infra node can call each VM by name (`infra`, `master`, `node1`, `node2`)
1. confirm the infra node can `ssh` into all VMs (including itself!)

### SSH into VMs

There are several ways to ssh into the VMs. You can do so via `ssh` installed on your machine, you can do so via the GCP console.
I will use another option, using the `gcloud` CLI, using the ssh key I've configured in Terrafom (` ssh-keys = "joostvdg:${file("~/.ssh/id_rsa.pub")}"`).

Why am I using this form?
Well, it makes it easier to reason about which machine I ssh into, as I can use the VM *name*.

```bash
# your google project id
PROJECT_ID=
```

```bash
# the google zone the vm is in, for example: europe-west-4a
VM_ZONE=
```

```bash
gcloud beta compute --project $PROJECT_ID ssh --zone $VM_ZONE "node1"
```

Confirm you can ssh into each VM by changing the zone/name accordingly.

### Confirm Sudo

Our ssh user isn't root - as it should be - so we need to use sudo for some tasks.

Confirm sudo works;

```bash
sudo cat /etc/locale.conf
```

### Confirm Local DNS

The OpenShift installation process and later OpenShift itself, relies on *local dns*.
This means, it assumes if there's a node called `master`, it can do `ssh master` and it works.

In GCP, DNS works within a Project by default. So assuming all the VMs  are within the same project this works out-of-the-box.
But, to avoid any surprises later, confirm it.

```bash
[joostvdg@master ~]$ ping master
PING master.c.MY_PROJECT_ID.internal (10.164.0.49) 56(84) bytes of data.
64 bytes from master.c.MY_PROJECT_ID.internal (10.164.0.49): icmp_seq=1 ttl=64 time=0.041 ms
64 bytes from master.c.MY_PROJECT_ID.internal (10.164.0.49): icmp_seq=2 ttl=64 time=0.094 ms
```

```bash
[joostvdg@master ~]$ ping node1
PING node1.c.MY_PROJECT_ID.internal (10.164.0.50) 56(84) bytes of data.
64 bytes from node1.c.MY_PROJECT_ID.internal (10.164.0.50): icmp_seq=1 ttl=64 time=1.13 ms
64 bytes from node1.c.MY_PROJECT_ID.internal (10.164.0.50): icmp_seq=2 ttl=64 time=0.343 ms
```

!!! note
    As you might expect, `MY_PROJECT_ID` will be the Google project Id where your VMs are.
    I've hidden that as a safety precaution, confirm it looks correct!

### Infra Node can SSH into others

For the OpenShift installation, our installation VM has to be able to ssh into every other VM[^3]. This doesn't work out of the box.

!!! warning
    I used my own keys here directly, because this is a temporary project only used by me.
    If your usecase is different, and you're not sure how to proceed, consult a security professional!

We have to create the `ssh` public key on every node for our ssh user (in my case, `joostvdg`) and the private also for our installation host (for example, `infra`).

This might not be a security best practice, but I did this by copying over my `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub` to each node's user home (`/home/joostvdg/.ssh/`).

!!! important 
    Once you've done this, ssh into the `infra` node, and confirm it can ssh to every other node.
    
    * `ssh joostvdg@node1`
    * `ssh joostvdg@node2`
    * `ssh joostvdg@master`
    * `ssh joostvdg@infra` -> YES, you have to ssh into yourself!

    This is important, because through this step, you can accept the prompt so the installation process can run ***unattended***!

Make sure to set the correct permissions to the `id_rsa` file via `sudo chmod 0400 ~/.ssh/id_rsa`!

### Fix Locale

I kept running into a `locale` warning, about using one that didn't exist on the VM.

If you want to get rid of this, you can change the `/etc/locale.conf` file.

```bash
sudo vim /etc/locale.conf
```

Make sure it looks like this.

```bash
LANG="en_US.UTF-8"
LC_CTYPE="en_US.UTF-8"
LC_ALL=en_US.UTF-8
```

## OpenShift Installation Pre-requisites

Before we can install OpenShift, we have to bring our nodes into a certain state.

We will do the following:

* register our VMs to RedHat
* register our VMs as part of our OpenShift Enterprise license
* configure `yum` for the installation process
* install and configure `docker` for the installation process
* login to the RedHat docker registry

### Register VMs

Please note, these steps have to be done on every VM!

If you use something like `iterm2`, you can save yourself some time by having four parallel sessions for each VM.
You do this by creating a split window (`control` + `command`  + `D`), and once logged in, create a shared `cursor` via `command` + `shift`+ `i`.

We start by installing the subscription manager.

```bash
sudo yum install subscription-manager -y
```

We then register our instance with our RedHat account.

```bash
sudo subscription-manager register --username=<user_name> --password=<password>
```

```bash
sudo subscription-manager refresh
```

Find the OpenShift subscription and you should get a single option. Use the id as the `--pool` in the next command.

```bash
sudo subscription-manager list --available --matches '*OpenShift*'
```

```bash
sudo subscription-manager attach --pool=?
```

### Configure Yum Repos

There's commands to disable each individual repository, but I found it easier to disable all, and then add those we need after.

```bash
sudo subscription-manager repos --disable="*"
sudo yum repolist
```

```bash
sudo yum-config-manager --disable \*
```

### Install Default Packages

As we've disable all of our `yum` repositories, we first add the once we need.

```bash
sudo subscription-manager repos \
    --enable="rhel-7-server-rpms" \
    --enable="rhel-7-server-extras-rpms" \
    --enable="rhel-7-server-ose-3.11-rpms" \
    --enable="rhel-7-server-ansible-2.8-rpms"
```

Once we have a set of usable `yum` repositories, we can then install all the packages we need.

```bash
sudo yum install wget git net-tools bind-utils yum-utils iptables-services bridge-utils bash-completion kexec-tools sos psacct openshift-ansible atomic python-docker-py docker device-mapper-libs device-mapper-event-libs -y
```

!!! note
    There have been some bugs in the past, related to docker versions. If, for some reason, you have to downgrade to a known working version of docker, this is a way of doing that.

    ```bash
    sudo yum downgrade docker-rhel-push-plugin-1.13.1-75.git8633870.el7_5  docker-client-1.13.1-75.git8633870.el7_5 docker-common-1.13.1-75.git8633870.el7_5 docker-1.13.1-75.git8633870.el7_5
    ```

Once we have all the packages installed, make sure they're updated and then we reboot our machines.

```bash
sudo yum update -y
sudo reboot
```

### Install Docker

I sneaked the docker packages into the previous installation command already, so we only have to enable/configure docker at this point.

If you want to configure more details, such as where docker stores its volumes/data, please take a look at RedHat's installation guide[^4].

```bash
sudo systemctl start docker.service
sudo systemctl enable docker.service
```

To confirm docker works:

```bash
sudo systemctl status docker.service
```

Make sure that on each node, your default user can use docker.

```bash
sudo setfacl --modify user:joostvdg:rw /var/run/docker.sock
```

### Setup Registry Authentication

The images for OpenShift come from RedHat's own docker registry.
We have to login, before we can use those images[^5].

So use your RedHat account credentials.

```bash
docker login https://registry.redhat.io -u <USER> -p <PASS>
```

## Create Ansible Inventory File

OpenShift comes with two ways of installing, via docker or via Ansible.
The fun part, the docker container will use Ansible to install anyway.

So no matter which way you will install OpenShift, you need to create a InventoryFile.

RedHat has a couple of example files[^6], but these aren't complate - you need `infra` nodes as well!

### Important Configuration Items

Bellow follow some variables I recommend configuring, for information, consult the RedHat documentation[^7].

* **OSEv3:children**:  the types of nodes to be configured
* **OSEv3:vars**: variables for the installation process
    * **ansible_become**: set the `True` if Ansible can not run as root
    * **ansible_ssh_user**: if Ansible cannot run as root, as which user should it ssh into the other nodes
    * **oreg_url**: template for the docker images used by OpenShift, this should be `registry.access.redhat.com/openshift3/ose-${component}:${version}`, it will be used by components such as ETCD, Kubelet and so on
    * **oreg_auth_user**: your RedHat account username
    * **oreg_auth_password**: your RedHat account password
    * **openshift_cloudprovider_kind**: the kind of cloud provider where RHOS is installed on, in the case of GCP its `gce` (don't ask me)
    * **openshift_gcp_project**: is required to allow OpenShift the ability to create local disks in GCP for PersistentVolumes, should be your Google Project ID
    * **os_firewall_use_firewalld**: use `firewalld` instead of iptables, seems to work better and is recommended by the RHOS 3.11 install guide (as of 2018+ I believe)
* Node definitions (`etcd`, `masters`, `nodes`): instructs Ansible which machine should be configured and with what

!!! important
    If you use an external LoadBalancer, also set `openshift_master_cluster_public_hostname`.

    > This variable overrides the public host name for the cluster, which defaults to the host name of the master. If you use an external load balancer, specify the address of the external load balancer. 

### Example Inventory File

```yaml
# Create an OSEv3 group that contains the masters, nodes, and etcd groups
[OSEv3:children]
masters
nodes
etcd

# Set variables common for all OSEv3 hosts
[OSEv3:vars]
# SSH user, this user should allow ssh based auth without requiring a password
ansible_ssh_user=joostvdg
# If ansible_ssh_user is not root, ansible_become must be set to true
ansible_become=true

openshift_deployment_type=openshift-enterprise
# This is supposed to be a template, do not change!
oreg_url=registry.access.redhat.com/openshift3/ose-${component}:${version}
oreg_auth_user="YOUR_RED_HAT_USERNAME"
oreg_auth_password="YOUR_RED_HAT_PASSWORD"
openshift_cloudprovider_kind=gce
openshift_gcp_project="YOUR_GOOGLE_PROJECT_ID"
openshift_gcp_prefix=joostvdgrhos
# If deploying single zone cluster set to "False"
openshift_gcp_multizone="False"

openshift_master_api_port=443
openshift_master_console_port=443
os_firewall_use_firewalld=True
# Enable if you want to use httpd for managing additional users
# openshift_master_identity_providers=[{'name': 'htpasswd_auth', 'login': 'true', 'challenge': 'true', 'kind': 'HTPasswdPasswordIdentityProvider'}]
# openshift_master_htpasswd_users={'administrator': 'password'}

# host group for masters
[masters]
master.c.<YOUR_GOOGLE_PROJECT_ID>.internal

# host group for etcd
[etcd]
master.c.<YOUR_GOOGLE_PROJECT_ID>.internal

# host group for nodes, includes region info
[nodes]
master.c.<YOUR_GOOGLE_PROJECT_ID>.internal openshift_node_group_name='node-config-master'
node1.c.<YOUR_GOOGLE_PROJECT_ID>.internal openshift_node_group_name='node-config-compute'
node2.c.<YOUR_GOOGLE_PROJECT_ID>.internal openshift_node_group_name='node-config-compute'
infra1.c.<YOUR_GOOGLE_PROJECT_ID>.internal openshift_node_group_name='node-config-infra'
```

!!! Important

    Make sure to replace the `YOUR_...` placeholder values with your actual values. 

    * `oreg_auth_user` (YOUR_RED_HAT_USERNAME)
    *  `oreg_auth_password` (YOUR_RED_HAT_PASSWORD)
    *  `YOUR_GOOGLE_PROJECT_ID`

## Install RHOS 3.11 with Ansible

There are two ways to install RHOS 3.11. Via Ansible directly[^8], or via Ansible in a container[^9].
As our nodes are configured according to what the Ansible installation requires, there's no need to rely on the container.

Additionally, if you want to use the container way, you have to make sure the container can use the same DNS configuration as the nodes can themselves. I've not done this, so this would be on you!

### Final Preparations

Ansible creates a fact file. It does so at a location a non-root user doesn't have access to.

So it is best to create this file upfront - on every node - and chown it to the user that will do the ssh/Ansible install.

```bash
sudo mkdir -p /etc/ansible/facts.d
sudo chown -R joostvdg /etc/ansible/facts.d
```

### Install OpenShift

We install OpenShift via two scripts, `playbooks/prerequisites.yml` and `playbooks/deploy_cluster.yml`.
When we install `openshift-ansible atomic` via yum, we also get the Ansible playbooks for OpenShift.

Either go into the directory of those files, or use the entire path;

```bash
cd /usr/share/ansible/openshift-ansible
```

Execute OpenShift Pre-requisites script:

```bash
ansible-playbook -i /home/joostvdg/inventoryFile /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml
```

If all is successful, it will end with all actions in green and `finished successfully` (or similar) .
Once this is the case, execute OpenShift Installation:

```bash
ansible-playbook -i /home/joostvdg/inventoryFile  /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml
```

Now you should be able to run `oc get nodes` on the installation node.

## Read More

* https://access.redhat.com/documentation/en-us/reference_architectures/2018/html-single/deploying_and_managing_openshift_3.9_on_google_cloud_platform/index#google_cloud_platform_networking
* https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html-single/installing_clusters/index#what-s-next
* https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html/installing_clusters/install-config-install-prerequisites#prereq-network-access
* http://crunchtools.com/hackers-guide-to-installing-openshift-container-platform-3-11/
* https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html-single/installing_clusters/index#install-config-example-inventories
* https://docs.openshift.com/container-platform/3.11/admin_guide/manage_users.html
* https://itnext.io/explore-different-methods-to-build-and-push-image-to-private-registry-with-tekton-pipelines-5cad9dec1ddc

## References

[^1]: https://cloud.google.com/solutions/partners/openshift-on-gcp
[^2]: https://access.redhat.com/documentation/en-us/reference_architectures/2018/html/deploying_and_managing_openshift_3.9_on_google_cloud_platform/
[^3]: https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html/installing_clusters/install-config-install-host-preparation#ensuring-host-access
[^4]: https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html/installing_clusters/install-config-install-host-preparation#configuring-docker-storage
[^5]: https://access.redhat.com/RegistryAuthentication
[^6]: https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html-single/installing_clusters/index#install-config-example-inventories
[ ^7]: https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html/installing_clusters/install-config-configuring-inventory-file#configuring-cluster-variables
[^8]: https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html/installing_clusters/install-running-installation-playbooks#running-the-advanced-installation-rpm
[^9]: https://access.redhat.com/documentation/en-us/openshift_container_platform/3.11/html/installing_clusters/install-running-installation-playbooks#running-the-advanced-installation-containerized