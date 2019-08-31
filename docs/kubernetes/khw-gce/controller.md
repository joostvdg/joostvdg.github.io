title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - Controllers (7/11)
hero: Controllers (7/11)

# Controller Config

We have to configure the following:

* move certificates to the correct location
* move encryption configuration to `/var/lib/kubernetes`
* download and install binaries
  * kubectl
  * kube-apiserver
  * kube-scheduler
  * kube-controller-manager
* configure API server
  * systemd service
* configure Controller Manager
  * systemd service
* configure Scheduler
  * systemd service
  * kubernetes configuration yaml `kind: KubeSchedulerConfiguration`
* create nginx reverse proxy to enable GCE's health checks to reach each API Server instance
* configure RBAC configuration in the API server
  * via `ClusterRole` and `ClusterRoleBinding`

## Install

We have an installer script, `controller-local.sh`, which should be executed on each controller VM.

To do so, use the `controller.sh` script to upload this file to the VM's.

```bash
./controller.sh
```
