---
tags:
  - TKG
  - Vsphere
  - Harbor
  - TANZU
---

title: Custom CA
description: Set up a custom Certificate Authority with CFSSL

## Setup Certificate Authority

In Addition, we need to have the Certificate Authority.

If you don't have one, or want to learn how to create one yourself, follow along.
We use the tools from [CloudFlare](https://github.com/cloudflare/cfssl), **cfssl**, for this.

The documentation is pretty heavy and hard to follow at times, so we take inspiration from this [Medium blog post](https://rob-blackbourn.medium.com/how-to-use-cfssl-to-create-self-signed-certificates-d55f76ba5781) to stick to the basics.

The steps are as follows:

* create cfssl profile
* create CA config
* generate CA certificate and key
* create server certificate JSON config
* generate derived certificate and key

The step _generate derived certificate and key_ is done later, when we generate the Harbor certificate (our self-hosted registry of choice).

## CFSSL Profile

Save the following as `cfssl.json`:

```json title="cfssl.json"
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "intermediate_ca": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment",
            "cert sign",
            "crl sign",
            "server auth",
            "client auth"
        ],
        "expiry": "8760h",
        "ca_constraint": {
            "is_ca": true,
            "max_path_len": 0,
            "max_path_len_zero": true
        }
      },
      "peer": {
        "usages": [
            "signing",
            "digital signature",
            "key encipherment",
            "client auth",
            "server auth"
        ],
        "expiry": "8760h"
      },
      "server": {
        "usages": [
          "signing",
          "digital signing",
          "key encipherment",
          "server auth"
        ],
        "expiry": "8760h"
      },
      "client": {
        "usages": [
          "signing",
          "digital signature",
          "key encipherment",
          "client auth"
        ],
        "expiry": "8760h"
      }
    }
  }
}
```

## Create CA

Create a JSON config file for your CA: `ca.json`.

This file contains the values of your CA.

```json title="ca.json"
{
  "CN": "Kearos Tanzu Root CA",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "NL",
      "L": "Utrecht",
      "O": "Kearos",
      "OU": "Kearos Tanzu",
      "ST": "Utrecht"
    }
  ]
}
```

!!! info "Field names meaning"

    If you are wondering what those names, such as `C`, `L`, mean, here's a table:

    | Abbreviation | Description          |
    | :----------- | :--------------------|
    | **CN**       |  CommonName          |
    | **OU**       |  OrganizationalUnit  |
    | **O**        |  Organization        |        
    | **L**        |  Locality            |
    | **S**        |  StateOrProvinceName |   
    | **C**        |  CountryName or CountryCode         |       

And then generate the `ca.pem` and `ca-key.pem` files:

```sh
cfssl gencert -initca ca.json | cfssljson -bare ca
```

## Create Server Certificate Config file

This is very similar to the `ca.json` file, you can copy most of it.

You can include the `CN` and `hostnames` fields, but if you want to generate more than one certificate (for multiple hosts), it is better to leave them blank.
In the command with which you generate the certificate, you can then supply those with environment variables to make them more dynamic, and make it easier to update them later.

Create the following file: `base-service-cert.json`

```json title="base-service-cert.json"
{
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "names": [
        {
            "C": "NL",
            "L": "Utrecht",
            "O": "Kearos Tanzu",
            "OU": "Kearos Tanzu Hosts",
            "ST": "Utrecht"
        }
    ]
}
```
