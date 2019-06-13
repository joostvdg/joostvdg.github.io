# Jenkins X Workshop


## Create Cluster

```bash
PROJECT=
NAME=ws-feb
ZONE=europe-west4
MACHINE=n1-standard-2
MIN_NODES=3
MAX_NODES=5
PASS=admin
PREFIX=ws
```

!!! Warning
    You might want to do this: (not sure why)
    ```bash
        echo "nexus:
        enabled: false
        " | tee myvalues.yaml
    ```


```bash
jx create cluster gke -n $NAME -p $PROJECT -z $ZONE -m $MACHINE \
    --min-num-nodes $MIN_NODES --max-num-nodes $MAX_NODES \
    --default-admin-password=$PASS \
    --default-environment-prefix $NAME
```

### Alternatively

!!! INFO
    Domain will get `.jx` as a prefix anyway.

```bash
JX_CLUSTER_NAME=joostvdg
JX_DOMAIN=kearos.net
JX_GIT_USER=joostvdg
JX_ORG=joostvdg
JX_K8S_REGION=europe-west4
JX_NAME=jx-joostvdg
```

```bash
JX_API_TOKEN=
JX_ADMIN_PSS=
JX_GCE_PROJECT=
```

```bash
jx create cluster gke \
    -n ${JX_NAME} \
    --exposer='Ingress' \
    --preemptible=false \
    --cluster-name="${JX_CLUSTER_NAME}" \
    --default-admin-password="${JX_ADMIN_PSS}" \
    --domain="${JX_DOMAIN}" \
    --machine-type='n1-standard-2' \
    --max-num-nodes=3 \
    --min-num-nodes=2 \
    --project-id=${JX_GCE_PROJECT} \
    --default-environment-prefix ${JX_NAME} \
    --zone="${JX_ZONE}" \
    --http='false' \
    --tls-acme='true' \
    --skip-login
```

```bash
    --prow \
    --no-tiller='true'\
        --vault='true' \
```

## Issues

* `-b` doesn't work with `--vault` as the config is empty
* `--vault='true'` doesn't work with https (cert-manager) because ` sync.go:64] Not syncing ingress jx/cm-acme-http-solver-stx47 as it does not contain necessary annotations`
** also, it seems its TLS config isn't correct for some reason
* does TLS with cert-manager actually work?
* now it doesn't actually install `cert-manager`? Whats up with that.

## Install Certmanager

### Via JX

Updates the entire ingress configuration, installs cert-mananger, certificates, replaces ingress definitions, updates webhooks, and allows you to set a different domain name.

```bash
jx upgrade ingress --cluster
```

### Manually

This does not create certificates nor does it update the ingress defintions.

```bash
kubectl create namespace cert-manager
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.6/deploy/manifests/00-crds.yaml
helm install --name cert-manager --namespace cert-manager stable/cert-manager
```

## Demo App

### Post creation

```bash
Creating GitHub webhook for joostvdg/cmg for url https://hook.jx.jx.kearos.net/hook

Watch pipeline activity via:    jx get activity -f cmg -w
Browse the pipeline log via:    jx get build logs joostvdg/cmg/master
Open the Jenkins console via    jx console
You can list the pipelines via: jx get pipelines
When the pipeline is complete:  jx get applications

For more help on available commands see: https://jenkins-x.io/developing/browsing/
```

### Promote

```bash
jx promote ${APP} --version $VERSION --env production -b
```

## Compliance

```bash
jx compliance run
```

```bash
jx compliance status
```

```bash
jx compliance logs -f
```

```bash
jx compliance delete
```

## Chartmuseum auth faillure

* uses kubernetes secret
* relies on kubernetes-secret (Jenkins) plugin
* can have trouble with special charactes
* to fix, update the kubernetes secret (used by chartmuseum and the pipeline)

## Workshop responses

* send to Alyssa & Juni
* address for sending

### Responses



### Extra requirements

* billing needs to be enabled, else you cannot create a cluster of that size
* we need to test more with windows
** without admin
** different python versions
