---
tags:
  - TKG
  - TAP
  - TANZU
  - SSH
---

title: Git access with SSH
description: TAP Build profile with SSH access for FluxCD

# Git access with SSH

We recommend having access to your git server via SSH.

You can take a look at TAP's [official docs](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.3/tap/GUID-scc-git-auth.html) or continue with my guide below.

!!! Warning "Using Gitea as example"
    This guide takes Gitea as example, although it should work for any of the major Git servers (GitHub, GitHub Enterprise, GitLab, Bitbucket).

    To install Gitea, [look here](/tanzu/tap/gitea/).

## Collect Known hosts

Run `netshoot` or some other container with `ssh` tools inside the cluster.

```sh
kubectl run tmp-shell --rm -i --tty --image ${HARBOR_HOSTNAME}/test/netshoot:v0.9 --namespace default -- /bin/bash
```

```sh
ssh-keyscan gitea-ssh.gitea.svc.cluster.local > gitea-known-hosts.txt
```

The contents of this file go into your `GIT_SSH_KNOWN_HOSTS` variable.

```sh
cat gitea-known-hosts.txt
```

## Generate SSH Secret

Assuming you are using Gitea, I'll also assume the `ssh key` for Gitea is located here: `~/.ssh/gitea_id_rsa`.

```sh
export GIT_SSH_SECRET_KEY="tap-build-ssh"
export GIT_SERVER="${GITEA_HOSTNAME}"
export GIT_SSH_PUSH_KEY=$(cat ~/.ssh/gitea_id_rsa)
export GIT_SSH_PULL_KEY=$(cat ~/.ssh/gitea_id_rsa)
export GIT_SSH_PULL_ID=$(cat ~/.ssh/gitea_id_rsa.pub)
export GIT_SSH_KNOWN_HOSTS=$(cat gitea-known-hosts.txt)
```

```sh
ytt -f ytt/tap-build-ssh-key-secret.ytt.yml \
  -v secretName="$GIT_SSH_SECRET_KEY" \
  -v server="$GITEA_HOSTNAME" \
  -v sshPushKey="$GIT_SSH_PUSH_KEY" \
  -v sshPullKey="$GIT_SSH_PULL_KEY" \
  -v sshPullId="$GIT_SSH_PULL_ID" \
  -v knownHosts="$GIT_SSH_KNOWN_HOSTS" \
  > "tap-build-ssh-key-secret.yaml"
```

NOTE: which namespaces? Says `ServiceAccount configured for the workload`, but what about FluxCD?

```sh
kubectl apply -f tap-build-ssh-key-secret.yaml \
  --namespace ${TAP_DEVELOPER_NAMESPACE}
```

* Add the secret to the secrets of the SA doing the workloads
* for example, `default` in Namespace `default`

You can inspect the SA:

```sh
kubectl get sa -n default default -o yaml
```

Which will then look as follows:

```yaml
apiVersion: v1
imagePullSecrets:
- name: registry-credentials
- name: tap-registry
kind: ServiceAccount
metadata:
  creationTimestamp: "2023-01-30T10:09:54Z"
  name: default
  namespace: default
  resourceVersion: "12849738"
  uid: 2b97fa15-c681-447b-9700-85cafb6b561e
secrets:
- name: registry-credentials
- name: default-token-rxzbh
- name: tap-build-ssh
```
