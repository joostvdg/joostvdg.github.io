title: Jenkins Build Docker w/ Kaniko
description: Build Docker Images with Jenkins on Kubernetes with Kaniko (Azure)

# Kaniko Pipelines

Kaniko[^1] is one of the recommended tools for building Docker images within Kubernetes, especially when you build them as part of a Jenkins Pipeline.
I've written about [why you should use Kaniko](/blogs/docker-alternatives/)(or similar) tools, the rest assumes you want to use Kaniko within your pipeline.

!!! quote
    [Kaniko](https://github.com/GoogleContainerTools/kaniko#kaniko---build-images-in-kubernetes) is a tool to build container images from a Dockerfile, inside a container or Kubernetes cluster.

    kaniko doesn't depend on a Docker daemon and executes each command within a Dockerfile completely in userspace. This enables building container images in environments that can't easily or securely run a Docker daemon, such as a standard Kubernetes cluster.

For more examples for leveraging Kaniko when using Jenkins in Kubernetes, you can look at the documentation from CloudBees Core[^2].

## Pipeline Example

!!! note
    The Kaniko logger uses ANSI Colors, which can be represented via the [Jenkins ANSI Color Plugin](https://github.com/jenkinsci/ansicolor-plugin).

    If you have the plugin installed, you can do something like the snipped below to render the colors.

    ```groovy
    container(name: 'kaniko', shell: '/busybox/sh') {
        ansiColor('xterm') {
            sh '''#!/busybox/sh
            /kaniko/executor -f `pwd`/Dockerfile.run -c `pwd` --cache=true --destination=${REGISTRY}/${REPOSITORY}/${IMAGE}
            '''
        }
    }
    ```

```bash
pipeline {
    agent {
        kubernetes {
            label 'kaniko'
            yaml """
kind: Pod
metadata:
  name: kaniko
spec:
  containers:
  - name: golang
    image: golang:1.12
    command:
    - cat
    tty: true
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    imagePullPolicy: Always
    command:
    - /busybox/cat
    tty: true
    volumeMounts:
      - name: jenkins-docker-cfg
        mountPath: /kaniko/.docker
  volumes:
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: registry-credentials
          items:
            - key: .dockerconfigjson
              path: config.json
"""
        }
    }
    stages {
        stage('Checkout') {
            steps {
                git 'https://github.com/joostvdg/cat.git'
            }
        }
        stage('Build') {
            steps {
                container('golang') {
                    sh './build-go-bin.sh'
                }
            }
        }
        stage('Make Image') {
            environment {
                PATH        = "/busybox:$PATH"
                REGISTRY    = 'index.docker.io' // Configure your own registry
                REPOSITORY  = 'caladreas'
                IMAGE       = 'cat'
            }
            steps {
                container(name: 'kaniko', shell: '/busybox/sh') {
                    sh '''#!/busybox/sh
                    /kaniko/executor -f `pwd`/Dockerfile.run -c `pwd` --cache=true --destination=${REGISTRY}/${REPOSITORY}/${IMAGE}
                    '''
                }
            }
        }
    }
}
```

## Configuration

Kaniko relies on a docker secret for directly communicating to a Docker Registry. This can be supplied in various ways, but the most common is to create a Kubernetes Secret of type `docker-registry`.

```bash
kubectl create secret docker-registry registry-credentials \  
    --docker-username=<username>  \
    --docker-password=<password> \
    --docker-email=<email-address>
```

We can then mount it in the pod via `Volumes` (PodSpec level) and `volumeMounts` (Container level).

```yaml
  volumes:
  - name: jenkins-docker-cfg
    projected:
      sources:
      - secret:
          name: docker-credentials
          items:
            - key: .dockerconfigjson
              path: config.json
```

## Azure & ACR

Of course, there always have to be difference between the Public Cloud Providers (AWS, Azure, Alibaba, GCP).

In the case of Kaniko, its Azure that does things differently.

Assuming you want to leverage Azure Container Registry (ACR), you're in Azure after all, you will have to do a few things differently.

### Create ACR

You can use the Azure CLI[^5] or an Configuration-As-Code Tool such as Terraform[^6].

#### Azure CLI

First, create a resource group.

```bash
az group create --name myResourceGroup --location eastus
```

And then create the ACR.

```bash
az acr create --resource-group myResourceGroup --name myContainerRegistry007 --sku Basic
```

#### Terraform

We leverage the `azurerm` backend of terraform[^9][^10].

```terraform
resource "azurerm_resource_group" "acr" {
    name     = "${var.resource_group_name}-acr"
    location = "${var.location}"
}

resource "azurerm_container_registry" "acr" {
    name                     = "${var.container_registry_name}"
    resource_group_name      = "${azurerm_resource_group.acr.name}"
    location                 = "${azurerm_resource_group.k8s.location}"
    sku                      = "Premium"
    admin_enabled            = false
}
```

### Configure Access to ACR

Now that we have an ACR, we need to be able to pull and images from and to the registry.

This requires access credentials, which we can create in several ways, we'll explore via ServicePrinciple.

#### Via ServicePrinciple Credentials

The commands below are taken from the Azure Container Registry documentation about authentication[^7].

First, lets setup some values that are not derived from something.

```bash
EMAIL=me@example.com
SERVICE_PRINCIPAL_NAME=acr-service-principal
ACR_NAME=myacrinstance
```

Second, we fetch the basic information about the registry we have. We need this information for the other commands.

```bash
ACR_LOGIN_SERVER=$(az acr show --name $ACR_NAME --query loginServer --output tsv)
ACR_REGISTRY_ID=$(az acr show --name $ACR_NAME --query id --output tsv)
```

Now we can create a ServicePrinciple with just the rights we need[^8]. 
In the case of Kaniko, we need Push and Pull rights, which are both captured in the role `acrpush`.

```bash
SP_PASSWD=$(az ad sp create-for-rbac --name http://$SERVICE_PRINCIPAL_NAME --role acrpush --scopes $ACR_REGISTRY_ID --query password --output tsv)
CLIENT_ID=$(az ad sp show --id http://$SERVICE_PRINCIPAL_NAME --query appId --output tsv)
```

```bash
kubectl create secret docker-registry registry-credentials --docker-server ${ACR_LOGIN_SERVER} --docker-username ${CLIENT_ID} --docker-password ${SP_PASSWD} --docker-email ${EMAIL}
```

## References

[^1]: [Kaniko GitHub](https://github.com/GoogleContainerTools/kaniko)
[^2]: [CloudBees Guide On Using Kaniko With CloudBees Core](https://go.cloudbees.com/docs/cloudbees-core/cloud-install-guide/kubernetes-install/#_using_kaniko_with_cloudbees_core)
[^3]: [Sail CI On Kaniko With Azure Container Registry](https://sail.ci/docs/build-and-push-docker-containers-within-a-pipeline-azure-container-registry)
[^4]: [Create Azure Container Registry With Azure CLI](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-azure-cli)
[^5]: [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
[^6]: [Terraform](https://www.terraform.io/)
[^7]: [Azure Container Registry Authentication Documentation](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-auth-aks)
[^8]: [Azure Container Registry Roles and Permissions](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-roles)
[^9]: [Terraform AzureRM Backend](https://www.terraform.io/docs/providers/azurerm/index.html)
[^10]: [Create AKS Cluster Via Terraform](https://joostvdg.github.io/kubernetes/distributions/aks-terraform/)
[^11]: [Azure Container Registry Credentials Management](https://docs.microsoft.com/en-us/cli/azure/acr/credential?view=azure-cli-latest)
