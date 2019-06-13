# Jenkins X Hybrid TLS

Jenkins X Hybrid TLS is a configuration of Jenkins X using both Static Jenkins and Jenkins X Serverless with Tekton within the same cluster. As the TLS suffix hints at, it also uses TLS for both installations to make sure all the services and your applications are accessible via https with a valid certificate.

## Pre-requisites

* GCP account
    * with active subscription
    * with an active project with which you are authenticated
* `gcloud` CLI
* Jenkins X CLI `jx`
* httpie or curl

## Steps

* create JX cluster in GKE with static Jenkins
    * without Nexus
* create Go (lang) quickstart
* configure TLS
* install Serverless Jenkins X in the same cluster
* create Spring Boot Quickstart
* configure TLS for Serverless namespaces only
* re-install Jenkins X with Nexus

## Static

### Prepare

#### Variables

```bash
CLUSTER_NAME=#name of your cluster
PROJECT=#name of your GCP project
REGION=#GCP region to install cluster in
GITHUB_USER=#your GitHub Username
GITHUB_TOKEN=#GitHub apitoken
```

#### myvalues.yaml

We're going to use a demo application based on Go, so we don't need Nexus.

To configure Jenkins X to skip Nexus' installation, create the file `myvalues.yaml` with the following contents:

```yaml
nexus:
  enabled: false
docker-registry:
  enabled: true
```

### Install JX

Make sure you execute this command where you have the `myvalues.yaml` file.

```bash
jx create cluster gke \
    --cluster-name ${CLUSTER_NAME} \
    --project-id ${PROJECT} \
    --region ${REGION} \
    --machine-type n1-standard-2 \
    --min-num-nodes 1 \
    --max-num-nodes 2 \
    --default-admin-password=admin \
    --default-environment-prefix jx-rocks \
    --git-provider-kind github \
    --git-username ${GITHUB_USER} \
    --git-provider-kind github \
    --git-api-token ${GITHUB_TOKEN} \
    --batch-mode
```

### Go Quickstart

```bash
jx create quickstart \
    -l go --org ${GITHUB_USER} \
    --project-name jx-static-go \
    --import-mode=Jenkinsfile \
    --deploy-kind default \
    -b
```

#### Watch activity

You can either go to Jenkins and watch the job there: `jx console` or watch in your console via `jx get activity`.

```bash
jx get activity -f jx-static-go -w
```

Once the build completes, you should see something like the line below, you can test the application.

```bash
Promoted                          28m5s    1m41s Succeeded  Application is at: http://jx-static-go.jx-staging.34.90.105.15.nip.io
```

#### Test application

To confirm the application is running in the staging environment:

```bash
jx get applications
```

Which should show something like this:

```bash
APPLICATION  STAGING PODS URL
jx-static-go 0.0.1   1/1  http://jx-static-go.jx-staging.${LIB_IP}.nip.io
```

```bash
LB_IP=$(kubectl get svc -n kube-system jxing-nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

```bash
http jx-static-go.jx-staging.${LB_IP}.nip.io
```

Which should show the following:

```bash
HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 43
Content-Type: text/plain; charset=utf-8
Date: Thu, 13 Jun 2019 12:17:39 GMT
Server: nginx/1.15.8

