# Worker Installation

## Install base components

### Download

```bash
wget -q --show-progress --https-only --timestamping \
    https://github.com/kubernetes-incubator/cri-tools/releases/download/v1.0.0-beta.0/crictl-v1.0.0-beta.0-linux-amd64.tar.gz \
    https://storage.googleapis.com/kubernetes-the-hard-way/runsc \
    https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
    https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz \
    https://github.com/containerd/containerd/releases/download/v1.1.2/containerd-1.1.2.linux-amd64.tar.gz \
    https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubectl \
    https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kube-proxy \
    https://storage.googleapis.com/kubernetes-release/release/v1.10.2/bin/linux/amd64/kubelet
```

### Prepare landing folders

```bash
sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes \
    /etc/containerd/
```

### Unpack to folders

```bash
chmod +x kubectl kube-proxy kubelet runc.amd64 runsc
    sudo mv runc.amd64 runc
    sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
    sudo tar -xvf crictl-v1.0.0-beta.0-linux-amd64.tar.gz -C /usr/local/bin/
    sudo tar -xvf cni-plugins-amd64-v0.7.1.tgz -C /opt/cni/bin/
    sudo tar -xvf containerd-1.1.2.linux-amd64.tar.gz -C /
```

## List variables

```bash
POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
    http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)

echo HOSTNAME=$HOSTNAME
echo POD_CIDR=$POD_CIDR
```

## Configure ContainerD

### Runtime configuration file

```ini
cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
EOF
```

### SystemD service configuration file

```ini
cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
```

## Configure CNI

!!! warning
    We do not need to configure cni as we will setup Weave and it will do the necessary setup automagically.

## Configure Kubelet

### Move certificates to correct places

```bash
sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
sudo mv ca.pem /var/lib/kubernetes/
```

### Create k8s yaml configuration

```yaml
cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF
```

### SystemD service configuration file

!!! warning
    One thing I see missing from your kubelet configuration is  `--non-masquerade-cidr flag.`
    Kubelet needs to be run with this option for traffic to outside clusterIP range. Refer here - kubenet

        Kubelet should also be run with the `--non-masquerade-cidr=<clusterCidr>` argument to ensure traffic to IPs outside this range will use IP masquerade.

    Not sure, if this is the cause, but looks like this is a requirement and is missing from the Kubelet config.



```ini
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --allow-privileged=true \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Kube-Proxy


### Move kubeconfig

```bash
sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
```

### Create k8s yaml config

```yaml
cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
    kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF
```

### Create SystemD service

```ini
cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
    --config=/var/lib/kube-proxy/kube-proxy-config.yaml \\
    --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

## Configure and start the SystemD services

```bash
sudo systemctl daemon-reload
sudo systemctl enable containerd kubelet kube-proxy
sudo systemctl start containerd kubelet kube-proxy
```

### Validate

!!! note
    Run this from a machine outside the cluster, with access to the admin kubeconfig.

```bash
gcloud compute ssh controller-0 --command "kubectl get nodes --kubeconfig admin.kubeconfig"
```

!!! note
    As we didn't configure networking yet, the nodes should be shown as `NotReady` status.

