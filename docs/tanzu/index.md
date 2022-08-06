title: VMware Tanzu
description: What is VMware Tanzu

# What Is VMware Tanzu

VMware is known, amongst other things, as something related to Virtual Machines.

And while VM technology is still essential and helps manage data centers around the globe, it is not at the forefront of software development innovation.

In recent years the industry shifted to (more) public cloud and container orchestration as the de facto standard "operating system."

In this light, VMware invests a lot in cloud technologies that can work in the public cloud, VMware-managed data centers, and any Kubernetes distribution.

These technologies are the VMware **Tanzu**[^1] brand. This also means that [VMware Tanzu](https://tanzu.vmware.com/) is not a single thing but a range of products and (OSS) technologies.

## Tanzu Products

The Tanzu family is a rich set of products ranging from licensed self-hosted applications, and cloud-based subscription services, to collections of VMware products[^2] with OpenSource Software.

Below is a limited list to give you an idea. For a complete overview, visit the VMware [Tanzu products](https://tanzu.vmware.com/products).


| Name                                    | Type             | Abbreviation | Description                                                                                                                                                                     |
|-----------------------------------------|------------------|--------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Tanzu Application Platform              | Suite            | TAP          | Suite tools (incl. OSS) for building, testing, and deploying applications in Kubernetes (CI/CD, GitOps, DevSecOps)                                                              |
| Tanzu for Kubernetes Operations         | Suite            | TKO          | Suite of licensed (VMware) products for managing Kubernetes clusters (Tanzu Mission Control, Tanzu Observability, and Tanzu Service Mesh)                             |
| Tanzu Kubernetes Grid - Stand alone     | Self-host        | TKGm         | Kubernetes distribution that runs "anywhere." TKG Manages the underlying infra with Cluster API.                                                                              |
| Tanzu Kubernetes Grid - vCenter embedded | Self-host        | TKGs         | Kubernetes distribution managed directly by vCenter. Also known as `vSphere with Tanzu` (and under the code name `Project Pacific`)                                             |
| Tanzu Mission Control                   | SaaS             | TMC          | Online management platform for managing a fleet of Kubernetes clusters, but not limited to TKG. (package repositories, policies, and namespace). |
| Tanzu Service Mesh                      | SaaS + Self-host | TSM          | Built on top of Istio Service Mesh. Adds a management plane that lets you combine multiple clusters into a single Service Mesh.                                                 |
| Tanzu Observability                     | SaaS             | TO           | Originally known as Wavefront. Provides a suite of tools to monitor and trace applications and infrastructure (Kubernetes, vCenter, VMs, and so on)                              |
| Tanzu Build Service                     | Self-host        | TBS          | Automated container creation, management, and governance. Build on top of Cloud Native Build packs.                                                                             |

## References

[^1]: [VMware Tanzu landing page](https://tanzu.vmware.com/)
[^2]: [VMware Tanzu products overview page](https://tanzu.vmware.com/products)
