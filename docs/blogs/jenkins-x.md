# Jenkins X

## Choose your distribution

## GKE via JX binary

```bash
export JX_TOOL_PSW=ZfwYM0odeI5W41GGzXgGqFmP
export MACHINE_TYPE=n1-standard-2
export GKE_ZONE=europe-west4-a
export K8S_VERSION=1.11.2-gke.18
export GKE_NAME=joostvdg-jx-nov18-1
export GIT_API_TOKEN=
export PROJECT_ID=
```

```bash
jx create cluster gke \
    --cluster-name=${GKE_NAME} \
    --default-admin-password=${JX_TOOL_PSW} \
    --domain='kearos.net' \
    --git-api-token=${GIT_API_TOKEN} \
    --git-username='joostvdg' \
    --no-tiller \
    --project-id=${PROJECT_ID} \
    --prow=true  \
    --vault=true \
    --zone=${GKE_ZONE} \
    --machine-type=${MACHINE_TYPE} \
    --labels='owner=jvandergriendt,purpose=practice,team=ps' \
    --skip-login=true \
    --max-num-nodes='3' \
    --min-num-nodes='2' \
    --kubernetes-version=${K8S_VERSION} \
    --batch-mode=true
```

```bash
--skip-installation=false: Provision cluster only, don't install Jenkins X into it
--skip-login=false: Skip Google auth if already logged in via gcloud auth
```