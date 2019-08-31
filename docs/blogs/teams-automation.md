title: Core Modern Teams Automation
description: Use GitOps to manage Team Master in CloudBees Core on Modern
Hero: GitOps for Team Masters

# Core Modern Teams Automation

CloudBees Core on Modern (meaning, on Kubernetes) has two main types of Jenkins Masters, a Managed Master, and a Team Master. In this article, we're going to automate the creation and management of the Team Masters.

!!! hint
	If you do not want to read any of the code here, or just want to take a look at the end result - pipeline wise - you can find working examples on GitHub.

	* [Template Repository](https://github.com/joostvdg/cb-team-gitops-template) - creates a new team template and a PR to the GitOps repository
	* [GitOps Repository](https://github.com/joostvdg/cb-team-gitops) - applies GitOps principles to manage the CloudBees Core Team Masters

## Goals

Just automating the creation of a Team Master is relatively easy, as this can be done via the [Client Jar](). So we're going to set some additional goals to create a decent challenge.

* **GitOps**: I want to be able to create and delete Team Masters by managing configuration in a Git repository 
* **Configuration-as-Code**: as much of the configuration as possible should be stored in the Git repository
* **Namespace**: one of the major reasons for Team Masters to exist is to increase (Product) Team autonomy, which in Kubernetes should correspond to a `namespace`. So I want each Team Master to be in its own Namespace!
* **Self-Service**: the solution should cater to (semi-)autonomous teams and lower the workload of the team managing CloudBees Core. So requesting a Team Master should be doable by everyone

## Before We Start

Some assumptions need to be taken care off before we start.

* Kubernetes cluster in which you are `ClusterAdmin`
	* if you don't have one yet, [there are guides on this elsewhere on the site](/kubernetes/distributions/install-gke/)
* your cluster has enough capacity (at least two nodes of 4gb memory)
* your cluster has CloudBees Core Modern installed
	* if you don't have this yet [look at one of the guides on this site](/cloudbees/cbc-gke-helm/)
	* or look at the [guides on CloudBees.com](https://go.cloudbees.com/docs/cloudbees-core/cloud-install-guide/)
* have administrator access to CloudBees Core Cloud **Operations Center**

!!!	tip "Code Examples"
	The more extensive Code Examples, such as Kubernetes Yaml files, are collapsed by default. You can open them by clicking on them. On the right, the code snippet will have a `[ ]` copy icon. Below is an example.


??? example "Code Snippet Example"
	Here's a code snippet.

	```groovy
	pipeline {
		agent any
		stages {
			stage('Hello') {
				steps {
					echo 'Hello World!'
				}
			}
		}
	}
	```

## Bootstrapping

All right, so we want to use GitOps and to process the changes we need a Pipeline that can be triggered by a Webhook. I believe in ***everything as code*** - except Secrets and such - which includes the Pipeline.

Unfortunately, **Operations Center** cannot run such pipelines. To get over this hurdle, we will create a special `Ops` Team Master. This Master will be configured to be able to Manage the other Team Masters for us.

Log into your Operations Center with a user that has administrative access.

### Create API Token

Create a new API Token for your administrator user by clicking on the user's name - top right corner. Select the `Configuration` menu on the left and then you should see a section where you can `Create a API Token`. This Token will disappear, so write it down.

### Get & Configure Client Jar

Replace the values marked by `< ... >`. The Operations Center URL should look like this: `http://cbcore.mydomain.com/cjoc`.

Setup the connection variables.

```bash
OC_URL=<your operations center url>
```

```bash
USR=<your username>
TKN=<api token>
```

Download the Client Jar.

```bash
curl ${OC_URL}/jnlpJars/jenkins-cli.jar -o jenkins-cli.jar
```

### Create Alias & Test

```bash
alias cboc="java -jar jenkins-cli.jar -noKeyAuth -auth ${USR}:${TKN} -s ${OC_URL}"
```

```bash
cboc version
```

### Create Team Ops

As the tasks of the Team Masters for managing Operations are quite specific and demand special rights, I'd recommend putting this in its own `namespace`. To do so properly, we need to configure a few things.

* allows Operations Center access to this namespace (so it can create the Team Master)
* give the `ServiceAccount` the permissions to create `namespace`'s for the other Team Masters
* add config map for the Jenkins Agents
* temporarily change Operations Center's operating Namespace (where it will spawn resources in)
* use the CLI to create the `team-ops` Team Master
* reset Operations Center's operating Namespace

### Update & Create Kubernetes Namespaces

#### Create Team Ops Namespace

```bash
kubectl apply -f team-ops-namespace.yaml
```

??? example "team-ops-namespace.yaml"
	This creates the `team-ops` namespace including all the resources required such as `ResourceQuota`, `ServiceAccount` and so on.

    ```yaml
    apiVersion: v1
    kind: Namespace
    metadata:
      name: team-ops

    ---

    apiVersion: v1
    kind: ResourceQuota
    metadata:
      name: resource-quota
      namespace: team-ops
    spec:
      hard:
        pods: "20"
        requests.cpu: "4"
        requests.memory: 6Gi
        limits.cpu: "5"
        limits.memory: 10Gi
        services.loadbalancers: "0"
        services.nodeports: "0"
        persistentvolumeclaims: "10"

    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: jenkins
      namespace: team-ops

    ---

    kind: Role
    apiVersion: rbac.authorization.k8s.io/v1beta1
    metadata:
      name: pods-all
      namespace: team-ops
    rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["pods/exec"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get","list","watch"]

    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: RoleBinding
    metadata:
      name: jenkins
      namespace: team-ops
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: pods-all
    subjects:
    - kind: ServiceAccount
      name: jenkins
      namespace: team-ops

    ---

    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: RoleBinding
    metadata:
      name: cjoc
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: master-management
    subjects:
    - kind: ServiceAccount
      name: jenkins
      namespace: team-ops

    ---

    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: ClusterRole
    metadata:
      name: create-namespaces
    rules:
    - apiGroups: ["*"]
      resources: ["serviceaccounts", "rolebindings", "roles", "resourcequotas", "namespaces"]
      verbs: ["create","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["configmaps", "rolebindings", "roles", "resourcequotas", "namespaces"]
      verbs: ["create","get","list"]
    - apiGroups: [""]
      resources: ["events"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["persistentvolumeclaims", "pods", "pods/exec", "services", "statefulsets", "ingresses", "extensions"]
      verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get", "list", "watch"]
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["list"]
    - apiGroups: ["apps"]
      resources: ["statefulsets"] 
      verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]
    - apiGroups: ["extensions"]
      resources: ["ingresses"]
      verbs: ["create", "delete", "get", "list", "patch", "update", "watch"]

    ---

    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: ClusterRoleBinding
    metadata:
      name: ops-namespace
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: create-namespaces
    subjects:
    - kind: ServiceAccount
      name: jenkins
      namespace: team-ops
    ```

#### Update Operation Center ServiceAccount

The `ServiceAccount` under which Operation Center runs, only has rights in it's own `namespace`. Which means it cannot create our Team Ops Master. Below is the `.yaml` file for Kubernetes and the command to apply it.

!!! warning
    I assume you're using the default `cloudbees-core` as per Cloudbees' documentation. If this is not the case, change the last line, `namespace: cloudbees-core` with the namespace your Operation Center runs in.

```bash
kubectl apply -f patch-oc-serviceaccount.yaml -n team-ops
```

??? example "patch-oc-serviceaccount.yaml"
	This patches the existing Operation Center's ServiceAccount to also have the correct rights in the `team-ops` namespace.

    ```yaml
    kind: Role
    apiVersion: rbac.authorization.k8s.io/v1beta1
    metadata:
      name: master-management
    rules:
    - apiGroups: [""]
      resources: ["pods"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["pods/exec"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["pods/log"]
      verbs: ["get","list","watch"]
    - apiGroups: ["apps"]
      resources: ["statefulsets"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["services"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["persistentvolumeclaims"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: ["extensions"]
      resources: ["ingresses"]
      verbs: ["create","delete","get","list","patch","update","watch"]
    - apiGroups: [""]
      resources: ["secrets"]
      verbs: ["list"]
    - apiGroups: [""]
      resources: ["events"]
      verbs: ["get","list","watch"]

    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: RoleBinding
    metadata:
      name: cjoc
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: master-management
    subjects:
    - kind: ServiceAccount
      name: cjoc
      namespace: cloudbees-core
	```

#### Jenkins Agent ConfigMap

```bash
kubectl apply -f jenkins-agent-config-map.yaml -n team-ops
```

??? example "jenkins-agent-config-map.yaml"
    Creates the Jenkins Agent ConfigMap, which contains the information the Jenkins Agent - within a PodTemplate - uses to connect to the Jenkins Master.

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: jenkins-agent
    data:
      jenkins-agent: |
        #!/usr/bin/env sh
        # The MIT License
        #
        #  Copyright (c) 2015, CloudBees, Inc.
        #
        #  Permission is hereby granted, free of charge, to any person obtaining a copy
        #  of this software and associated documentation files (the "Software"), to deal
        #  in the Software without restriction, including without limitation the rights
        #  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        #  copies of the Software, and to permit persons to whom the Software is
        #  furnished to do so, subject to the following conditions:
        #
        #  The above copyright notice and this permission notice shall be included in
        #  all copies or substantial portions of the Software.
        #
        #  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        #  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        #  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        #  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        #  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        #  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
        #  THE SOFTWARE.
        # Usage jenkins-slave.sh [options] -url http://jenkins [SECRET] [AGENT_NAME]
        # Optional environment variables :
        # * JENKINS_TUNNEL : HOST:PORT for a tunnel to route TCP traffic to jenkins host, when jenkins can't be directly accessed over network
        # * JENKINS_URL : alternate jenkins URL
        # * JENKINS_SECRET : agent secret, if not set as an argument
        # * JENKINS_AGENT_NAME : agent name, if not set as an argument
        if [ $# -eq 1 ]; then
            # if `docker run` only has one arguments, we assume user is running alternate command like `bash` to inspect the image
            exec "$@"
        else
            # if -tunnel is not provided try env vars
            case "$@" in
                *"-tunnel "*) ;;
                *)
                if [ ! -z "$JENKINS_TUNNEL" ]; then
                    TUNNEL="-tunnel $JENKINS_TUNNEL"
                fi ;;
            esac
            if [ -n "$JENKINS_URL" ]; then
                URL="-url $JENKINS_URL"
            fi
            if [ -n "$JENKINS_NAME" ]; then
                JENKINS_AGENT_NAME="$JENKINS_NAME"
            fi  
            if [ -z "$JNLP_PROTOCOL_OPTS" ]; then
                echo "Warning: JnlpProtocol3 is disabled by default, use JNLP_PROTOCOL_OPTS to alter the behavior"
                JNLP_PROTOCOL_OPTS="-Dorg.jenkinsci.remoting.engine.JnlpProtocol3.disabled=true"
            fi
            # If both required options are defined, do not pass the parameters
            OPT_JENKINS_SECRET=""
            if [ -n "$JENKINS_SECRET" ]; then
                case "$@" in
                    *"${JENKINS_SECRET}"*) echo "Warning: SECRET is defined twice in command-line arguments and the environment variable" ;;
                    *)
                    OPT_JENKINS_SECRET="${JENKINS_SECRET}" ;;
                esac
            fi
            
            OPT_JENKINS_AGENT_NAME=""
            if [ -n "$JENKINS_AGENT_NAME" ]; then
                case "$@" in
                    *"${JENKINS_AGENT_NAME}"*) echo "Warning: AGENT_NAME is defined twice in command-line arguments and the environment variable" ;;
                    *)
                    OPT_JENKINS_AGENT_NAME="${JENKINS_AGENT_NAME}" ;;
                esac
            fi
            SLAVE_JAR=/usr/share/jenkins/slave.jar
            if [ ! -f "$SLAVE_JAR" ]; then
                tmpfile=$(mktemp)
                if hash wget > /dev/null 2>&1; then
                    wget -O "$tmpfile" "$JENKINS_URL/jnlpJars/slave.jar"
                elif hash curl > /dev/null 2>&1; then
                    curl -o "$tmpfile" "$JENKINS_URL/jnlpJars/slave.jar"
                else
                    echo "Image does not include $SLAVE_JAR and could not find wget or curl to download it"
                    return 1
                fi
                SLAVE_JAR=$tmpfile
            fi
            #TODO: Handle the case when the command-line and Environment variable contain different values.
            #It is fine it blows up for now since it should lead to an error anyway.
            exec java $JAVA_OPTS $JNLP_PROTOCOL_OPTS -cp $SLAVE_JAR hudson.remoting.jnlp.Main -headless $TUNNEL $URL $OPT_JENKINS_SECRET $OPT_JENKINS_AGENT_NAME "$@"
        fi
	```

### Create Initial Master

To make it easier to change the `namespace` if needed, its extracted out from the command.

```bash
OriginalNamespace=cloudbees-core
```

This script changes the Operations Center's operating `namespace`, creates a Team Master with the name `ops`, and then resets the namespace.

```bash
cboc groovy = < configure-oc-namespace.groovy team-ops
cboc teams ops --put < team-ops.json
cboc groovy = < configure-oc-namespace.groovy $OriginalNamespace
```

??? example "team-ops.json"
    This `json` file that describes a team. By default there are three roles defined on a team, `TEAM_ADMIN`, `TEAM_MEMBER`, and `TEAM_GUEST`. Don't forget to change the `id`'s to Group ID's from your Single-Sign-On solution.

    ```yaml
    {
        "version" : "1",
        "data": {
            "name": "ops",
            "displayName": "Operations",
            "provisioningRecipe": "basic",
            "members": [{
                "id": "Catmins",
                "roles": ["TEAM_ADMIN"]
            },
            {
                "id": "Pirates",
                "roles": ["TEAM_MEMBER"]
            },
            {
                "id": "Continental",
                "roles": ["TEAM_GUEST"]
            }
            ],
            "icon": {
                "name": "hexagons",
                "color": "#8d7ec1"
            }
        }
    }
	```

??? example "configure-oc-namespace.groovy"
	This is a Jenkins Configuration or System Groovy script. It will change the `namespace` Operation Center uses to create resources. You can change this in the UI by going to `Operations Center` -> `Manage Jenkins` -> `System Configuration` -> `Master Provisioning` -> `Namespace`.

	```groovy
    import hudson.*
    import hudson.util.Secret;
    import hudson.util.Scrambler;
    import hudson.util.FormValidation;
    import jenkins.*
    import jenkins.model.*
    import hudson.security.*

    import com.cloudbees.masterprovisioning.kubernetes.KubernetesMasterProvisioning
    import com.cloudbees.masterprovisioning.kubernetes.KubernetesClusterEndpoint

    println "=== KubernetesMasterProvisioning Configuration - start"

    println "== Retrieving main configuration"
    def descriptor = Jenkins.getInstance().getInjector().getInstance(KubernetesMasterProvisioning.DescriptorImpl.class)
    def namespace = this.args[0]

    def currentKubernetesClusterEndpoint =  descriptor.getClusterEndpoints().get(0)
    println "= Found current endpoint"
    println "= " + currentKubernetesClusterEndpoint.toString()
    def id = currentKubernetesClusterEndpoint.getId()
    def name = currentKubernetesClusterEndpoint.getName()
    def url = currentKubernetesClusterEndpoint.getUrl()
    def credentialsId = currentKubernetesClusterEndpoint.getCredentialsId()

    println "== Setting Namspace to " + namespace
    def updatedKubernetesClusterEndpoint = new KubernetesClusterEndpoint(id, name, url, credentialsId, namespace)
    def clusterEndpoints = new ArrayList<KubernetesClusterEndpoint>()
    clusterEndpoints.add(updatedKubernetesClusterEndpoint)
    descriptor.setClusterEndpoints(clusterEndpoints)

    println "== Saving Jenkins configuration"
    descriptor.save()

    println "=== KubernetesMasterProvisioning Configuration - finish"
	```

## Configure Team Ops Master

Now that we've created the Operations Team Master (Team Ops), we can configure it. 

The Pipelines we need will require credentials, we describe them below. 

* **githubtoken_token**: GitHub API Token only, credentials type `Secret Text`  (for the PR pipeline)
* **githubtoken**: GitHub username and API Token
* **jenkins-api**: Username and API Token for Operations Center. Just like the one we used for Client Jar.

We also need to have a Global Pipeline Library defined by the name `github.com/joostvdg/jpl-core`. This, as the name suggests, should point to `https://github.com/joostvdg/jpl-core.git`.

