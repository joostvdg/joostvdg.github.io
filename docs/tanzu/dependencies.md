---
tags:
  - ldap
  - openldap
  - dependencies
  - TAP
  - TANZU
---

title: Dependencies For TAP/TKG
description: Packages that are dependencies for TAP or TKG packages, such as LDAP

## LDAP Dependency

There are many ways to run an LDAP server.

I generally use OpenLDAP, via the following:

* [osixia/openldap](https://hub.docker.com/r/osixia/openldap) container image, well constructed and decently maintained
* [jp-gouin/helm-openldap](https://github.com/jp-gouin/helm-openldap) helm chart, uses the above image and has an HA version

### Image Relocation

In case you need to relocate the image to another registry, you can use a [Docker client](https://www.docker.com/products/docker-desktop/) or [imgpkg](https://carvel.dev/imgpkg)

```sh
docker pull osixia/openldap:1.5.0 --platform linux/amd64
docker tag osixia/openldap:1.5.0 harbor.10.220.2.199.sslip.io/tap/openldap:1.5.0
docker push harbor.10.220.2.199.sslip.io/tap/openldap:1.5.0
```

```sh
imgpkg copy \
  -i osixia/openldap:1.5.0 \
  --to-repo=harbor.10.220.2.199.sslip.io/tap/openldap
```

### Helm Install

```sh
helm repo add helm-openldap https://jp-gouin.github.io/helm-openldap/
```

```sh
helm repo update
```

```sh
helm upgrade --install ldap helm-openldap/openldap \
  --namespace ldap --create-namespace \
  --values ldap-values.yaml\
  --version 2.0.4
```

#### Helm Values File

!!! Hint
    Dont't forget to replace the `image.repository` value if you relocated the image!

```yaml title="ldap-values.yaml"
image:
  repository: osixia/openldap
  tag: 1.5.0

phpldapadmin:
  enabled: false

ltb-passwd:
  enabled: false

customLdifFiles:

  main.ldif: |
  ...

adminPassword: C5z6DUTNSMDoiWCHI2GIuSPIzCJt5Zo0
configPassword: C5z6DUTNSMDoiWCHI2GIuSPIzCJt5Zo0
```

!!! Warning
    A full example of the helm values is found [github.com/joostvdg/tanzu-example](https://github.com/joostvdg/tanzu-example/tree/main/dependencies/ldap).

#### Main LDIF

The following file is not recommend for production, but should be fine for testing and PoC environments.

??? Example "main.ldif"

    This is an example contents of the `customLdifFiles.main.ldif` property of the values file above.

    ```ini title="main.ldif"
    # define people and groups as category
    dn: ou=People, dc=example,dc=org
    objectclass: top
    objectclass: organizationalunit
    ou: People

    dn: ou=Groups, dc=example,dc=org
    objectclass: top
    objectclass: organizationalunit
    ou: Groups

    # add Administrator group and add me and admin as members
    dn: cn=BlueAdmins, ou=Groups,dc=example,dc=org
    objectclass: top
    objectclass: groupOfNames
    cn: BlueAdmins
    ou: Groups
    member: uid=blueadmin,ou=People, dc=example,dc=org

    dn: cn=Blue, ou=Groups,dc=example,dc=org
    objectclass: top
    objectclass: groupOfNames
    cn: Blue
    ou: Groups
    member: uid=blueadmin,ou=People, dc=example,dc=org
    member: uid=bluedev,ou=People, dc=example,dc=org

    dn: uid=blueadmin, ou=People, dc=example,dc=org
    uid: blueadmin
    cn: blueadmin
    sn: Admin
    givenname: Blue
    objectclass: top
    objectclass: person
    objectclass: organizationalPerson
    objectclass: inetOrgPerson
    ou: People
    mail: blueadmin@example.org
    userpassword: C5z6DUTNSMDoiWCHI2GIuSPIzCJt5Zo0

    dn: uid=bluedev, ou=People, dc=example,dc=org
    uid: bluedev
    cn: bluedev
    sn: Dev
    givenname: Blue
    objectclass: top
    objectclass: person
    objectclass: organizationalPerson
    objectclass: inetOrgPerson
    ou: People
    mail: bluedev@example.org
    userpassword: C5z6DUTNSMDoiWCHI2GIuSPIzCJt5Zo0
    ```

### Verify LDAP with ldapsearch

In case you're not sure about the credentials used, you can retrieve them from the namespace you installed LDAP in.

In this case, I've installed LDAP in the `ldap` namespace, and named the helm release `ldap`, which then gets `-openldap` concatenated to it.

```sh
LDAP_ADMIN_PASS=$(kubectl get secret --namespace ldap ldap-openldap -o jsonpath="{.data.LDAP_ADMIN_PASSWORD}" | base64 --decode)
LDAP_CONFIG_PASS=$(kubectl get secret --namespace ldap ldap-openldap -o jsonpath="{.data.LDAP_CONFIG_PASSWORD}" | base64 --decode)
```

You can open a shell to any of the Pods, there are three by default.

```sh
kubectl get pod -n ldap
```

```sh
NAME              READY   STATUS    RESTARTS   AGE
ldap-openldap-0   1/1     Running   0          19h
ldap-openldap-1   1/1     Running   0          19h
ldap-openldap-2   1/1     Running   0          19h
```

Either execute a single command at a time:

```sh
kubectl exec -n ldap --stdin=true --tty=true ldap-openldap-0 \
    -- ldapsearch -x -H ldap://ldap-openldap.ldap.svc.cluster.local:389 \
    -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" -w $LDAP_ADMIN_PASS
```

Or you can enter the shell session, and run multiple commands.

```sh
kubectl exec -n ldap --stdin=true --tty=true ldap-openldap-0 -- bash
```

Set the password to the `LDAP_ADMIN_PASSWORD` that you collected via the shell commands above.

```sh
LDAP_ADMIN_PASS=
```

#### LDAP Searches

!!! Note
    This assumes your LDAP is installed in the namespace `ldap` with Helm release name `ldap`.
    The **service** fronting the LDAP pods is then accessible at this dns: `ldap-openldap.ldap.svc.cluster.local`.

    If you changed these values, change the commands appropriately.

Finds all entries.

```sh
ldapsearch -x \
    -H ldap://ldap-openldap.ldap.svc.cluster.local:389 \
    -b dc=example,dc=org \
    -D "cn=admin,dc=example,dc=org" \
    -w $LDAP_ADMIN_PASS
```

Finds users.

```sh
ldapsearch -x \
    -H ldap://ldap-openldap.ldap.svc.cluster.local:389 \
    -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" \
    -s sub "(objectclass=inetOrgPerson)"\
    -w $LDAP_ADMIN_PASS
```

Finds groups.

```sh
ldapsearch -x \
    -H ldap://ldap-openldap.ldap.svc.cluster.local:389\
    -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" \
    -s sub "(&(objectClass=groupOfNames)(ou=Groups))"\
    -w $LDAP_ADMIN_PASS
```

Finds groups this user belongs to.

```sh
ldapsearch -x \
    -H ldap://ldap-openldap.ldap.svc.cluster.local:389 \
    -b dc=example,dc=org -D "cn=admin,dc=example,dc=org" \
    -s sub "(& (objectclass=groupOfNames)(member=uid=bluedev, ou=People, dc=example,dc=org) )" \
    -w $LDAP_ADMIN_PASS
```
