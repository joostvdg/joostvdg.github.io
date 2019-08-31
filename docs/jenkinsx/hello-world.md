title: Jenkins X - Hello World
description: How To Create A Hello World App With Jenkins X

# Hello World Demo

## Create GKE + Jenkins X cluster

```bash
export JX_CLUSTER_NAME=joostvdg
export JX_ENV_PREFIX=joostvdg
export JX_ADMIN_PSS=vXDzpiaVAthneXJR355J7PBT
export JX_DOMAIN=jx.kearos.net
export JX_GIT_USER=joostvdg
export JX_API_TOKEN=61edcbf6507d31b3f2fe811baa82aa6de33db001
export JX_ORG=demomon
export JX_GCE_PROJECT=ps-dev-201405
export JX_K8S_REGION=europe-west4
export JX_K8S_ZONE=europe-west4-a
export GKE_NODE_LOCATIONS=${REGION}-a,${REGION}-b
export JX_K8S_VERSION=
```

### Get supported K8S versions

```bash tab="Zonal"
gcloud container get-server-config --zone ${JX_K8S_ZONE}
```

``` bash tab="Regional"
gcloud container get-server-config --region ${JX_K8S_REGION}
```

```bash
export JX_K8S_VERSION=1.11.7-gke.4
```

### Create regional cluster w/ Domain

Currently only possible if you create a regional cluster first and then install jx.

```bash
gcloud container clusters create ${JX_CLUSTER_NAME} \
    --region ${JX_K8S_REGION} --node-locations ${GKE_NODE_LOCATIONS} \
    --cluster-version ${JX_K8S_VERSION} \
    --enable-pod-security-policy \
    --enable-network-policy \
    --num-nodes 2 --machine-type n1-standard-2 \
    --min-nodes 2 --max-nodes 3 \
    --enable-autoupgrade \
    --enable-autoscaling \
    --labels=owner=jvandergriendt,purpose=practice
```

```bash
jx install
```

### Create zonal cluster w/ Domain

```bash
jx create cluster gke \
    --cluster-name="${JX_CLUSTER_NAME}" \
    --default-admin-password="${JX_ADMIN_PSS}" \
    --domain="${JX_DOMAIN}" \
    --kubernetes-version="${JX_K8S_VERSION}" \
    --machine-type='n1-standard-2' \
    --max-num-nodes=3 \
    --min-num-nodes=2 \
    --project-id=${JX_GCE_PROJECT} \
    --zone="${JX_K8S_ZONE}" \
    --kaniko=true \
    --skip-login
```

#### Reinstall

```bash
jx install \
    --default-environment-prefix=$JX_ENV_PREFIX \
    --git-api-token=$JX_API_TOKEN \
    --git-username=$JX_GIT_USER \
    --environment-git-owner=$JX_GIT_USER \
    --default-admin-password="${JX_ADMIN_PSS}" \
    --domain="${JX_DOMAIN}"
```

### Configure Domain

Once the cluster is up and the Jenkins X basics are installed, jx will prompt us about missing an ingress controller.

```
? No existing ingress controller found in the kube-system namespace, shall we install one? Yes
```

Reply yes, and in a little while, you will see the following message:

```bash
You can now configure your wildcard DNS jx.kearos.net to point to 35.204.0.182
nginx ingress controller installed and configured
```

We can now go to our Domain configuration and set `*.jx.${DomainName}` to the ip listed.

If you're using Google Domains by any chance, you create an `A` class record for `*.jx` with ip `35.204.0.182`.

Unfortunately, that's not enough, as the ingress resources created by jx after will have a different IP address.
So we have to add a second IP address to your Class A record.

Still assuming GKE, you can retrieve the second IP address as follows:

```bash
INGRESS_IP=$(kubectl get ing chartmuseum -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
echo $INGRESS_IP
```

To test the domain, you can do the following:

```bash
CM_URL=$(kubectl get ing chartmuseum -o jsonpath="{.spec.rules[0].host}")
```

``` bash tab="Curl"
curl $CM_URL
```

``` bash tab="Httpie"
http $CM_URL
```

### Configure TLS

If we have a proper domain configured and working, we can also enable TLS.
As we've not done so at the start, we will have to update the Ingress configuration.

For all the options for updating the Ingress configuration, use the command below.

```bash
jx upgrade ingress --help
```

To configure TLS for our ingresses, we need TLS certificates.
Jenkins X does this via Let's Encrypt, which in Kubernetes is easily done via [Certmanager](https://github.com/jetstack/cert-manager).

The command we will issue will ask us if we want to install `CertManager`, and then delete all existing ingress resources and recreate them with the certificate.
Unfortunately, when in Batch mode (`-b`) it does not install `CertManager` nor is there an option to force it in this case.

