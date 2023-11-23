---
tags:
  - TAP
  - Tanzu
  - Backstage
  - Developer Portal
---

title: TAP GUI - GitLab Integrations
description: Tanzu Application Platform GUI - GitLab Integrations

# TAP GUI - GitLab Integration

TAP GUI is the central component of TAP where people can interact with TAP.

This also makes it a good place to integrate with other tools that are part of the daily software development cycles.

In this guide we look at how you can integrate [GitLab](https://about.gitlab.com) with TAP GUI[^1].

Possible integrations with GitLab:

1. Authentication
1. Trust Catalog Items Source
1. Catalog Items

## Authentication

TAP GUI is based on [Backstage](https://backstage.io)[^2].
For authentication, TAP GUI relies on the plugins that Backstage supports.

As such, the [TAP GUI documentation](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-auth.html)[^3] offers nothing but a reference to the [Backstage auth docs](https://backstage.io/docs/auth/))[^4].

One of the plugins that is installed by default, is the [GitLab Auth provider](https://backstage.io/docs/auth/gitlab/provider). Through it, we can defer authentication to TAP GUI to GitLab[^5].

### Steps To Take

The steps to take, to configure GitLab as the auth provider for TAP GUI are as follows:

1. Create an OAuth App on GitLab, as [described in the Backstage docs](https://backstage.io/docs/auth/gitlab/provider)[^5]
1. Add the Provider configuration to the View cluster's Sensitive values

### Configuration Example

```yaml title="view-profile-sensitive-values-snippet.yaml"
tap_install:
  sensitive_values:
    tap_gui:
      service_type: ClusterIP
      app_config:
        auth:
          environment: development
          providers:
            gitlab:
              development:
                clientId: 9d0ad...........50038
                clientSecret: c9dd6............4e0dee
                audience: https://gitlab.services.mydomain.com/
```

Once the updated configuration is applied, you can now log in via GitLab.

## Trust Catalog Items Source

One of the core features of Backstage is the [Sofware Catalog](https://backstage.io/docs/features/software-catalog/)[^6].

> The Backstage Software Catalog is a centralized system that keeps track of ownership and metadata for all the software in your ecosystem (services, websites, libraries, data pipelines, etc). The catalog is built around the concept of metadata YAML files stored together with the code, which are then harvested and visualized in Backstage. [^6]

To ingest Software Catalog items, Backstage (or TAP GUI) needs to trust the source.

Backstage trusts public sites such as GitHub.com by default.
When you self-host GitLab, we need to add the [GitLab integration](https://backstage.io/docs/integrations/gitlab/locations)[^7].

To ensure everything works well, we need the GitLab URL and a [Personal Access Token](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html) (PAT)[^8].

I encountered that only specifying my Host and PAT where not enough, so this is the GitLab integration snippet I've used.

```yaml
tap_install:
  sensitive_values:
    tap_gui:
      app_config:
        integrations:
          gitlab:
            - host: gitlab.services.mydomain.com
              token: glpat-dVnf.....UhvC
              apiBaseUrl: https://gitlab.services.mydomain.com/api/v4
              baseUrl: https://gitlab.services.mydomain.com
```

## Catalog Items

Backstage supports three ways of ingesting Catalog Items:

1. Upload a YAML file via the GUI
1. Add a static item to the TAP GUI configuration
1. Add a Discovery to the TAP GUI configuration

The first is straight forward, you go the the TAP GUI, click Register Entity and paste the URL pointing to a Catalog item.

For the second and third options we update the TAP install values.

You can read more [about performing Catalog operations](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-catalog-catalog-operations.html) from the Tanzu docs[^9].

### Static Catalog Entry

Adding static entries is straightforward.

The property `catalog.locations` takes an array of `location`, which has a `type` and `target` property.
See an example below:

```yaml
tap_install:
  sensitive_values:
    tap_gui:
      app_config:
        catalog:
          locations:
            - type: url
              target: https://gitlab.services.my-domain.com/joostvdg/tap-catalog/~/blob/main/catalog/catalog-info.yaml
            - type: url
              target: https://gitlab.services.my-domain.com/joostvdg/tap-hello-world/~/blob/main/catalog/catalog-info.yaml
```

### Automatic Discovery

The [Discovery](https://backstage.io/docs/integrations/gitlab/discovery) feature lets Backstage scan all repositories in your GitLab instance (to which the PAT has access) to discover catalog items[^10].

!!! Warning
    This plugin in not installed by default (in Backstage):

    > As this provider is not one of the default providers, you will first need to install the gitlab catalog plugin:

    And I haven't tried if TAP GUI does, so you might have to tweak your Backstage.

    This is supported starting TAP 1.7[^11].

## References

[^1]: [GitLab - DevSecOps Platform](https://about.gitlab.com)
[^2]: [Backstage](https://backstage.io)
[^3]: [TAP GUI - Authentication](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-auth.html)
[^4]: [Backstage docs - Authentication](https://backstage.io/docs/auth/)
[^5]: [Backstage docs - GitLab auth provider](https://backstage.io/docs/auth/gitlab/provider)
[^6]: [Backstage docs - Software Catalog](https://backstage.io/docs/features/software-catalog/)
[^7]: [Backstage docs - GitLab Integration](https://backstage.io/docs/integrations/gitlab/locations)
[^8]: [GitLab docs - Create a Personal Access Token](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html)
[^9]: [TAP GUI - Catalog Operations](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.5/tap/tap-gui-catalog-catalog-operations.html)
[^10]: [Backstage docs - GitLab Discovery](https://backstage.io/docs/integrations/gitlab/discovery)
[^11]: [TAP 1.7 - Tanzu Developer Portal Configurator](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-about.html)