## Create GitOps Pipeline

In total, we need two repositories and two or three Pipelines.
You can either use my CLI Docker Image or roll your own. I will proceed as if you will create your own.

* **CLI Image Pipeline**: this will create a CLI Docker Image that is used to talk to Operations Center via the Client Jar (CLI)
* **PR Pipeline**: I like the idea of Self-Service, but in order to keep things in check, you might want to provide that via a PullRequest (PR) rather than a direct write to the Master branch. This is also Repository One, as I prefer having each pipeline in their own Repository, but you don't need to.
* **Main Pipeline**: will trigger on a commit to the Master branch and create the new team. I'll even throw in a free ***manage your Team Recipes*** for free as well.

### Create CLI Image Pipeline

In a Kubernetes cluster, you should not build with Docker directly, use an in-cluster builder such as [Kaniko](https://github.com/GoogleContainerTools/kaniko) or [Buildah](https://buildah.io/). 

You can read more about the why and how [elsewhere on this site](/blogs/jenkins-pipeline-docker-alternatives/).

!!! tip 
	If you do not want to create your own, you can re-use my images.
	
	There should be one available for every recent version of CloudBees Core that will work with your Operations Center.
	The images are available in DockerHub at [caladreas/cbcore-cli](https://cloud.docker.com/u/caladreas/repository/docker/caladreas/cbcore-cli)

#### Kaniko Configuration

Kaniko uses a Docker Image to build your Docker Image in cluster. It does however need to directly communicate to your Docker Registry. This requires a Kubernetes `Secret` of type `docker-registry`.

How you can do this and more, you [can read on the CloudBees Core Docs](https://go.cloudbees.com/docs/cloudbees-core/cloud-install-guide/kubernetes-using-kaniko/).

#### Pipeline

Now that you have Kaniko configured, you can use this Pipeline to create your own CLI Images.

!!!	caution
	Make sure you replace the environment variables with values that make sense to you.

	* *CJOC_URL* internal url in Kubernets, usually `http://cjoc.<namespace>/cjoc`
	* *REGISTRY* : index.docker.io = DockerHub
	* *REPO*: docker repository name
	* *IMAGE*: docker image name

??? example "Jenkinsfile"
	Jenkins Declarative Pipeline for the CLI Image geberation.

	```groovy
    pipeline {
        agent {
            kubernetes {
            //cloud 'kubernetes'
            label 'test'
            yaml """
    kind: Pod
    metadata:
      name: test
    spec:
      containers:
      - name: curl
        image: byrnedo/alpine-curl
        command:
        - cat
        tty: true
        resources:
          requests:
            memory: "50Mi"
            cpu: "100m"
          limits:
            memory: "50Mi"
            cpu: "100m"
      - name: kaniko
        image: gcr.io/kaniko-project/executor:debug
        imagePullPolicy: Always
        command:
        - /busybox/cat
        tty: true
        resources:
          requests:
            memory: "50Mi"
            cpu: "100m"
          limits:
            memory: "50Mi"
            cpu: "100m"
        volumeMounts:
          - name: jenkins-docker-cfg
            mountPath: /root
      volumes:
      - name: jenkins-docker-cfg
        projected:
          sources:
          - secret:
              name: docker-credentials
              items:
                - key: .dockerconfigjson
                  path: .docker/config.json
    """
            }
        }
        environment {
            CJOC_URL    = 'http://cjoc.cloudbees-core/cjoc'
            CLI_VERSION = ''
            REGISTRY    = 'index.docker.io'
            REPO        = 'caladreas'
            IMAGE       = 'cbcore-cli'
        }
        stages {
            stage('Download CLI') {
                steps {
                    container('curl') {
                        sh 'curl --version'
                        sh 'echo ${CJOC_URL}/jnlpJars/jenkins-cli.jar'
                        sh 'curl ${CJOC_URL}/jnlpJars/jenkins-cli.jar --output jenkins-cli.jar'
                        sh 'ls -lath'
                    }
                }
            }
            stage('Prepare') {
                parallel {
                    stage('Verify CLI') {
                        environment {
                            CREDS   = credentials('jenkins-api')
                            CLI     = "java -jar jenkins-cli.jar -noKeyAuth -s ${CJOC_URL} -auth"
                        }
                        steps {
                            sh 'echo ${CLI}'
                            script {
                                CLI_VERSION = sh returnStdout: true, script: '${CLI} ${CREDS} version'
                            }
                            sh 'echo ${CLI_VERSION}'
                        }
                    }
                    stage('Prepare Dockerfile') {
                        steps {
                            writeFile encoding: 'UTF-8', file: 'Dockerfile', text: """FROM mcr.microsoft.com/java/jre-headless:8u192-zulu-alpine
    WORKDIR /usr/bin
    ADD jenkins-cli.jar .
    RUN pwd
    RUN ls -lath
    """
                        }
                    }
                }
            }
            stage('Build with Kaniko') {
                environment { 
                    PATH = "/busybox:/kaniko:$PATH"
                    TAG  = "${CLI_VERSION}"
                }
                steps {
                    sh 'echo image fqn=${REGISTRY}/${REPO}/${IMAGE}:${TAG}'
                    container(name: 'kaniko', shell: '/busybox/sh') {
                        sh '''#!/busybox/sh
                        /kaniko/executor -f `pwd`/Dockerfile -c `pwd` --cleanup --cache=true --destination=${REGISTRY}/${REPO}/${IMAGE}:${TAG}
                        /kaniko/executor -f `pwd`/Dockerfile -c `pwd` --cleanup --cache=true --destination=${REGISTRY}/${REPO}/${IMAGE}:latest
                        '''
                    }
                }
            }
        }
    }
	```

### PR Pipeline

!!!	caution
	The PR Pipeline example builds upon the GitHub API, if you're not using GItHub, you will have to figure out another way to make the PR.

#### Tools Used

* [yq](https://github.com/mikefarah/yq): commandline tool for processing Yaml files
* [jq](https://stedolan.github.io/jq/) commandline tool for pressing Json files 
* [Kustomize](https://kustomize.io) templating tool for Kubernetes Yaml, as of Kubernetes `1.13`, this is part of the Client (note, your server can be older, don't worry!)
* [Hub](https://github.com/github/hub) commandline client for GitHub

#### Repository Layout

* folder: `team-master-template`
    * with file `simple.json`
* folder: `namespace-creation`
    * with folder: `kustomize` this contains the [Kustomize](https://kustomize.io/) configuration

??? example "Simple.json"
	This is a template for the team JSON definition.

	```json
    {
        "version" : "1",
        "data": {
            "name": "NAME",
            "displayName": "DISPLAY_NAME",
            "provisioningRecipe": "RECIPE",
            "members": [
                {
                    "id": "ADMINS",
                    "roles": ["TEAM_ADMIN"]
                },
                {
                    "id": "MEMBERS",
                    "roles": ["TEAM_MEMBER"]
                },
                {
                    "id": "GUESTS",
                    "roles": ["TEAM_GUEST"]
                }
            ],
            "icon": {
                "name": "ICON",
                "color": "HEX_COLOR"
            }
        }
    }
	```

#### Kustomize Configuration

Kustomize is a tool for template Kubernetes YAML definitions, which is what we need here. However, only for the `namespace` creation & configuration. So if you don't want to do that, you can skip this.

The Kustomize configuration has two parts, a folder called `team-example` with a `kustomization.yaml`. This will be what we configure to generate a new yaml definition. The main template is in the folder `base`, where the entrypoint will be again `kustomization.yaml`. This time, the `kustomization.yaml` will link to all the template files we need.

As posting all these yaml files again is a bit much, I'll link to my example repo. Feel free to fork it instead: [cb-team-gitops-template](https://github.com/joostvdg/cb-team-gitops-template)

* [configmap.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/configmap.yaml): the Jenkins Agent ConfigMap
* [namespace.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/namespace.yaml): the new namespace
* [resource-quota.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/resource-quota.yaml): resource quota's for the namespace
* [role-binding-cjoc.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/role-binding-cjoc.yaml): a role binding for the CJOC ServiceAccount, so it create create the new Master in the new `namespace`
* [role-binding.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/role-binding.yaml): the role binding for the `jenkins` ServiceAccount, which allows the new Master to create and manage Pods (for PodTemplates)
* [role-cjoc.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/role-cjoc.yaml): the role for CJOC for the ability to create a Master in the new Namspace
* [role.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/role.yaml): the role for the `jenkins` ServiceAccount for the new Master
* [service-account.yaml](https://github.com/joostvdg/cb-team-gitops-template/blob/master/namespace-creation/kustomize/base/service-account.yaml): the ServiceAccount, `jenkins`, used by the new Master

#### Pipeline

The Pipeline will do the following:

* capture input parameters to be used to customize the Team Master
* update the Kustomize template to make sure every resource is correct for the new namespace (`teams-<name of team>`)
* execute Kustomize to generate a single `yaml` file that defines the configuration for the new Team Masters' namespace
* process the `simple.json` to generate a `team.json` file for the new Team Master for use with the Jenkins CLI
* checkout your GIT_REPO that contains your team definitions
* create a new PR to your GIT_REPO for the new team

??? example "Jenkinsfile"
	Variables to update:

	* **GIT_REPO**: the GitHub repository in which the Team Definitions are stored
	* **RESET_NAMESPACE**: the namespace Operations Center should use as default

	```groovy
      pipeline {
          agent {
              kubernetes {
              label 'team-automation'
              yaml """
      kind: Pod
      spec:
        containers:
        - name: hub
          image:  caladreas/hub
          command: ["cat"]
          tty: true
          resources:
            requests:
              memory: "50Mi"
              cpu: "150m"
            limits:
              memory: "50Mi"
              cpu: "150m"
        - name: kubectl
          image: bitnami/kubectl:latest
          command: ["cat"]
          tty: true
          securityContext:
            runAsUser: 1000
            fsGroup: 1000
          resources:
            requests:
              memory: "50Mi"
              cpu: "100m"
            limits:
              memory: "150Mi"
              cpu: "200m"
        - name: yq
          image: mikefarah/yq
          command: ['cat']
          tty: true
          resources:
            requests:
              memory: "50Mi"
              cpu: "100m"
            limits:
              memory: "50Mi"
              cpu: "100m"
        - name: jq
          image: colstrom/jq
          command: ['cat']
          tty: true
          resources:
            requests:
              memory: "50Mi"
              cpu: "100m"
            limits:
              memory: "50Mi"
              cpu: "100m"
              
      """
              }
          }
          libraries {
              lib('github.com/joostvdg/jpl-core')
          }
          options {
              disableConcurrentBuilds() // we don't want more than one at a time
              checkoutToSubdirectory 'templates' // we need to do two checkouts
              buildDiscarder logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '5', numToKeepStr: '5') // always clean up
          }
          environment {
              envGitInfo          = ''
              RESET_NAMESPACE     = 'jx-production'
              TEAM_BASE_NAME      = ''
              NAMESPACE_TO_CREATE = ''
              DISPLAY_NAME        = ''
              TEAM_RECIPE         = ''
              ICON                = ''
              ICON_COLOR_CODE     = ''
              ADMINS_ROLE         = ''
              MEMBERS_ROLE        = ''
              GUESTS_ROLE         = ''
              RECORD_LOC          = ''
              GIT_REPO                 = ''
          }
          stages {
              stage('Team Details') {
                  input {
                      message "Please enter the team details."
                      ok "Looks good, proceed"
                      parameters {
                          string(name: 'Name', defaultValue: 'hex', description: 'Please specify a team name')
                          string(name: 'DisplayName', defaultValue: 'Hex', description: 'Please specify a team display name')
                          choice choices: ['joostvdg', 'basic', 'java-web'], description: 'Please select a Team Recipe', name: 'TeamRecipe'
                          choice choices: ['anchor', 'bear', 'bowler-hat', 'briefcase', 'bug', 'calculator', 'calculatorcart', 'clock', 'cloud', 'cloudbees', 'connect', 'dollar-bill', 'dollar-symbol', 'file', 'flag', 'flower-carnation', 'flower-daisy', 'help', 'hexagon', 'high-heels', 'jenkins', 'key', 'marker', 'monocle', 'mustache', 'office', 'panther', 'paw-print', 'teacup', 'tiger', 'truck'], description: 'Please select an Icon', name: 'Icon'
                          string(name: 'IconColorCode', defaultValue: '#CCCCCC', description: 'Please specify a valid html hexcode for the color (https://htmlcolorcodes.com/)')
                          string(name: 'Admins', defaultValue: 'Catmins', description: 'Please specify a groupid or userid for the TEAM_ADMIN role')
                          string(name: 'Members', defaultValue: 'Pirates', description: 'Please specify a groupid or userid for the TEAM_MEMBER role')
                          string(name: 'Guests', defaultValue: 'Continental', description: 'Please specify a groupid or userid for the TEAM_GUEST role')
                      }
                  }
                  steps {
                      println "Name=${Name}"
                      println "DisplayName=${DisplayName}"
                      println "TeamRecipe=${TeamRecipe}"
                      println "Icon=${Icon}"
                      println "IconColorCode=${IconColorCode}"
                      println "Admins=${Admins}"
                      println "Members=${Members}"
                      println "Guests=${Guests}"
                      script {
                          TEAM_BASE_NAME      = "${Name}"
                          NAMESPACE_TO_CREATE = "cb-teams-${Name}"
                          DISPLAY_NAME        = "${DisplayName}"
                          TEAM_RECIPE         = "${TeamRecipe}"
                          ICON                = "${Icon}"
                          ICON_COLOR_CODE     = "${IconColorCode}"
                          ADMINS_ROLE         = "${Admins}"
                          MEMBERS_ROLE        = "${Members}"
                          GUESTS_ROLE         = "${Guests}"
                          RECORD_LOC          = "templates/teams/${Name}"
                          sh "mkdir -p ${RECORD_LOC}"
                      }
                  }
              }
              stage('Create Team Config') {
                  environment {
                      BASE        = 'templates/namespace-creation/kustomize'
                      NAMESPACE   = "${NAMESPACE_TO_CREATE}"
                      RECORD_LOC  = "templates/teams/${TEAM_BASE_NAME}"
                  }
                  parallel {
                      stage('Namespace') {
                          steps {
                              container('yq') {
                                  sh 'yq w -i ${BASE}/base/role-binding.yaml subjects[0].namespace ${NAMESPACE}'
                                  sh 'yq w -i ${BASE}/base/namespace.yaml metadata.name ${NAMESPACE}'
                                  sh 'yq w -i ${BASE}/team-example/kustomization.yaml namespace ${NAMESPACE}'
                              }
                              container('kubectl') {
                                  sh '''
                                      kubectl kustomize ${BASE}/team-example > ${RECORD_LOC}/team.yaml
                                      cat ${RECORD_LOC}/team.yaml
                                  '''
                              }
                          }
                      }
                      stage('Team Master JSON') {
                          steps {
                              container('jq') {
                                  sh """jq \
                                  '.data.name = "${TEAM_BASE_NAME}" |\
                                  .data.displayName = "${DISPLAY_NAME}" |\
                                  .data.provisioningRecipe = "${TEAM_RECIPE}" |\
                                  .data.icon.name = "${ICON}" |\
                                  .data.icon.color = "${ICON_COLOR_CODE}" |\
                                  .data.members[0].id = "${ADMINS_ROLE}" |\
                                  .data.members[1].id = "${MEMBERS_ROLE}" |\
                                  .data.members[2].id = "${GUESTS_ROLE}"'\
                                  templates/team-master-template/simple.json > ${RECORD_LOC}/team.json
                                  """
                              }
                              sh 'cat ${RECORD_LOC}/team.json'
                          }
                      }
                  }
              }
              stage('Create PR') {
                  when { branch 'master'}
                  environment {
                      RECORD_OLD_LOC  = "templates/teams/${TEAM_BASE_NAME}"
                      RECORD_LOC      = "teams/${TEAM_BASE_NAME}"
                      PR_CHANGE_NAME  = "add_team_${TEAM_BASE_NAME}"
                  }
                  steps {
                      container('hub') {
                          dir('cb-team-gitops') {
                              script {
                                  envGitInfo = git "${GIT_REPO}"
                              }
                              sh 'git checkout -b ${PR_CHANGE_NAME}'
                              sh 'ls -lath ../${RECORD_OLD_LOC}'
                              sh 'cp -R ../${RECORD_OLD_LOC} ./teams'
                              sh 'ls -lath'
                              sh 'ls -lath teams/'

                              gitRemoteConfigByUrl(envGitInfo.GIT_URL, 'githubtoken_token') // must be a API Token ONLY -> secret text
                              sh '''
                              git config --global user.email "jenkins@jenkins.io"
                              git config --global user.name "Jenkins"
                              git add ${RECORD_LOC}
                              git status
                              git commit -m "add team ${TEAM_BASE_NAME}"
                              git push origin ${PR_CHANGE_NAME}
                              '''


                              // has to be indented like that, else the indents will be in the pr description
                              writeFile encoding: 'UTF-8', file: 'pr-info.md', text: """Add ${TEAM_BASE_NAME}
      \n
      This pr is automatically generated via CloudBees.\\n
      \n
      The job: ${env.JOB_URL}
                          """

                              // TODO: unfortunately, environment {}'s credentials have fixed environment variable names
                              // TODO: in this case, they need to be EXACTLY GITHUB_PASSWORD and GITHUB_USER
                              script {
                                  withCredentials([usernamePassword(credentialsId: 'githubtoken', passwordVariable: 'GITHUB_PASSWORD', usernameVariable: 'GITHUB_USER')]) {
                                      sh """
                                      set +x
                                      hub pull-request --force -F pr-info.md -l '${TEAM_BASE_NAME}' --no-edit
                                      """
                                  }
                              }
                          }
                      }
                  }
              }
          }
      }
	```

### Main Pipeline

The main Pipeline should be part of a repository. The Repository should look like this:

* `recipes` (folder)
    * `recipes.json` -> current complete list of CloudBees Core Team Recipes definition
* `teams` (folder)
    * folder per team
        * `team.json` -> CloudBees Core Team definition
        * `team.yaml` -> Kubernetes YAML definition of the `namespace` and all its resources

#### Process

The pipeline can be a bit hard to grasp, so let me break it down into individual steps.

We have the following stages:

* `Create Team` - which is broken into sub-stages via the [sequential stages feature](https://jenkins.io/blog/2018/07/02/whats-new-declarative-piepline-13x-sequential-stages/).
        * `Parse Changelog`
        * `Create Namespace`
        * `Change OC Namespace`
        * `Create Team Master`
* `Test CLI Connection`
* `Update Team Recipes`

#### Notable Statements

??? example "disableConcurrentBuilds"
	We change the `namespace` of Operation Center to a different value only for the duration of creating this master. This is something that should probably be part of the Team Master creation, but as it is a single configuration option for all that Operation Center does, we need to be careful. By ensuring we only run one build concurrently, we reduce the risk of this blowing up in our face.

	```groovy
    options {
        disableConcurrentBuilds()
    }
	```

??? example "when { }"
	The [When Directive](https://jenkins.io/doc/book/pipeline/syntax/#when) allows us to creating effective conditions for when a stage should be executed.
	
	The snippet below shows the use of a combination of both the `branch` and `changeset` built-in filters. `changeset` looks at the commit being build and validates that there was a change in that file path.

	```groovy
        when { allOf { branch 'master'; changeset "teams/**/team.*" } }
	```

??? example "post { always { } }"
	The [Post Directive](https://jenkins.io/doc/book/pipeline/syntax/#post) allows us to run certain commands after the main pipeline has run depending on the outcome (compared or not to the previous outcome). In this case, we want to make sure we reset the `namespace` used by Operations Center to the original value.

	By using `post { always {} }`, it will ALWAYS run, regardless of the status of the pipeline. So we should be safe.

	```groovy
    post {
        always {
            container('cli') {
                sh '${CLI} ${CREDS} groovy = < resources/bootstrap/configure-oc-namespace.groovy ${RESET_NAMESPACE}'
            }
        }
    }
	```

??? example "stages { stage { parallel { stage() { stages { stage { "
	Oke, you might've noticed this massive indenting depth and probably have some questions. 

	By combining [sequential stages](https://jenkins.io/blog/2018/07/02/whats-new-declarative-piepline-13x-sequential-stages/) with [parallel stages](https://jenkins.io/blog/2017/09/25/declarative-1/) we can create a set of stages that will be executed in sequence but can be controlled by a single `when {} ` statement whether or not they get executed. 

	This prevents mistakes being made in the condition and accidentally running one or other but not all the required steps.

	```groovy
        stages {
            stage('Create Team') {
                parallel {
                    stage('Main') {
                        stages {
                            stage('Parse Changelog') {
	```


??? example "changetSetData & container('jpb') {}"
	Alright, so even if we know a team was added in `/teams/<team-name>`, we still don't know the following two things: 1) what is the name of this team, 2) was this team changed or deleted?

	So we have to process the changelog to be able to answer these questions as well. There are different ways of getting the changelog and parsing it. I've written one you can do on ANY machine, regardless of Jenkins by leveraging `Git` and my own custom binary (`jpb` -> Jenkins Pipeline Binary). The code for my binary is at GitHub: [github.com/joostvdg/jpb](https://github.com/joostvdg/jpb).

	An alternative approach is described by [CloudBees Support here](https://support.cloudbees.com/hc/en-us/articles/217630098-How-to-access-Changelogs-in-a-Pipeline-Job-), which leverages Jenkins groovy powers.

	```groovy
    COMMIT_INFO = "${scmVars.GIT_COMMIT} ${scmVars.GIT_PREVIOUS_COMMIT}"
    def changeSetData = sh returnStdout: true, script: "git diff-tree --no-commit-id --name-only -r ${COMMIT_INFO}"
    changeSetData = changeSetData.replace("\n", "\\n")
    container('jpb') {
        changeSetFolders = sh returnStdout: true, script: "/usr/bin/jpb/bin/jpb GitChangeListToFolder '${changeSetData}' 'teams/'"
        changeSetFolders = changeSetFolders.split(',')
    }
	```

#### Files

??? example "recipes.json"
	The default Team Recipes that ships with CloudBees Core Modern.

	```JSON
        {
            "version": "1",
            "data": [{
                "name": "basic",
                "displayName": "Basic",
                "description": "The minimalistic setup.",
                "plugins": ["bluesteel-master", "cloudbees-folders-plus", "cloudbees-jsync-archiver", "cloudbees-monitoring", "cloudbees-nodes-plus", "cloudbees-ssh-slaves", "cloudbees-support", "cloudbees-workflow-template", "credentials-binding", "email-ext", "git", "git-client", "github-branch-source", "github-organization-folder", "infradna-backup", "ldap", "mailer", "operations-center-analytics-reporter", "operations-center-cloud", "pipeline-model-definition", "ssh-credentials", "wikitext", "workflow-aggregator", "workflow-cps-checkpoint"],
                "default": true
            }, {
                "name": "java-web",
                "displayName": "Java & Web Development",
                "description": "The essential tools to build, release and deploy Java Web applications including integration with Maven, Gradle and Node JS.",
                "plugins": ["bluesteel-master", "cloudbees-folders-plus", "cloudbees-jsync-archiver", "cloudbees-monitoring", "cloudbees-nodes-plus", "cloudbees-ssh-slaves", "cloudbees-support", "cloudbees-workflow-template", "credentials-binding", "email-ext", "git", "git-client", "github-branch-source", "github-organization-folder", "infradna-backup", "ldap", "mailer", "operations-center-analytics-reporter", "operations-center-cloud", "pipeline-model-definition", "ssh-credentials", "wikitext", "workflow-aggregator", "workflow-cps-checkpoint", "config-file-provider", "cloudbees-aws-cli", "cloudbees-cloudfoundry-cli", "findbugs", "gradle", "jira", "junit", "nodejs", "openshift-cli", "pipeline-maven", "tasks", "warnings"],
                "default": false
            }]
        }
	```

??? example "Jenkinsfile"
	This is the pipeline that will process the commit to the repository and, if it detects a new team is created will apply the changes.

	Variables to overwrite:
	
	* **GIT_REPO**: the https url to the Git Repository your GitOps code/configuration is stored
	* **RESET_NAMESPACE**: the `namespace` your Operation Center normally operates in
	* **CLI**: this command depends on the namespace Operation Center is in (`http://<service name>.<namespace>/cjoc`)

	```groovy
    pipeline {
        agent {
            kubernetes {
                label 'jenkins-agent'
                yaml '''
    apiVersion: v1
    kind: Pod
    spec:
      serviceAccountName: jenkins
      containers:
      - name: cli
        image: caladreas/cbcore-cli:2.176.2.3
        imagePullPolicy: Always
        command:
        - cat
        tty: true
        resources:
          requests:
            memory: "50Mi"
            cpu: "150m"
          limits:
            memory: "50Mi"
            cpu: "150m"
      - name: kubectl
        image: bitnami/kubectl:latest
        command: ["cat"]
        tty: true
        resources:
          requests:
            memory: "50Mi"
            cpu: "100m"
          limits:
            memory: "150Mi"
            cpu: "200m"
      - name: yq
        image: mikefarah/yq
        command: ['cat']
        tty: true
        resources:
          requests:
            memory: "50Mi"
            cpu: "100m"
          limits:
            memory: "50Mi"
            cpu: "100m"
      - name: jpb
        image: caladreas/jpb
        command:
        - cat
        tty: true
        resources:
          requests:
            memory: "50Mi"
            cpu: "100m"
          limits:
            memory: "50Mi"
            cpu: "100m"
      securityContext:
        runAsUser: 1000
        fsGroup: 1000
    '''
            }
        }
        options {
            disableConcurrentBuilds()
            buildDiscarder logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '5', numToKeepStr: '5')
        }
        environment {
            RESET_NAMESPACE     = 'cloudbees-core'
            CREDS               = credentials('jenkins-api')
            CLI                 = "java -jar /usr/bin/jenkins-cli.jar -noKeyAuth -s http://cjoc.cloudbees-core/cjoc -auth"
            COMMIT_INFO         = ''
            TEAM                = ''
            GIT_REPO            = ''
        }
        stages {
            stage('Create Team') {
                when { allOf { branch 'master'; changeset "teams/**/team.*" } }
                parallel {
                    stage('Main') {
                        stages {
                            stage('Parse Changelog') {
                                steps {
                                    // Alternative approach: https://support.cloudbees.com/hc/en-us/articles/217630098-How-to-access-Changelogs-in-a-Pipeline-Job-
                                    // However, that runs on the master, JPB runs in an agent!
                                    script {
                                        scmVars = git "${GIT_REPO}"
                                        COMMIT_INFO = "${scmVars.GIT_COMMIT} ${scmVars.GIT_PREVIOUS_COMMIT}"
                                        def changeSetData = sh returnStdout: true, script: "git diff-tree --no-commit-id --name-only -r ${COMMIT_INFO}"
                                        changeSetData = changeSetData.replace("\n", "\\n")
                                        container('jpb') {
                                            changeSetFolders = sh returnStdout: true, script: "/usr/bin/jpb/bin/jpb GitChangeListToFolder '${changeSetData}' 'teams/'"
                                            changeSetFolders = changeSetFolders.split(',')
                                        }
                                        if (changeSetFolders.length > 0) {
                                            TEAM = changeSetFolders[0]
                                            TEAM = TEAM.trim()
                                            // to protect against a team being removed
                                            def exists = fileExists "teams/${TEAM}/team.yaml"
                                            if (!exists) {
                                                TEAM = ''
                                            }
                                        } else {
                                            TEAM = ''
                                        }
                                        echo "Team that changed: |${TEAM}|"
                                    }
                                }
                            }
                            stage('Create Namespace') {
                                when { expression { return !TEAM.equals('') } }
                                environment {
                                    NAMESPACE   = "cb-teams-${TEAM}"
                                    RECORD_LOC  = "teams/${TEAM}"
                                }
                                steps {
                                    container('kubectl') {
                                        sh '''
                                            cat ${RECORD_LOC}/team.yaml
                                            kubectl apply -f ${RECORD_LOC}/team.yaml
                                        '''
                                    }
                                }
                            }
                            stage('Change OC Namespace') {
                                when { expression { return !TEAM.equals('') } }
                                environment {
                                    NAMESPACE   = "cb-teams-${TEAM}"
                                }
                                steps {
                                    container('cli') {
                                        sh 'echo ${NAMESPACE}'
                                        script {
                                            def response = sh encoding: 'UTF-8', label: 'create team', returnStatus: true, script: '${CLI} ${CREDS} groovy = < resources/bootstrap/configure-oc-namespace.groovy ${NAMESPACE}'
                                            println "Response: ${response}"
                                        }
                                    }
                                }
                            }
                            stage('Create Team Master') {
                                when { expression { return !TEAM.equals('') } }
                                environment {
                                    TEAM_NAME = "${TEAM}"
                                }
                                steps {
                                    container('cli') {
                                        println "TEAM_NAME=${TEAM_NAME}"
                                        sh 'ls -lath'
                                        sh 'ls -lath teams/'
                                        script {
                                            def response = sh encoding: 'UTF-8', label: 'create team', returnStatus: true, script: '${CLI} ${CREDS} teams ${TEAM_NAME} --put < "teams/${TEAM_NAME}/team.json"'
                                            println "Response: ${response}"
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            stage('Test CLI Connection') {
                steps {
                    container('cli') {
                        script {
                            def response = sh encoding: 'UTF-8', label: 'retrieve version', returnStatus: true, script: '${CLI} ${CREDS} version'
                            println "Response: ${response}"
                        }
                    }
                }
            }
            stage('Update Team Recipes') {
                when { allOf { branch 'master'; changeset "recipes/recipes.json" } }
                steps {
                    container('cli') {
                        sh 'ls -lath'
                        sh 'ls -lath recipes/'
                        script {
                            def response = sh encoding: 'UTF-8', label: 'update team recipe', returnStatus: true, script: '${CLI} ${CREDS} team-creation-recipes --put < "recipes/recipes.json"'
                            println "Response: ${response}"
                        }
                    }
                }
            }
        }
        post {
            always {
                container('cli') {
                    sh '${CLI} ${CREDS} groovy = < resources/bootstrap/configure-oc-namespace.groovy ${RESET_NAMESPACE}'
                }
            }
        }
    }        
	```
