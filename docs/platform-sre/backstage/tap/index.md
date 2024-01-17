---
tags:
  - IDP
  - TAP
  - Platform Engineering
  - SRE
  - Tanzu
  - Backstage
---

title: Backstage and Tanzu
description: Backstage & Tanzu Application Platform

# Backstage and Tanzu

Tanzu Application Platform includes Backstage as its GUI, as a central component for building a Internal Developer Portal.

With that reasoning, TAP's version of Backstage is named Tanzu Developer Portal.

## Add Additional Backstage Plugins to TDP

Tanzu Developer Portal, or TDP, contains Backstage's default plugins and a few selected plugins that make sense for its use in TAP.

The Backstage community has a lot more [plugins](https://backstage.io/plugins/) available.

Many plugins require you to change the Backstage sources yourself before you they work as expected.

This is complicated with the TDP, as you do not have access to this version of Backstage's source.

To make it possible to add either your own or any of the existing Backstage plugins, the TAP team created additional APIs inside Backstage.

This allows us to "wrap" a vanilla Backstage plugin and include it into the TDP via the [Tanzu Developer Portal Configurator](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-building.html).

Which comes down to building an updated TDP container image with the wrapper plugins included via a configuration file.

This has been explored by community superstar [VRabbi](https://vrabbi.cloud/post/tanzu-developer-portal-configurator-deep-dive/), who has created a [public repository](https://github.com/vrabbi-tap/tdp-plugin-wrappers) with many Backstage community plugins already wrapped and ready to use.

I wanted to explore this myself, so I folled the following (high over) steps:

1. Create a Backstage Frontend and a Backend plugin
    1. See [Create a Backend Plugin](/platform-sre/backstage/plugin/backend/)
    1. See [Create a Frontend Plugin](/platform-sre/backstage/plugin/frontend/)
1. [Wrap Backstage plugins for use in the TDP](/platform-sre/backstage/tap/wrap-plugins/)
1. [Add Wrapped Plugins to the TDP](/platform-sre/backstage/tap/add-wrap-plugin/)

!!! Important
    While writing this, the Tanzu team added a similar guide to the official TAP documentation.

    You might want to follow the [Create a Tanzu Developer Portal plug-in](https://docs.vmware.com/en/VMware-Tanzu-Application-Platform/1.7/tap/tap-gui-configurator-create-plug-in-wrapper.html) guide instead.

