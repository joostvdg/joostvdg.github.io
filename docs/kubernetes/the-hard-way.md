# Kubernetes the Hard Way

This assumes OSX and GKE.

## Network

* https://blog.csnet.me/k8s-thw/part1/
* https://github.com/kelseyhightower/kubernetes-the-hard-way


### Kelseys

| Range         | Use           |
|10.240.0.10/24	|LAN (GCE VMS)  |
|10.200.0.0/16 	|k8s Pod network|
|10.32.0.0/24 	|k8s Service network|
|10.32.0.1 	    |k8s API server |
|10.32.0.10 	|k8s dns        |

* API Server: https://127.0.0.1:6443
* service-cluster-ip-range=10.32.0.0/24
* cluster-cidr=10.200.0.0/1


### CSNETs

| Range         | Use           |
|10.32.2.0/24 	|LAN (csnet.me) |
|10.16.0.0/16 	|k8s Pod network|
|10.10.0.0/22 	|k8s Service network|
|10.10.0.1 	    |k8s API server |
|10.10.0.10 	|k8s dns        |

* API Server: https://10.32.2.97:6443
* service-cluster-ip-range=10.10.0.0/22
* cluster-cidr=10.16.0.0/16


## Install tools

```bash
brew install kubernetes-cli
brew install cfssl
brew install kubernetes-helm
brew install stern
brew install terraform
```

### Check versions

```bash
kubectl version -c -o yaml
cfssl version
helm version -c --short
stern --version
terraform version
```

### Terraform remote storage

* create s3 bucket
* configure terraform to use this as remote state storage

```bash
export AWS_ACCESS_KEY_ID="anaccesskey"
export AWS_SECRET_ACCESS_KEY="asecretkey"
export AWS_DEFAULT_REGION="eu-central-1"
```

```terraform
terraform {
  backend "s3" {
    bucket  = "euros-terraform-state"
    key     = "terraform.tfstate"
    region  = "eu-central-1"
    encrypt = "true"
  }
}

```

## Compute resources

### Create network

#### VPC with Firewall rules

```terraform
provider "google" {
  credentials = "${file("${var.credentials_file_path}")}"
  project     = "${var.project_name}"
  region      = "${var.region}"
}

resource "google_compute_network" "khw" {
  name                    = "kubernetes-the-hard-way"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "khw-kubernetes" {
  name          = "kubernetes"
  ip_cidr_range = "10.240.0.0/24"
  region        = "${var.region}"
  network       = "${google_compute_network.khw.self_link}"
}

resource "google_compute_firewall" "khw-allow-internal" {
  name    = "kubernetes-the-hard-way-allow-internal"
  network = "${google_compute_network.khw.name}"

  source_ranges = ["10.240.0.0/24", "10.200.0.0/16"]

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "khw-allow-external" {
  name    = "kubernetes-the-hard-way-allow-external"
  network = "${google_compute_network.khw.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22", "6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}
```

#### Confirm network

```bash
gcloud compute firewall-rules list --filter="network:kubernetes-the-hard-way"
```

Should look like:

```bash
NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW                 DENY
kubernetes-the-hard-way-allow-external  kubernetes-the-hard-way  INGRESS    1000      icmp,tcp:22,tcp:6443
kubernetes-the-hard-way-allow-internal  kubernetes-the-hard-way  INGRESS    1000      icmp,udp,tcp
```

### Public IP

```json
resource "google_compute_address" "khw-lb-public-ip" {
  name = "kubernetes-the-hard-way"
}
```

Confirm:

```bash
gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"
```

Output:

```bash
NAME                     REGION        ADDRESS         STATUS
kubernetes-the-hard-way  europe-west4  35.204.134.219  RESERVED
```