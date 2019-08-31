title: Your Own Kubernetes CRD
description: How To Create Your Own Kubernetes Customer Resource Definition


# Kubernetes CRD

Kubernetes is a fantastic platform that allows you to run a lot of different workloads in various ways. It has APIs front and center, allowing you to choose different implementation as they suit you.

Sometimes you feel something is missing. There is a concept with your application or something you want from the cluster that isn't (however) available in Kubernetes.

It is then that you can look for extending Kubernetes itself. Either its API or by creating a new kind of resource: a Custom Resource Definition or CRD.

## What you need

* **resource definition**: the yaml  definition of your custom resource
* **custom controller**: a controller to interact with your custom resource


### Resource Definition

As with any Kubernetes resource, you need a yaml file that defines it with the lexicon of Kubernetes. In this case, the **Kind** is `CustomerResourceDefinition`.

```YAML
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: manifests.cat.kearos.net
spec:
  group: cat.kearos.net
  version: v1
  names:
    kind: ApplicationManifest
    plural: applicationmanifests
    singular: applicationmanifest
    shortNames:
      - cam
  scope: Namespaced
```

* **apiVersion**: as the name implies, it's an API extension
* **kind**:  has to be `CustomResourceDefinition` else it wouldn't be a CRD
* **name**:  name must match the spec fields below, and be in the form: <plural>.<group>
* **group**:  API group name so that you can group multiple resources somewhat together
* **names**: 
	* **kind**: the resource kind, used for other resource definitions
	* **plural** is the official name used in the Kubernetes API, also the default for interaction with `kubectl`
	* **singular**:  alias for the API usage in kubectl and used as the display value
	* **shortNames**: shortNames allow a shorter string to match your resource on the CLI
* **scope**:  can either be `Namespaced`, tied to a specific namespace, or `Cluster` where it must be cluster-wide unique

#### Install CRD

Taking the above example and saving it as `application-manifest.yml`, we can install the CRD into the cluster as follows.

```bash
kubectl create -f application-manifest.yml
```

### Resource Usage Example

```YAML
apiVersion: cat.kearos.net/v1
kind: ApplicationManifest
metadata:
    name: manifest-cat
spec:
    name: cat
    description: Central Application Tracker
    namespace: cat
    artifactIDs:
        - github.com/joostvdg/cat
    sources:
        - git@github.com:joostvdg/cat.git
```

Looking at this example, you might wonder how this works.
There is a specification in there - `spec` - with all kinds of custom fields. But where do they come from?

Nowhere really, so you cannot validate this with the CRD alone. You can put any arbitrary field in there. 

So what do you do with the CRD then?
You can create a custom controller that processes your custom resources.
Because creating a custom controller for your custom resources is complicated and takes several steps, we will do this in a separate article.
