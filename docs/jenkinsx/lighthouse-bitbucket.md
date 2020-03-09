title: Jenkins X - Lighthouse & Bitbucket
description: Installing Jenkins X using Bitbucket and Lighthouse for environment repositories

# Jenkins X - Lighthouse & Bitbucket

This guide is about using Jenkins X with Lighthouse[^1] as webhook manager and Bitbucket for the environment repositories[^2].

## Run Bitbucket on Kubernetes

Unfortunately, Atlassian doesn't have an officially supported Bitbucket for Kubernetes.

So I've taken the courtesy of creating my own basic configuration - read, ***not*** production ready.

!!! example "service.yaml"

    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
    labels:
        app: bitbucket
    name: bitbucket
    namespace: default
    spec:
    ports:
    - name: http
        port: 80
        protocol: TCP
        targetPort: http
    selector:
        app: bitbucket
    sessionAffinity: None
    type: ClusterIP
    ```

!!! example "ingress.yaml"

    I've taken the assumption that your cluster supports Ingress resources (even if its an OpenShift cluster).

    ```yaml
    apiVersion: extensions/v1beta1
    kind: Ingress
    metadata:
      name: bitbucket
      namespace: default
    spec:
      rules:
      - host: bitbucket.openshift.example.com
        http:
          paths:
          - backend:
              serviceName: bitbucket
              servicePort: 80
    ```

!!! example "stateful-set.yaml"

    ```yaml
    apiVersion: apps/v1
    kind: StatefulSet
    metadata:
      name: bitbucket
      namespace: default
    spec:
      serviceName: "bitbucket"
      replicas: 1
      selector:
        matchLabels:
          app: bitbucket
      template:
        metadata:
          labels:
            app: bitbucket
        spec:
          containers:
          - name: bitbucket
            image: atlassian/bitbucket-server:7.0.0
            ports:
            - containerPort: 7990
              name: http
            - containerPort: 7999
              name: web
            volumeMounts:
            - name: data
              mountPath: /var/atlassian/application-data/bitbucket
      volumeClaimTemplates:
      - metadata:
          name: data
        spec:
          accessModes: [ "ReadWriteOnce" ]
          resources:
            requests:
              storage: 5Gi
    ```

## JX Boot Configuration

We use `jx boot`[^3] to install Jenkins X. 
If we want to use Bitbucket for the environment repositories, we have to use Lighthouse[^1][^4].

In order to jx to install correctly, we have configure several parameters in the `jx-requirements.yml` with specific values.
See the docs for all the possible values[^5].

* **webhook: lighthouse**:  we have to set the webhook manager to `lighthouse`, as Prow only works with GitHub
* **environmentGitOwner: jx**: the project in Bitbucket where the repositories need to be created
* **gitKind: bitbucketserver**: the `kind` of git server, in this case `bitbucketserver`, because `bitbucket` refers to [Bitbucket Cloud](https://bitbucket.org/)
* **gitName: bs**: the name for our gitserver configuration
* **gitServer: http://bitbucket.openshift.example.com**: the url to our Bitbucket Server

We also have to set the storage for at least the logs.
If we do not configure the storage for our logs, they will be assumed to be written to github pages of our application.
That is, regardless of where our application resides. So, if you use anything other than GitHub (cloud), you *have* to configure the logs storage.

The easiest solution, is to create a seperate repository for the build logs in your Bitbucket Server project.

```yaml
    storage:
      logs:
        enabled: true
        url: "http://bitbucket.openshift.example.com/scm/jx/build-logs.git"
