title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - Setup ETCD (6/11)
hero: Setup ETCD (6/11)

# ETCD

> Kubernetes components are stateless and store cluster state in etcd. In this lab you will bootstrap a three node etcd cluster and configure it for high availability and secure remote access.

The bare minimum is to have a single `etcd` instance running. But for production purposes it is best to run etcd in HA mode.
This means we need to have three instances running that know eachother.

Again, this is not a production ready setup, as the static nature prevents automatic recovery if a node fails.

## Steps to take

* download & install etcd binary
* prepare required certificates
* create `systemd` service definition
* reload `systemd` configuration, enable & start the service

### Install script

Make sure that the local install script is on every server, you can use the `etcd.sh` script for this.

Then, make sure you're connect to all three controller VM's at the same time, for example via tmux or iterm.
For iterm:

* use `ctrl` + `shift` + `d` to open three horizontal windows
* use `ctrl` + `shift` + `i` to write output to all three windows at once
* login to each controller `gcloud compute ssh controller-?`
* `./etcd-local.sh`

## Verification

```bash
sudo ETCDCTL_API=3 etcdctl member list \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/etcd/ca.pem \
    --cert=/etc/etcd/kubernetes.pem \
    --key=/etc/etcd/kubernetes-key.pem
```

### Expected Output

```bash
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:2379
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:2379
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:2379
```
