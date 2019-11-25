title: Kubernetes Service - Google GKE (Terraform)
description: Kubernetes Public Cloud Service Google GKE Via Terraform

# GKE Terraform

## Resources

* [Terraform Google Cloud Container Cluster (GKE) Resource](https://www.terraform.io/docs/providers/google/r/container_cluster.html)
* [Un-official GKE Terraform Module](https://github.com/terraform-google-modules/terraform-google-kubernetes-engine)
* [Jetstack GKE Terraform Module](https://blog.jetstack.io/blog/terraform-gke-module/)

## Pre-Requisites

## Terraform Configuration

The idea behind the Terraform configuration is as follows:

* Use *Configuration-as-Code* to create the GKE Cluster
* Have separate Node Pools for workload isolation / specialization
* Each Node Pool has a Cluster Autoscaler to make the cluster size dynamic

### Variables

```Terraform
variable "project" { }

variable "name" {
  description = "The name of the cluster (required)"
  default     = "my-awesome-jx-cluster"
}

variable "description" {
  description = "The description of the cluster"
  default     = "Jenkins X Environment for ..."
}

variable "location" {
  description = "The location to host the cluster"
  default     = "europe-west4"
}

variable "cluster_master_version" {
  description = "The minimum kubernetes version for the master nodes"
  default     = "1.14.7-gke.10"
}
```

### Main

```Terraform
terraform {
  required_version = "~> 0.12"
}

# https://www.terraform.io/docs/providers/google/index.html
provider "google" {
  version   = "~> 2.18.1"
  project   = "${var.project}"
  region    = "europe-west4"
  zone      = "europe-west4-b"
}
```

### Cluster

```Terraform
resource "google_container_cluster" "primary" {
  name        = "${var.name}"
  location    = "${var.location}"

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool  = true
  initial_node_count        = 1
  min_master_version        = "${var.cluster_master_version}"
  resource_labels           = {
    environment = "development"
    created-by  = "terraform"
    owner       = "joostvdg"
  }

  # Configuration options for the NetworkPolicy feature.
  network_policy {
    # Whether network policy is enabled on the cluster. Defaults to false.
    # In GKE this also enables the ip masquerade agent
    # https://cloud.google.com/kubernetes-engine/docs/how-to/ip-masquerade-agent
    enabled = true

    # The selected network policy provider. Defaults to PROVIDER_UNSPECIFIED.
    provider = "CALICO"
  }
}
```

### Node Pools

```Terraform
resource "google_container_node_pool" "nodepool1" {
  name       = "pool1"
  location   =  "${var.location}"
  cluster    =  "${google_container_cluster.primary.name}"
  node_count = 1

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 4
  }

  node_config {
    machine_type = "n1-standard-2"
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "nodepool2" {
  name       = "pool2"
  location   = "europe-west4"
  cluster    = "${google_container_cluster.primary.name}"
  node_count = 1

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }

  node_config {
    machine_type = "n2-standard-2"
    oauth_scopes = [
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/ndev.clouddns.readwrite",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}
```