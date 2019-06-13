# Jenkins X Serverless

## What

* Tekton
* Jenkins X Serverless
* Jenkins X Pipelines

## Commands

### Create Cluster

```bash
jx create cluster gke \
    --cluster-name jx-rocks \
    --project-id $PROJECT \
    --region us-east1 \
    --machine-type n1-standard-2 \
    --min-num-nodes 1 \
    --max-num-nodes 2 \
    --default-admin-password=admin \
    --default-environment-prefix jx-rocks \
    --git-provider-kind github \
    --batch-mode
```

### Install JX

Where Project, is Gcloud Project ID.

Requires `docker-registry gcr.io`, else it doesn't work.

```bash
jx install \
    --provider $PROVIDER \
    --external-ip $LB_IP \
    --domain $DOMAIN \
    --default-admin-password=admin \
    --ingress-namespace $INGRESS_NS \
    --ingress-deployment $INGRESS_DEP \
    --default-environment-prefix tekton \
    --git-provider-kind github \
    --namespace ${INSTALL_NS} \
    --prow \
    --docker-registry gcr.io \
    --docker-registry-org $PROJECT \
    --tekton \
    --kaniko \
    -b
```

## Notes

* `jx create cluster gke` cannot use kubernetes server version flag
    * it somehow sets an empty `--machineType` flag instead
* `jx install --tekton --prow` requires `--dockerRegistry` to be set
* `jx install --tekton --prow` can be install multiple times in the same cluster
    * to differentiate, set different namespace (which becomes part of the domain)
    * might need to update webhooks incase env's already existed
* two jx serverless installs, and now `jx get build logs` doesn't work
    * `error: no Tekton pipelines have been triggered which match the current filter`
