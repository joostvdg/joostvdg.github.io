title: Jenkins integration with TAP
description: How to integrate Jenkins with Tanzu Application Platform

# Jenkins and Tanzu Application Platform


## Ways to combine TAP with Jenkins

* Jenkins + Image To URL:  Use Jenkins as a CI solution, ending with a Container Image. Jenkins then initiates the handover by triggering an Image To Source supply chain.
* Jenkins + Maven Artifact To URL: Use Jenkins as a CI solution; instead of the handover point being a Container Image, it is a Maven Artifact. TAP can watch (or is there an Event system?) Maven Artifacts and trigger a Cartographer supply chain (which includes generating the Container Image)

## Jenkins and Image To URL

* TAP setup
* Jenkins setup
* Cartographer SupplyChain
* Application Pipeline

### TAP setup

* Harbor with custom Certificate Authority (CA)
* TAP with iterate or run profile
* Register Application (Workload)

...

### Jenkins setup

* Jenkins in the same cluster
* Use JCasC
* Use Shared Libraries
* Use Declarative Pipeline

### Cartographer SupplyChain

* Use Out Of The Box (OOTB) supply chains
	* especially "Image To URL"
* Verify the trigger keyword (annotation for workload)

### Application Pipeline

* Trigger update by updating the workload CR
* Git event triggers start 
* Build and test application
* Build and test Container Image with the application
* Push and Label Container Image
* Show Diagram

## Jenkins and Maven Artifact To URL

TODO

## References