* When asked if we want to delete and recreate the existing ingress rules, say yes (`y`).
* Select the *expose type*, which should be `Ingress` (route is for OpenShift).
* Confirm your domain -> do not change it, as this upgrade does NOT change your domain configuration everywhere and you will end up with a broken system
* Say yes to cluster wide TLS
* If you're certain your Domain works, select the `production` LetEncrypt configuration, else choose `staging` for tests
* Confirm your email address and the summary
* Agree with installing `CertManager`
* Do Not agree with updating the webhooks (see below)

```bash
jx upgrade ingress --cluster --verbose
```

!!! Warning
    There's currently a bug with changing the webhooks via this command; see [issue #3115](https://github.com/jenkins-x/jx/issues/3115)
    It somehow can only select a *different* GitHub user than the current one, which makes no sense for an UPDATE.
    So we must update the webhooks manually ourselves!

#### Manually update webhooks

Due to [issue #3115](https://github.com/jenkins-x/jx/issues/3115) we need to manually update our webhooks for the environment repositories.

If you're not sure where your environment repositories are, you can retrieve them with the command below:

```bash
js get env
```

Open each environment repository, go to the settings tabs (top right), open the webhooks menu (on the left), and edit the webhook.
Simply change the `http://` to `https://` and save.

!!! Warning
    If you've selected the `staging` configuration for Let's Encrypt, you have set the SSL configuration to `Disable (not recommended)`.

### Create options

* `--buildpack='': The name of the build pack to use for the Team`
* `--vault`
* `--helm3=false: Use helm3 to install Jenkins X which does not use Tiller`
* `--kaniko=false`
* `--urltemplate='': For ingress; exposers can set the urltemplate to expose`

### Addons

```bash
create addon ambassador Create an ambassador addon
create addon anchore Create the Anchore addon for verifying container images
create addon cloudbees Create the CloudBees app for Kubernetes (a web console for working with CI/CD, Environments and GitOps)
create addon flagger Create the Flagger addon for Canary deployments
create addon gitea  Create a Gitea addon for hosting Git repositories
create addon istio  Create the Istio addon for service mesh
create addon knative-build Create the knative build addon
create addon kubeless Create a kubeless addon for hosting Git repositories
create addon owasp-zap Create the OWASP Zed Attack Proxy addon for dynamic security checks against running apps
create addon pipeline-events Create the pipeline events addon
create addon prometheus Creates a prometheus addon
create addon prow   Create a Prow addon
create addon sso    Create a SSO addon for Single Sign-On
create addon vault-operator Create an vault-operator addon for Hashicorp Vault
```

### Upgrade

```bash
jx upgrade --help
```

```bash
upgrade addons Upgrades any Addons added to Jenkins X if there are any new releases available
upgrade apps Upgrades any Apps to the latest release
upgrade binaries Upgrades the command line binaries (like helm or eksctl) - if there are new versions available
upgrade cli Upgrades the command line applications - if there are new versions available
upgrade cluster Upgrades the Kubernetes master to the specified version
upgrade extensions Upgrades the Jenkins X extensions available to this Jenkins X install if there are new versions available
upgrade ingress Upgrades Ingress rules
upgrade platform Upgrades the Jenkins X platform if there is a new release available
```

## Go lang example

```bash
jx create quickstartjc
```

* select `golang-http`

### Promote

```bash
APP=jx-go-demo-5
VERSION=0.0.2
```

```bash
jx promote ${APP} --version $VERSION --env production -b
```

```bash
jx get apps
```


## Spring Boot Example

```bash
jx create spring -d web -d actuator
```


## Serverless

```bash
jx create terraform gke \
    --vault='true' \
    --cluster="${JX_CLUSTER_NAME}"=gke \
    --gke-project-id=${JX_GCE_PROJECT} \
    --prow \
    --skip-login
```

## Demo - Show JX Stuff

### GitOps

```bash
Get environments: jx get environments
Watch pipeline activity via:    jx get activity -f golang-http -w
Browse the pipeline log via:    jx get build logs demomon/golang-http/master
Open the Jenkins console via    jx console
You can list the pipelines via: jx get pipelines
When the pipeline is complete:  jx get applications
```

## Build It

* explain build packs
* `jx create quickstart`
* show Jenkinsfile
* open application
    * `jx get applications`
* create new branch `git checkout -b wip`
* change main.go
* commit `git -a -m "better message"`
* push `git push remote wip`
* open PR page
* explain tide
* add cat picture: `/meow`
* test it
    * add comment `/test this`
    * open logs `jx logs -k`
* open PR environment
* approve the change
    * `/approve`
    * or add `approved` label
* open logs for next step
* promote: `jx promote myapp --version 1.2.3 --env production`
* promote: `jx promote ${APP} --version ${VERSION} --env production`
