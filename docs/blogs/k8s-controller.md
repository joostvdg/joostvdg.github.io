# Create your own custom Kubernetes controller

Before we dive into the why and how of creating a Kubernetes Controller, let's take a brief look at what it does.

## What is a Controller

I will only briefly touch on what a controller is. If you already know what it is you can safely skip this paragraph. 

>  In applications of robotics and automation, a control loop is a non-terminating loop that regulates the state of the system. In Kubernetes, a controller is a control loop that watches the shared state of the cluster through the API server and makes changes attempting to move the current state towards the desired state. Examples of controllers that ship with Kubernetes today are the replication controller, endpoints controller, namespace controller, and serviceaccounts controller.

So the purpose of controllers is to control - hence the name - the state of the system - our Kubernetes cluster. A controller is generally created to watch a single resource type and make sure that its desired state is met.

As there is already very well written material on the details of controllers, I'll leave it at this. For more information on controllers and how they work, I recommend reading [bitnami's deepdive](https://engineering.bitnami.com/articles/a-deep-dive-into-kubernetes-controllers.html) and the [kubernetes documentation](https://kubernetes.io/docs/concepts/overview/components/#kube-controller-manager).

## When to create your controller

Great, you're still reading this. So when would you put in the effort to create your controller?

I'm pretty sure there will be more cases, but the following two are the main ones.

* Process events on Core resources, Core being the resources any Kubernetes ships with
* Process events on Customer resources

Examples of customer controllers for the first use case are tools such as Kubediff, which will compare resources in the cluster with their definition in a Git repository.

For the second use case - custom controller for custom resource - there are many more examples. As most custom resources will have their controller to act on the events of the resources because existing controllers will not process the custom resource. Additionally, in most cases having resources sitting in a cluster with nothing happening is a bit of a waste. So we write a controller to match the resource.

## How to create your controller

When it comes to making a controller, it will be some Go (lang) code using the Kubernetes client library. This is straightforward if you're creating a controller for the core resources, but quite a few steps if you write a custom controller.

### Write a core resource controller

To ease ourselves into it lets first create a core resource controller.

We're aiming for a controller that can read our ConfigMaps resources. To be able to do this, we need the following:

* **Handler**: for the events (Created, Deleted, Updated)
* **Controller**: retrieves events from an informer, puts work on a queue, and delegates the events to the handler
* **Entrypoint**: typically a main.go file, that creates a connection to the Kubernetes API server and ties all of the resources together
* **Dockerfile**: to package our binary for running inside the cluster
* **Resource Definition YAML**: typical Kubernetes resource definition file, in our case a Deployment, so our controller will run as a pod/container

#### Handler

#### Controller

#### Entrypoint

#### Dockerfile

#### Resource Definition

## Resources

* https://medium.com/@trstringer/create-kubernetes-controllers-for-core-and-custom-resources-62fc35ad64a3
* https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/
* https://coreos.com/blog/introducing-operators.html
* https://engineering.bitnami.com/articles/a-deep-dive-into-kubernetes-controllers.html
* https://github.com/joostvdg/k8s-core-resource-controller
* https://github.com/kubernetes/sample-controller/blob/master/controller.go