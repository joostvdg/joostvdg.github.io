title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - VM's (2/11)
hero: VM's with Terraform (2/11)

# Compute resources

## Create network

### VPC with Firewall rules

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

resource "google_compute_firewall" "khw-allow-dns" {
  name    = "kubernetes-the-hard-way-allow-dns"
  network = "${google_compute_network.khw.name}"

  source_ranges = ["0.0.0.0"]

  allow {
    protocol = "tcp"
    ports    = ["53", "443"]
  }

  allow {
    protocol = "udp"
    ports    = ["53"]
  }
}

resource "google_compute_firewall" "khw-allow-health-check" {
  name    = "kubernetes-the-hard-way-allow-health-check"
  network = "${google_compute_network.khw.name}"

  allow {
    protocol = "tcp"
  }

  source_ranges = ["209.85.152.0/22", "209.85.204.0/22", "35.191.0.0/16"]
}
```

### Confirm network

```bash
gcloud compute firewall-rules list --filter="network:kubernetes-the-hard-way"
```

Should look like:

```bash
NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW                 DENY
kubernetes-the-hard-way-allow-external  kubernetes-the-hard-way  INGRESS    1000      icmp,tcp:22,tcp:6443
kubernetes-the-hard-way-allow-internal  kubernetes-the-hard-way  INGRESS    1000      icmp,udp,tcp
```

## Public IP

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

## VM Definitions with Terraform modules

We're going to need to create 6 VM's. 3 Controller nodes and 3 worker nodes.

Within each of the two categories, all the three VM's will be the same.
So it would be a waste to define them more than once.
This can be achieved via Terraform's [Module system](https://www.terraform.io/docs/modules/usage.html)(read more [here](https://blog.gruntwork.io/how-to-create-reusable-infrastructure-with-terraform-modules-25526d65f73d).

### Define a module

For the sake of naming convention, we'll put all of our `modules` in a *modules* subfolder.
We'll start with the controller module, but you can do the same for the worker.

```bash
mkdir -p modules/controller
```

```bash hl_lines="4"
ls -lath
drwxr-xr-x  27 joostvdg  staff   864B Aug 26 12:50 .
drwxr-xr-x  20 joostvdg  staff   640B Aug 22 14:47 ..
drwxr-xr-x   4 joostvdg  staff   128B Aug  7 22:43 modules
```

```bash
ls -lath modules
drwxr-xr-x  27 joostvdg  staff   864B Aug 26 12:50 ..
drwxr-xr-x   4 joostvdg  staff   128B Aug  7 22:43 .
drwxr-xr-x   4 joostvdg  staff   128B Aug  7 22:03 controller
```

Inside `modules/controller` we create two files, `main.tf` and `variables.tf`.
We have to create an additional variables file, as the module cannot use the main folder's variables.

Then, in our main folder we'll create a tf file for using these modules, called `nodes.tf`.
As stated above, we pass along any variable from our main `variables.tf` to the module.

```terraform
module "controller" {
  source       = "modules/controller"
  machine_type = "${var.machine_type_controllers}"
  num          = "${var.num_controllers}"
  zone         = "${var.region_default_zone}"
  subnet       = "${var.subnet_name}"
}

module "worker" {
  source       = "modules/worker"
  machine_type = "${var.machine_type_workers}"
  num          = "${var.num_workers}"
  zone         = "${var.region_default_zone}"
  network      = "${google_compute_network.khw.name}"
  subnet       = "${var.subnet_name}"
}
```

### Controller config

```terraform
data "google_compute_image" "khw-ubuntu" {
  family  = "ubuntu-1804-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "khw-controller" {
  count          = "${var.num}"
  name           = "controller-${count.index}"
  machine_type   = "${var.machine_type}"
  zone           = "${var.zone}"
  can_ip_forward = "true"

  tags = ["kubernetes-the-hard-way", "controller"]

  boot_disk {
    initialize_params {
      image = "${data.google_compute_image.khw-ubuntu.self_link}"
      size  = 200                                                 // in GB
    }
  }

  network_interface {
    subnetwork = "${var.subnet}"
    address    = "10.240.0.1${count.index}"

    access_config {
      // Ephemeral External IP
    }
  }

  # compute-rw,storage-ro,service-management,service-control,logging-write,monitoring
  service_account {
    scopes = ["compute-rw",
      "storage-ro",
      "service-management",
      "service-control",
      "logging-write",
      "monitoring",
    ]
  }
}
```

#### Variables

```terraform
variable "num" {
  description = "The number of controller VMs"
}

variable "machine_type" {
  description = "The type of VM for controllers"
}

variable "zone" {
  description = "The zone to create the controllers in"
}

