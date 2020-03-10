title: Jenkins X OpenShift 3.11
description: Installing Jenkins X on RedHat OpenShift 3.11 on GCP
Hero: Jenkins X on OpenShift 3.11

# Jenkins X on RedHat OpenShift 3.11

Why Jenkins X on RedHat OpenShift 3.11?
Well, not everyone can use public cloud solutions.

So, in order to help out those running OpenShift 3.11 and want to leverage Jenkins X, read along.

!!! note
    This guide is written early March 2020, using `jx` version `2.0.1212` and OpenShift version `v3.11.170`.
    
    The OpenShift used is [installed on GCP in a minimal fashion](http://127.0.0.1:8000/jenkinsx/lighthouse-bitbucket/),  so some shortcuts are taken. For example, there's only one user, the Cluster Admin. This isn't likely in a production cluster, but it is a start.

## Pre-requisites

* kubectl is 1.16.x or less
* Helm v2
* running OpenShift cluster
    * with cluster admin access (will update how to avoid this)
* GitHub account

If you're like me, you're likely managing your packages via a package manager such as Homebrew or Chocolatey.
This means you might run newer versions of Helm and kubectl and need to downgrade them. See below how!

!!! caution
    If you run this in an on-premises solution or otherwise cannot contact GitHub, you have to use [Lighthouse](/jenkinsx/lighthouse-bitbucket/) for managing the webhooks.

    As of March 2020, the support for Bitbucket Server is missing some features [read here on what you can about that](). 
    Meanwhile, we suggest you either use GitHub Enterprise or GitLab as alternatives with better support.



### Temporarily set Helm V2

Download Helm v2 release from [Helms GitHub Releases page](https://github.com/helm/helm/releases/tag/v2.16.3).

Place the binary somewhere, for example `$HOME/Resource/helm2`.
Then set your path with the location of Helm v2 first, before including the whole path to ensure Helm v2 is found first.

```bash
PATH=$HOME/Resources/helm2:$PATH
```

Ensure you're now running helm 2 by the command below:

```bash
helm version --client
```

It should show this:

```bash
Client: &version.Version{SemVer:"v2.16.1", GitCommit:"bbdfe5e7803a12bbdf97e94cd847859890cf4050", GitTreeState:"clean"}
```

### Downgrade Kubctl

Downgrade kubectl (need lower than 1.17):

```bash
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.16.7/bin/darwin/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
```

To confirm your kubectl version is as expected, run the command below:

```bash
kubectl version --client
```

The output should be as follows:

```bash
Client Version: version.Info{Major:"1", Minor:"16", GitVersion:"v1.16.7", GitCommit:"be3d344ed06bff7a4fc60656200a93c74f31f9a4", GitTreeState:"clean", BuildDate:"2020-02-11T19:34:02Z", GoVersion:"go1.13.6", Compiler:"gc", Platform:"darwin/amd64"}
```

## Install Via Boot

The current (as of March 2020) recommended way of installing Jenkins X, is via [jx boot](https://jenkins-x.io/docs/getting-started/setup/boot/).

### Boot Configuration

* **provider: kubernetes**: Normally, this is set to your cloud provider. in order to stay close to Kubernetes itself and thus OpenShift, we set this to `kubernetes`
* **registry: docker.io**: If you're on a public cloud vender, `jx boot` creates a docker registry for you (GCR on GCP, ACR on AWS, and so on), in this example we leverage Docker Hub (`docker.io`). This should be indicative for any self-hosted registry as well!
* **dockerRegistryOrg: caladreas**:  when the docker registry owner - in my case, `caladreas`- is different from the git repository owner, you have to specify this via `dockerRegistryOrg`
* **secretStorage: local**: Thre recommended approach is to use the HashiCorp Vault integration, but that isn't supported on OpenShift
* **webhook: prow**: This uses Prow for webhook management. In March 2020 the best option to use with GitHub. If you want to use Bitbucket [read my guide on jx with lighthouse & bitbucket](/jenkinsx/lighthouse-bitbucket/).


??? example "jx-requirements.yaml"

    ```yaml
    autoUpdate:
      enabled: false
    bootConfigURL: https://github.com/jenkins-x/jenkins-x-boot-config.git
    cluster:
      clusterName: rhos11
      environmentGitOwner: <GitHub User>
      gitKind: github
      gitName: github
      gitServer: https://github.com
      namespace: jx
      provider: kubernetes
      registry: docker.io
      dockerRegistryOrg: caladreas
    environments:
    - ingress:
        domain: openshift.kearos.net
        externalDNS: false
        ignoreLoadBalancer: true
        namespaceSubDomain: -jx.
      key: dev
      repository: environment-rhos11-dev
    - ingress:
        domain: "staging.openshift.kearos.net"
        namespaceSubDomain: ""
      key: staging
      repository: env-rhos311-staging
    - ingress:
        domain: "openshift.kearos.net"
        namespaceSubDomain: ""
      key: production
      repository: env-rhos311-prod
    gitops: true
    ingress:
      domain: openshift.example.com
      externalDNS: false
      ignoreLoadBalancer: true
      namespaceSubDomain: -jx.
    kaniko: true
    repository: nexus
    secretStorage: local
    versionStream:
      ref: v1.0.361
      url: https://github.com/jenkins-x/jenkins-x-versions.git
    webhook: prow
    ```

### Jx Boot

Go to a directory where you want to clone the development environment repository.

Create the initial configuration file, `jx-requirements.yml`, and run the initial `jx boot` iteration.

```bash
jx boot
```

It will ask you if you want to clone the `jenkins x boot config` repository:

```bash
? Do you want to clone the Jenkins X Boot Git repository? [? for help] (Y/n)
```

Say yes, and it will clone the configuration repository and start the jx boot pipeline.
It will fail, because not all values are copied from your `jx-requirements.yml` into the new cloned repository.

To resolve this, go into the new cloned repository and replace the values of `jx-requirements.yml` with your configuration.
Once done, restart the installation.

```bash
jx boot
```

### Failed to install certmanager

Jenkins X will fail to install Certmanager, because it relies on newer API components from Kubernetes than are available in OpenShift 3.11. The `11` of 3.11 refers to Kubernetes `1.11`. Certmanager requires `1.12`+.

To disable the installation of certmanager, we edit the `jenkins-x.yml`, which is the pipeline executed by `jx boot`.

We have to remove the `step`, that tries to install certmanager; `install-cert-manager-crds`.
The block of code we have to remove, is as follows:

```yaml
            - args:
              - apply
              - --wait
              - --validate=false
              - -f
              - https://raw.githubusercontent.com/jetstack/cert-manager/release-0.11/deploy/manifests/00-crds.yaml
              command: kubectl
              dir: /workspace/source
              env:
              - name: DEPLOY_NAMESPACE
                value: cert-manager
              name: install-cert-manager-crds
```

Once done, we can run `jx boot` again.

### Pipeline Runner faillure

For me, the `pipeline runner` deployment failed, failing the `jx boot` process - when it validates if everything came up.

```bash
pipelinerunner-74897865f5-2k4vb                0/1     CrashLoopBackOff   55         4h
```

```bash
error: unable to clone version dir: unable to create temp dir for version stream: mkdir /tmp/jx-version-repo-083799486: permission denied
```

A solution, is add a volume to the `pipelinerunner` deployment, which mounts an `emptyDir`[^1] to at `/tmp`.

```yaml
    volumeMounts:
    - mountPath: /tmp
      name: cache-volume
```

```yaml
  volumes:
  - name: cache-volume
    emptyDir: {}
```

Once the pipelinerunner pod is running, rerun the `jx boot` installation.

```bash
jx boot
```

It should now succeed with `cluster ok`.

## Create Quickstart

To validate Jenkins X works as it should, the first step is to create a `quickstart`[^2][^3].

For simplicity, lets stick to a Go (lang) project.

```bash
jx create quickstart --filter golang-http --project-name jx-go-rhos311 --batch-mode
```

This creates a new repository based on the quickstart for Go (lang)[^4] and the build pack for Go (lang)[^5].

I ran into two issues:

1. Tekton is not mounting my Docker registry credentials, thus the Kaniko build fails with `401: not authenticated` 
1. the expose controller[^6] is using Ingress resources by default, but doesn't want to create those on OpenShift[^7]

Once the issues below are solved, the application is runing in the staging environment.
You can view the applications in your cluster as follows:

```bash
jx get application
```

Which should look something like this:

```bash
APPLICATION STAGING PODS URL
jx-go       0.0.1   1/1  http://jx-go-jx-staging.staging.openshift.example.com
```

### Missing Docker Credentials

I used Docker hub as my Docker registry, but this applies to any other self-hosted Docker registry.

We have to do the following:

1. create a `docker-registry` secret in Kubernetes, with the credentials to our Docker registry (dockerhub or otherwise)
1. mount this secret in a location Kaniko picks it up

```bash
kubectl create secret docker-registry kaniko-secret --docker-username=<username> --docker-password=<password>  --docker-email=<email-address>
```

Mount docker hub secret as json in classic Kaniko style.

```yaml
pipelineConfig:
  env:
  -  name: DOCKER_CONFIG
     value: /root/.docker/
  pipelines:
    overrides:
    - pipeline: release
      stage: build 
      name: container-build
      volumes:
        - name: kaniko-secret
          secret:
            defaultMode: 420
            secretName: kaniko-secret
            items:
                - key: .dockerconfigjson
                  path: config.json
      containerOptions:
        volumeMounts:
          - mountPath: /root/.docker
            name: kaniko-secret
```

This should be enough. But if Kaniko still runs into a `401 unathenticated` error, you have to change the ConfigMap for the builder PodTemplate. For example, if you use Go with the `go` build pack, your build container will use the `jenkins-x-pod-template-go` config map. This contains some environment variables related to Docker. If you still have issues, remove these environment variables.

> those pod template configmaps are to support traditional jenkins servers so we don't really need much from them anymore with tekton, though if we delete them things fail for now so need to keep them, but just try and remove all the DOCKER related stuff from the configmap

```bash
kubectl edit cm jenkins-x-pod-template-go
```

### Expose Controller Options

When the build succeeds, Jenkins X makes a PullRequest to your environment repository.
By default, the first one is `Staging`, which will automatically promote[^10] and run the application.

This fails, because the default setting of the staging environment, is to expose the applications via the `Expose Controller` with an `Ingress` resource. Currently (March 2020), the Expose Controller assumes OpenShift cannot handle Ingress resources[^7].

So there's two options here:

1. configure the Expose Controller to use a `Route` to expose an application[^11]
1. customize the Expose Controller to only issue a warning when using `exposer: Ingress` on OpenShift environment

If you choose option one, change the value of `exposer` from `Ingress` to `Route`of the `env/values.yaml`.

!!! example "env/values.yaml"

    ```yaml
    expose:
      Annotations:
        helm.sh/hook: post-install,post-upgrade
        helm.sh/hook-delete-policy: hook-succeeded
      Args:
      - --v
      - 4
      config:
        domain: staging.openshift.staging.example.com
        exposer: Route
        http: "true"
        tlsacme: "false"
        urltemplate: '{{.Service}}.{{.Domain}}'
    ```

If you choose option 2, fork the [Expose Controller repository](https://github.com/jenkins-x/exposecontroller) and change the line that stops it from creating Ingress resources[^7].

As can be seen here: https://github.com/jenkins-x/exposecontroller/blob/master/exposestrategy/ingress.go#L48

```go
	if t == openShift {
		return nil, errors.New("ingress strategy is not supported on OpenShift, please use Route strategy")
	}
```

And the following steps:

1. new local build
1. create and push Docker image to a registry accessable in the cluster
1. create a new helm package, in `charts` directory, execute `helm package exposecontroller`
1. upload Helm chart somewhere, for example, a [GitHub repository](https://medium.com/@mattiaperi/create-a-public-helm-chart-repository-with-github-pages-49b180dbb417)
1. update the `env/requirements.yaml` to use your helm chart instead of the Jenkins X one for the Expose Controller

For example:

!!! example "env/requirements.yaml"

    ```yaml
    dependencies:
    # - alias: expose
    #   name: exposecontroller
    #   repository: http://chartmuseum.jenkins-x.io
    #   version: 2.3.118
    - alias: expose
      name: exposecontroller
      version: 2.3.109
      repository: https://raw.githubusercontent.com/joostvdg/helm-repo/master/
    ```

## Promote To Production

To promote an application to the Production environment, we have to instruct Jenkins X to do it for us[^10].

For example:

```bash
jx promote jx-go-rhos311-1 --version 0.0.34 --env production --batch-mode
```

Aside from the [Expose Controller](/jenkinsx/rhos-311-minimal/#expose-controller-options) issues, there's nothing else to be done.

Just be sure to make those changes in your production environment repository.

## Preview Environments

The only thing required to generate a Preview Environment in Jenkins X[^12], is to create a PullRequest to the `master` branch from a other branch.

Wether the preview environment succeeds, depends on two things.

One, does the Jenkins X service account - `tekton-bot` - have enough permissions to create the namespace unique to the pull request - default naming scheme is `jx-<user>-<app>-pr-<prNumber>`.

Two, because each Preview Environment has its one Expose Controller[^13], the [Expose Controller](/jenkinsx/rhos-311-minimal/#expose-controller-options) needs to be configured to either use `Route` or accept creating `Ingress` when on OpenShift.

If all is done, you can retrieve the current preview environments as follows:

```bash
jx get preview
```

Which should yield something like this:

```bash
PULL REQUEST                                           NAMESPACE        APPLICATION
https://bitbucket.openshift.kearos.net/jx/jx-go/pull/1 jx-jx-jx-go-pr-1 http://jx-go.jx-jx-jx-go-pr-1.openshift.example.com
```

## Errata

### Registry Owner Mismatch

It can happen that the docker registry owner is not the same for every application. If this is the case, the application will have to make a workaround after it is imported into Jenkins X (via `jx import` or `jx create quickstart`).

In order to resolve the mismatch between the default Jenkins X installation Docker registry owner and the application's owner, we need to change two things in our Jenkins X pipeline (`jenkins-x.yml`)[^8].

1. add an override for the Docker registry owner in the `jenkins-x.yml`, the pipeline of your application.
1. add an override for the `container-build` step of the `build` stage, for both the `release` and `pullrequest` pipelines.

Overriding the pipeline is done by specifying the stage to override under `pipelineConfig.overides`[^8][^9].

When you set `dockerRegistryOwner`, it overrides the value generated elsewhere.

```yaml
dockerRegistryOwner: caladreas
```

The only exception is where the image gets uploaded to via `Kaniko`. 

```yaml
- --destination=docker.io/caladreas/jx-go-rhos311-1:${inputs.params.version}
```

The end result will look like this.

!!! example "jenkins-x.yml"

    ```yaml
    dockerRegistryOwner: caladreas
    buildPack: go
    pipelineConfig:
        overrides:
        - pipeline: release
          stage: build 
          name: container-build
          steps:
            - name: container-build
              dir: /workspace/source
              image: gcr.io/kaniko-project/executor:9912ccbf8d22bbafbf971124600fbb0b13b9cbd6
              command: /kaniko/executor
              args:
                - --cache=true
                - --cache-dir=/workspace
                - --context=/workspace/source
                - --dockerfile=/workspace/source/Dockerfile
                - --destination=docker.io/caladreas/jx-go-rhos311-1:${inputs.params.version}
                - --cache-repo=docker.io/todo/cache
                - --skip-tls-verify-registry=docker.io
                - --verbosity=debug
        - pipeline: pullrequest
          stage: build 
          name: container-build
          steps:
            - name: container-build
              dir: /workspace/source
              image: gcr.io/kaniko-project/executor:9912ccbf8d22bbafbf971124600fbb0b13b9cbd6
              command: /kaniko/executor
              args:
                - --cache=true
                - --cache-dir=/workspace
                - --context=/workspace/source
                - --dockerfile=/workspace/source/Dockerfile
                - --destination=docker.io/caladreas/jx-go-rhos311-1:${inputs.params.version}
                - --cache-repo=docker.io/todo/cache
                - --skip-tls-verify-registry=docker.io
                - --verbosity=debug
    ```


## References

[^1]: https://kubernetes.io/docs/concepts/storage/volumes/#emptydir
[^2]: https://jenkins-x.io/docs/getting-started/first-project/create-quickstart/
[^3]: https://github.com/jenkins-x-quickstarts
[^4]: https://github.com/jenkins-x-quickstarts/golang-http
[^5]: https://github.com/jenkins-x-buildpacks/jenkins-x-kubernetes/tree/master/packs
[^6]: https://jenkins-x.io/docs/concepts/technology/#whats-is-exposecontroller
[^7]: https://github.com/jenkins-x/exposecontroller/blob/master/exposestrategy/ingress.go#L48
[^8]: https://jenkins-x.io/docs/reference/pipeline-syntax-reference/
[^9]: https://technologyconversations.com/2019/06/30/overriding-pipelines-stages-and-steps-and-implementing-loops-in-jenkins-x-pipelines/
[^10]: https://jenkins-x.io/docs/getting-started/promotion/
[^11]: https://github.com/jenkins-x/exposecontroller#exposer-types
[^12]: https://jenkins-x.io/docs/getting-started/build-test-preview/#generating-a-preview-environment
[^13]: https://jenkins-x.io/docs/reference/preview/#charts