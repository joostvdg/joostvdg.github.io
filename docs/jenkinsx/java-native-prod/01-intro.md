title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Introduction - 1/8
hero: Introduction - 1/8

# Introduction

## Stack

* **Google Cloud Platform(GCP)**: while you can do evyrthing required with other providers, I've chosen GCP
* **Kubernetes**: in particular, **GKE**
* **Jenkins X**: CI/CD
* **Helm**: packaging our Kubernetes application
    * managed by Jenkins X (_to a degree_)
* **Google Cloud SQL**(MySQL): our data storage
* **HashiCorp Vault**: secrets storage
* **Quarkus**: our Java framework
    * Spring Data JPA for ORM
    * Spring Web for the REST API
* **Java 11**
* **GraalVM**: compiler/runtime to create a native executable of our Java code

## What We Will Do

The outline of the steps to take is below. Each has its own page, so if you feel you have.

* Create Google Cloud SQL (MySql flavor) as datasource (we're on GCP afterall)
* Create Quarkus application 
* Import the application into Jenkins X
* Change the Build to Native Image (with GraalVM)
* Retrieve application secrets (such as Database username/password) from HashiCorp Vault
* Productionalize our Pipeline
    * Static Code Analysis with SonarQube/SonarCloud
    * Dependency Vulnerability scan with Sonatype's OSS Index
    * Integration Tests
* Productionalize our Applications
    * Monitoring with Prometheus & Grafana
    * Tracing with OpenTracing & Jaeger
    * Manage our logs with Sentry.io

## Pre-requisites

The pre-requisites are a Kubernetes Cluster with Jenkins X installed, including Haschicorp Vault integration. The guide assumes you use GKE, we will create our MySQL database there, but should be reproducable on other Kubernetes services where Jenkins X supports Hashicorp Vault (currently GKE and AWS's EKS).

If you want to focus on a stable production ready cluster, I can also recommend to use [CloudBees' distribution of Jenkins X](https://docs.cloudbees.com/docs/cloudbees-jenkins-x-distribution/latest/). Don't worry, this is also free with no caveats, but has a slower release candence to focus more on stability than the OSS mainline does.

* GKE Cluster: 
    * [GKE via Terraform](https://joostvdg.github.io/kubernetes/distributions/gke-terraform/)
    * [GKE via Gcloud](https://cloud.google.com/kubernetes-engine/docs/quickstart)
    * [GKE via Jenkins X's Terraform module](https://jenkins-x.io/docs/getting-started/)
* EKS Cluster:
    * [EKS via Jenkins X's Terraform module](https://registry.terraform.io/modules/jenkins-x/eks-jx/aws/0.2.1)
    * [EKS via EKSCTL](https://eksctl.io/)
    * [EKS](https://aws.amazon.com/blogs/startups/from-zero-to-eks-with-terraform-and-helm/)
* Jenkins X: 
    * [Jenkins X Getting Started on GKE Guide](https://jenkins-x.io/docs/getting-started/)
    * [CloudBees Jenkins X Distribution](https://docs.cloudbees.com/docs/cloudbees-jenkins-x-distribution/latest/)
    * [Youtube video with installation and maintenance guidance](https://www.youtube.com/watch?v=rQlP_3iXvRE)

## Why Quarkus

Before we start, I'd like to make the case, why I chose to use Quarkus for this.

Wanting to build a Native Image with Java 11 is part of the reason, we'll dive into that next.

Quarkus has seen an tremendous amount of updates since its inception. 
It is a really active framework, which does not require you to forget everything you've learned in other Java frameworks such as Spring and Spring Boot.

It comes out of the same part from RedHat that is involved with OpenShift - RedHat's Kubernetes distribution.
This ensures the framework is created with running Java on Kubernetes in mind. 
Jenkins X starts from Kubernetes, so this makes it a natural fit.

Next, the capabilities for making a Native Image and work done to ensure you - the developer - do not have to worry (too much) about how to get from a Spring application to a Native Image is staggering. This makes the Native Image experience pleasant and involve little to no debugging.

## Why Native Image

Great that Quarkus helps with making a Native Image. What is a Native Image?
In short, its makes your Java code into a runnable executable build for a specific environment.

You might wonder, what is wrong with using a runnable Jar - such as Spring Boot - or using a JVM?
Nothing in and on itself. However, there are cases where having a long running process with a slow start-up time hurts you.

In a Cloud Native world, including Kubernetes, this is far more likely than in traditional - read, VM's - environments. With the advent of creating many smaller services that may or may not be stateless, and should be capable of scaling horizontally from 0 to infinity, different characteristics are required.

Some of these characterics:

* minimal resource use as we pay per usage (to a degree)
* fast startup time
* perform as expected on startup (JVM needs to warm up)

A Native Image performs better on the above metrics than a classic Java application with a JVM.
Next to that, when you have a fixed runtime, the benefit of Java's "build once, run everywhere" is not as useful. When you always run your application in the same container in similar Kubernetes environments, a Native Image is perfectly fine.

Now, wether a Native Image performs better for your application depends on your application and its usage. The Native Image is no silver bullet. So it is still on you to do load and performance tests to ensure you're not degrading your performance for no reason!

## Resources

* https://quarkus.io/guides/writing-native-applications-tips
* https://quarkus.io/guides/building-native-image
* https://cloud.google.com/community/tutorials/run-spring-petclinic-on-app-engine-cloudsql
* https://github.com/GoogleCloudPlatform/community/tree/master/tutorials/run-spring-petclinic-on-app-engine-cloudsql/spring-petclinic/src/main/resources
* https://github.com/GoogleCloudPlatform/google-cloud-spanner-hibernate/blob/master/google-cloud-spanner-hibernate-samples/quarkus-jpa-sample
* https://medium.com/@hantsy/kickstart-your-first-quarkus-application-cde54f469973
* https://developers.redhat.com/blog/2020/04/10/migrating-a-spring-boot-microservices-application-to-quarkus/
* https://www.baeldung.com/rest-assured-header-cookie-parameter
* https://jenkins-x.io/docs/reference/pipeline-syntax-reference/#containerOptions
* https://openliberty.io/blog/2020/04/09/microprofile-3-3-open-liberty-20004.html#gra
* https://openliberty.io/docs/ref/general/#metrics-catalog.html
* https://grafana.com/grafana/dashboards/4701
* https://phauer.com/2017/dont-use-in-memory-databases-tests-h2/
* https://github.com/quarkusio/quarkus/tree/master/integration-tests
* https://hub.docker.com/r/postman/newman
* https://github.com/postmanlabs/newman
* https://learning.postman.com/docs/postman/launching-postman/introduction/
* https://jenkins-x.io/docs/guides/using-jx/pipelines/envvars/
* https://github.com/quarkusio/quarkus/tree/master/integration-tests/flyway/
* https://quarkus.io/guides/flyway
* https://rhuanrocha.net/2019/03/17/how-to-microprofile-opentracing-with-jaeger/
* https://medium.com/jaegertracing/microprofile-tracing-in-supersonic-subatomic-quarkus-43020f89a753
* https://github.com/opentracing-contrib/java-jdbc
* https://quarkus.io/guides/opentracing
* https://cloud.google.com/sql/docs/mysql/connect-kubernetes-engine?hl=en_US