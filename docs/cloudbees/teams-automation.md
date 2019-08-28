# Core Modern Teams Automation

CloudBees Core on Modern (meaning, on Kubernetes) has two main types of Jenkins Masters, a Managed Master, and a Team Master. In this article, we're going to automate the creation and management of the Team Masters.

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