variable "subnet" {
  description = "The subnet to create the nic in"
}

```

### Worker config

Extra config for the worker are the routes, to aid the pods going out of the node.

```terraform
data "google_compute_image" "khw-ubuntu" {
  family  = "ubuntu-1804-lts"
  project = "ubuntu-os-cloud"
}

resource "google_compute_instance" "khw-worker" {
  count          = "${var.num}"
  name           = "worker-${count.index}"
  machine_type   = "${var.machine_type}"
  zone           = "${var.zone}"
  can_ip_forward = "true"

  tags = ["kubernetes-the-hard-way", "worker"]

  metadata {
    pod-cidr = "10.200.${count.index}.0/24"
  }

  boot_disk {
    initialize_params {
      image = "${data.google_compute_image.khw-ubuntu.self_link}"
      size  = 200                                                 // in GB
    }
  }

  network_interface {
    subnetwork = "${var.subnet}"
    address    = "10.240.0.2${count.index}"

    access_config {
      // Ephemeral External IP
    }
  }

  service_account {
    scopes = ["compute-rw",
      "storage-ro",
      "service-management",
      "service-control",
      "logging-write",
      "monitoring",
    ]
  }
}

resource "google_compute_route" "khw-worker-route" {
  count       = "${var.num}"
  name        = "kubernetes-route-10-200-${count.index}-0-24"
  network     = "${var.network}"
  next_hop_ip = "10.240.0.2${count.index}"
  dest_range  = "10.200.${count.index}.0/24"
}
```

#### Variables

```terraform
variable "num" {
  description = "The number of controller VMs"
}

variable "machine_type" {
  description = "The type of VM for controllers"
}

variable "zone" {
  description = "The zone to create the controllers in"
}

variable "network" {
  description = "The network to use for routes"
}

variable "subnet" {
  description = "The subnet to create the nic in"
}
```

### Health check

Because we will have three controllers, we have to make sure that GKE forwards Kubernetes API requests to each of them via our public IP address.

We do this via a http health check, wich involves a forwarding rule and a target pool.
Target pool being the group of controller VM's for which the forwarding rule is active.

```terraform
resource "google_compute_target_pool" "khw-hc-target-pool" {
  name = "instance-pool"

  # TODO: fixed set for now, maybe we can make this dynamic some day
  instances = [
    "${var.region_default_zone}/controller-0",
    "${var.region_default_zone}/controller-1",
    "${var.region_default_zone}/controller-2",
  ]

  health_checks = [
    "${google_compute_http_health_check.khw-health-check.name}",
  ]
}

resource "google_compute_http_health_check" "khw-health-check" {
  name         = "kubernetes"
  request_path = "/healthz"
  description  = "The health check for Kubernetes API server"
  host         = "${var.kubernetes-cluster-dns}"
}

resource "google_compute_forwarding_rule" "khw-hc-forward" {
  name       = "kubernetes-forwarding-rule"
  target     = "${google_compute_target_pool.khw-hc-target-pool.self_link}"
  region     = "${var.region}"
  port_range = "6443"
  ip_address = "${google_compute_address.khw-lb-public-ip.self_link}"
}
```

## Apply Terraform state

In the end, our configuration should consist out of several `.tf` files and look something like this.

```bash
ls -lath
drwxr-xr-x  27 joostvdg  staff   864B Aug 26 12:50 .
drwxr-xr-x  20 joostvdg  staff   640B Aug 22 14:47 ..
drwxr-xr-x   4 joostvdg  staff   128B Aug  7 22:43 modules
-rw-r--r--   1 joostvdg  staff   1.5K Aug 26 12:50 variables.tf
-rw-r--r--   1 joostvdg  staff   1.3K Aug 17 16:03 firewall.tf
-rw-r--r--   1 joostvdg  staff   4.4K Aug 17 12:06 worker-config.md
-rw-r--r--   1 joostvdg  staff   1.6K Aug 17 09:35 healthcheck.tf
-rw-r--r--   1 joostvdg  staff   517B Aug 16 17:09 nodes.tf
-rw-r--r--   1 joostvdg  staff    92B Aug 16 13:52 publicip.tf
-rw-r--r--   1 joostvdg  staff   365B Aug  7 22:07 vpc.tf
-rw-r--r--   1 joostvdg  staff   189B Aug  7 16:51 base.tf
drwxr-xr-x   5 joostvdg  staff   160B Aug  7 21:52 .terraform
-rw-r--r--   1 joostvdg  staff     0B Aug  7 18:28 terraform.tfstate
```

We're now going to `plan` and then `apply` our Terraform configuration to create the resources in GCE.

```bash
terraform plan
```

```bash
terraform apply
```