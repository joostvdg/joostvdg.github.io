title: Jenkins X - Java Native Image Prod
description: Creating a Java Native Image application and run it as Production with Jenkins X - Introduction - 1/10
hero: Introduction - 1/10

# Introduction

## Stack

* **Google Cloud Platform(GCP)**: while you can do evyrthing required with other providers, I've chosen GCP
* **Kubernetes**: in particular, **GKE**
* **Jenkins X**: CI/CD
* **Helm**: packaging our Kubernetes application
    * managed by Jenkins X (_to a degree_)
* **Google Cloud SQL**(MySQL): our data storage
* **HashiCorp Vault**: secrets storage
* **Quarkus**: A Kubernetes Native Java stack tailored for OpenJDK HotSpot and GraalVM.
    * Spring Data JPA for ORM
    * Spring Web for the REST API
* **Flyway**: to manage our Database schema (introduced in [Previews & Integration Tests](/jenkinsx/java-native-prod/08-preview-int-test/))
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
* Promote the application to Jenkins X's Production environment

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

!!! important

    A little spoiler, but the Native Image build requires at least 6GB of memory but works best with about 8GB.
    This means your Kubernetes worker node that your build runs on, needs have at least about 10-12GB memory.

    If you're in GKE, as the guide assumes, the following machine types work:

    * `e2-highmem-2`
    * `n2-highmem-2`
    * `e2-standard-4`
    * `n2-standard-4`

    Keep in mind, you can use more than one Node Pool. You don't have to run all your nodes on these types, you need at least to be safe. Having autoscaling enabled for this Node Pool is recommended.

## Why Quarkus

Before we start, I'd like to make the case, why I chose to use Quarkus for this.

Wanting to build a Native Image with Java 11 is part of the reason, we'll dive into that next.

Quarkus has seen an tremendous amount of updates since its inception. 
It is a really active framework, which does not require you to forget everything you've learned in other Java frameworks such as Spring and Spring Boot. I like to stay up-to-date with what happens in the Java community, so spending some time with Quarkus was on my todo list.

It comes out of the same part from RedHat that is involved with OpenShift - RedHat's Kubernetes distribution.
This ensures the framework is created with running Java on Kubernetes in mind. 
Jenkins X starts from Kubernetes, so this makes it a natural fit.

Next, the capabilities for making a Native Image and work done to ensure you - the developer - do not have to worry (too much) about how to get from a Spring application to a Native Image is staggering. This makes the Native Image experience pleasant and involve little to no debugging.

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
* https://dbabulletin.com/index.php/2018/03/29/best-practices-using-flyway-for-database-migrations/