```

If you have forgotten to set the storage before the installation, you can rectify this afterwards via the `jx edit storage` command.

```bash
jx edit storage -c logs --git-url http://bitbucket.openshift.kearos.net/scm/jx/build-logs.git  --git-branch master
```

??? example "jx-requirements.yml"

    ```yaml
    bootConfigURL: https://github.com/jenkins-x/jenkins-x-boot-config.git
    cluster:
      clusterName: rhos11
      devEnvApprovers:
      - jvandergriendt
      environmentGitOwner: jx
      gitKind: bitbucketserver
      gitName: bs
      gitServer: http://bitbucket.openshift.example.com
      namespace: jx
      provider: kubernetes
      registry: docker.io
    environments:
    - ingress:
        domain: openshift.example.com
        namespaceSubDomain: -jx.
      key: dev
      repository: environment-rhos11-dev
    - ingress:
        domain: staging.openshift.example.com
        namespaceSubDomain: ""
      key: staging
      repository: env-rhos311-staging
    - key: production
      repository: env-rhos311-prod
    gitops: true
    ingress:
      domain: openshift.example.com
      namespaceSubDomain: -jx.
    kaniko: true
    repository: nexus
    secretStorage: local
    storage:
      logs:
        enabled: true
        url: "http://bitbucket.openshift.example.com/scm/jx/build-logs.git"
    versionStream:
      ref: v1.0.361
      url: https://github.com/jenkins-x/jenkins-x-versions.git
    webhook: lighthouse
    ```

### Bitbucket API Token

To authenticate with Bitbucket server, Jenkins X needs a API token of a user that has admin permissions.

First, create this user API token in Bitbucket.
You can do so, via `Manage Account`(top right menu) -> `Personal access tokens` -> `Create a token` (top right).

Then use the `jx create token addon `[^6] command to create the API token for Bitbucket server.
Make sure to use the same `--name <NAME>`, as the `gitName` in your `jx-requirements.yml` file.

> Creates a new User Token for an Addon service

For example, lets create the token for my configuration:

```bash
jx create token addon --name bs --url http://bitbucket.openshift.example.com  --api-token <API_TOKEN> <USER>
```

This should give the following response.

```bash
Created user <USER> API Token for addon server bs at http://bitbucket.openshift.example.com
```

## Installation

Before running the Jenkins X installation with `jx boot`, make sure you meet the pre-requisites.

### Pre-requisites

* Kubernetes cluster
* cluster admin access to Kubernetes cluster
* Bitbucket server
* Project in Bitbucket server
* API token in Bitbucket server
* API token for Jenkins X in the Kubernetes cluster

Once these are met, we can install Jenkins X via `jx boot`[^3].

### Issue with controllerbuild

A potential issue you can run into, is that the deployment `jenkins-x-controllerbuild` fails to come up.

```bash
could not lock config file //.gitconfig: Permission denied: failed to run 'git config --global --add user.name jenkins-x-bot' command in directory '',
```

The issue here, seems to be some missing configuration, as the the two `/`'s in `//.gitconfig`, give the idea there's supposed to be some folder defined.

A way to solve this, is to ensure we have a home folder git can write into, and tell git where this home folder is.

The image seems to set its working directory to `/home/jenkins`, so lets use that.
In order to tell git where to write its configuration to, we can set the `HOME` environment variable.

So in the `jenkins-x-controllerbuild` deployment, set the HOME environment variable to `/home/jenkins`.

```yaml
- name: HOME
  value: /home/jenkins
```

Add folder for `home/jenkins` via volume and volumeMount.

```yaml
    volumeMounts:
    - mountPath: /home/jenkins
      name: jenkinshome
```

```yaml
  volumes:
  - name: jenkinshome
    emptyDir: {}
```

## Errata

### Import & Quickstarts Source Repositories Always HTTPS

When you add applications to Jenkins X, either via the `jx import` or `jx create quickstart` processes, a `SourceRepository` CRD gets created.

This resource will contain the the value `spec.httpCloneURL`. This is used in the Tekton pipelines for cloning the repository.
This `httpCloneURL` is always set to `https://`, even if the repository `url` is `http://`.

To retrieve the existing source repositories, you can do the following:

```bash
kubectl get sourcerepository
```

You can edit a specific source repository via:

```bash
kubectl edit sourcerepository jx-jx-go
```

And if required, change the `https://` into a `http://`.

### PullRequest Updates

Bitbucket Server does not send a specific webhook when there's an update to a branch participating in a PullRequest.
It only sends a generic `Push` event, which does not give Jenkins X the information required to trigger a new build for the specific PullRequest.

Atlassian has recently add this feature in Bitbucket Server `7.0.0`, confirmed by the [March 5th update in this Jira ticket](https://jira.atlassian.com/browse/BSERV-10279).

As of March 2020, this is not yet supported by Jenkins X, nor is it expected at this point in time to find its way into earlier releases (such as 6.x) of Bitbucket server.

## References

[^1]: https://jenkins-x.io/docs/reference/components/lighthouse/
[^2]: https://jenkins-x.io/docs/reference/components/lighthouse/#bitbucket-server
[^3]: https://jenkins-x.io/docs/getting-started/setup/boot/how-it-works/
[^4]: https://jenkins-x.io/docs/getting-started/setup/boot/#bitbucket-server
[^5]: https://jenkins-x.io/docs/reference/config/config/#config.jenkins.io/v1.ClusterConfig
[^6]: https://jenkins-x.io/commands/jx_create_token_addon/