Hello from:  Jenkins X golang http example
```

### Configure TLS

Make sure you have two things:

* the address of your LoadBalancer (see below how to retrieve this)
* a Domain name with a quick and easy DNS configuration (incl. wildcard support)

#### Retrieve LoadBalancer address

```bash
LB_IP=$(kubectl get svc -n kube-system jxing-nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```

#### Configure DNS

Go to your Domain provider of choice, if you don't have one, consider [Google Domains](https://domains.google/) for 12 Euro per year.
They might no be the cheapest, but the service is great and works quick - changes like we're about to do, take a few minutes to be effectuated.

Configure the following wildcards to direct to your LoadBalancer's IP address:

* `*.jx` - [type A](https://support.google.com/domains/answer/3251147?hl=en)
* `*.jx-staging` - [type A](https://support.google.com/domains/answer/3251147?hl=en)
* `*.jx-production` - [type A](https://support.google.com/domains/answer/3251147?hl=en)
* `*.serverless` - [type A](https://support.google.com/domains/answer/3251147?hl=en) (for the serverless section)

#### Upgrade Ingress

To configure TLS inside Jenkins X, we make use of [Let's Encrypt](https://letsencrypt.org/) and [cert-manager](https://github.com/jetstack/cert-manager).

To get Jenkins X to configure TLS, we use the `jx upgrade ingress` command.

```bash
DOMAIN=#your domain name
```

```bash
jx upgrade ingress \
    --cluster true \
    --domain $DOMAIN
```

!!! Info
    To be sure, the Domain name above should the base hostname only.
    Any resource within your JX installation will automatically get the following domain name: `{name}.{namespace}.{DOMAIN}`.
    For example, if your domain is `example.com` Jenkins will become `jenkins.jx.example.com`.

##### Test applications

Confirm your application now has a https protocol.

```bash
jx get applications
```

```bash
http https://jx-static-go.jx-staging.${DOMAIN}
```

## Serverless

### Prepare

The values for `INGRESS_NS` and `INGRESS_DEP` are the default based on the static install created above.
If your ingress controller namespace and/or deployment have different names, replace the values.

For the `LB_IP`, we're also assuming default names and namespaces.

```bash
PROVIDER=gke
LB_IP=$(kubectl get svc -n kube-system jxing-nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
DOMAIN_SUFFIX=#your domain name
DOMAIN=serverless.${DOMAIN_SUFFIX}
INGRESS_NS=kube-system
INGRESS_DEP=jxing-nginx-ingress-controller
INSTALL_NS=cdx
PROJECT=#your GCP project
```

!!! Info
    We're going to use the `cdx` namespace, this will create namespaces such as `cdx` and `cdx-staging`.
    In order to avoid having to register every environment in at our DNS provider, we will use an additional domain prefix `serverless`. Making the domain `serverless.{DOMAIN}` and the JX components `{name}.cdx.serverless.{DOMAIN}`.

### Install Serverless JX

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

### Spring Boot Quickstart

#### Create quickstart

```bash
jx create spring -d web -d actuator \
    --group com.example \
    --artifact jx-spring-boot-demo \
    -b
```

```bash
cd jx-spring-boot-demo
```

#### Add controller

Assuming you kept the group the same, you should find a folder `src/main/java/com/example/jxspringbootdemo` containing a file, `DemoApplication.java`.

We're going to have to add two files to the same folder:

* `Greeting.java`
* `GreetingController.java`

##### Greeting

```java
package com.example.jxspringbootdemo;

public class Greeting {

    private final long id;
    private final String content;

    public Greeting(long id, String content) {
        this.id = id;
        this.content = content;
    }

    public long getId() {
        return id;
    }

    public String getContent() {
        return content;
    }
}
```

##### GreetingController

```java
package com.example.jxspringbootdemo;

import java.util.concurrent.atomic.AtomicLong;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class GreetingController {

    private static final String template = "Hello, %s!";
    private final AtomicLong counter = new AtomicLong();

    @RequestMapping("/greeting")
    public Greeting greeting(@RequestParam(value="name", defaultValue="World") String name) {
        return new Greeting(counter.incrementAndGet(),
                            String.format(template, name));
    }
}
```

#### Test application

```bash
jx get activity -f jx-cdx-spring-boot-demo-1 -w
```

### Re-Install with Nexus

#### myvalues.yaml

Our application didn't work because now we have an application that depends on a Maven repository.
We have to "re-install" Jenkins X, to have it install Nexus for us in the `cdx` namespace.

```yaml
nexus:
  enabled: true
docker-registry:
  enabled: true
```

#### Install

Make sure you execute this command where you have the `myvalues.yaml` file.

```bash
jx install \
    --provider $PROVIDER \
    --external-ip $LB_IP \
    --domain serverless.$DOMAIN \
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

### Test Application

To trigger a new build, make a change - for example to the `README.md` and push it.

```bash
jx get activity -f jx-cdx-spring-boot-demo-1 -w
```

```bash
http jx-cdx-spring-boot-demo-1.cdx-staging.serverless.${DOMAIN}/greeting
```

### Configure TLS

```bash
jx upgrade ingress --domain $DOMAIN --namespaces cdx,cdx-staging
```

#### Re-test application

```bash
ORG=#the GitHub user or organisation your application is in
```

```bash
jx update webhooks --repo=jx-cdx-spring-boot-demo-1 --org=${ORG}
jx get applications
jx get activity -f jx-cdx-spring-boot-demo-1 -w
http https://jx-cdx-spring-boot-demo-1.cdx-staging.serverless.${DOMAIN}/greeting
```