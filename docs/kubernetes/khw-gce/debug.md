title: Kubernetes The Hard Way (KHW) - Google Cloud 
description: Kubernetes The Hard Way - How To Debug (11/11)
hero: How To Debug (11/11)

# Debug

## Kubernetes components not healthy

### Check for healthy status

On a control plane node, check `etcd`.

```bash
sudo ETCDCTL_API=3 etcdctl member list \
    --endpoints=https://127.0.0.1:2379 \
    --cacert=/etc/etcd/ca.pem \
    --cert=/etc/etcd/kubernetes.pem \
    --key=/etc/etcd/kubernetes-key.pem
```

```bash
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:2379
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:2379
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:2379
```

On a control plan node, check control plane components.

```bash
kubectl get componentstatuses --kubeconfig admin.kubeconfig
```

Should look like this:

```bash
NAME                 STATUS    MESSAGE              ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-2               Healthy   {"health": "true"}
etcd-0               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}
```

On a control plane node, check API server status (via nginx reverse proxy).

```bash
curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz
```

```bash
HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Mon, 14 May 2018 13:45:39 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive

ok
```

On an external system, you can check if the API server is working and reachable via routing.

```bash
curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
```

Assuming that GCE is used.

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')  
```

### Check for errors

```bash
journalctl
```

Or for specific components.

```bash
journalctl -u kube-scheduler
```

## Weave-Net pods Blocked

Sometimes when installing weave-net as the CNI plugin, the pods are blocked.

```bash
NAME              READY     STATUS    RESTARTS   AGE
weave-net-fwvsr   0/2       Blocked   0          3m
weave-net-v9z9n   0/2       Blocked   0          3m
weave-net-zfghq   0/2       Blocked   0          3m
```

Usually this means something went wrong with the CNI configuration.
Ideally, Weave-Net will generate this when installed, but sometimes this doesn't happen.

This is easily found when checking the `journalctl` on the worker nodes (`journalctl -u kubelet`).

There are three things to be done before installing weave-net again.

### Ensure ip4 forwarding is enabled

```bash
sysctl net.ipv4.ip_forward=1
sysctl -p /etc/sysctl.conf
```

See [Kubernetes Docs for GCE routing](https://kubernetes.io/docs/concepts/cluster-administration/networking/#google-compute-engine-gce) 
or [Michael Champagne](https://blog.csnet.me/k8s-thw/part7/)'s blog on KHW.


### Ensure all weave-net resources are gone

I've noticed that when this problem occurs, deleting the weave-net resources with `kubectl delete -f <weaveNet resource>` leaves the pods.
The pods are terminated (they never started) but are not removed.

To remove them, use the line below, as explained [on stackoverflow](https://stackoverflow.com/questions/35453792/pods-stuck-at-terminating-status).

```bash
kubectl delete pod NAME --grace-period=0 --force
```

### Restart Kubelet

I'm not sure if this is 100% required, but I've had better luck with restarting the kubelet before reinstalling weave-net.

So, login to each worker node, `gcloud compute ssh worker-?` and issue the following commands.

```bash
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

## DNS on GCE not working

It seemed something has changed in GCE after Kelsey Hightower's [Kubernetes The Hardway](https://github.com/kelseyhightower/kubernetes-the-hard-way/) was written/updated.

This means that if you follow through the documentation, you will run into this:

```bash
kubectl exec -ti $POD_NAME -- nslookup kubernetes
;; connection timed out; no servers could be reached

command terminated with exit code 1
```

The cure seems to be to add additional `resolve.conf` file configuration to the kubelet's systemd service definition.

```ini hl_lines="13"
cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \
  --config=/var/lib/kubelet/kubelet-config.yaml \
  --container-runtime=remote \
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \
  --resolv-conf=/run/systemd/resolve/resolv.conf \
  --image-pull-progress-deadline=2m \
  --kubeconfig=/var/lib/kubelet/kubeconfig \
  --network-plugin=cni \
  --register-node=true \
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
```

In addition, one should also use at least busybox 1.28 to do the dns check.

For more information, [read this issue](https://github.com/kelseyhightower/kubernetes-the-hard-way/issues/356).