# Remote Access

```bash
KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')
echo "KUBERNETES_PUBLIC_ADDRESS=${KUBERNETES_PUBLIC_ADDRESS}"

kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

kubectl config use-context kubernetes-the-hard-way
```

## Confirm

```bash
kubectl get nodes -o wide
```