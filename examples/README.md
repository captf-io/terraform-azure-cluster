# Examples

Manifests that use the Azure module images. Both are `clusterctl generate
yaml` templates: `${VARIABLE}` placeholders, with defaults where one makes
sense.

| File | What it creates | Variables |
| --- | --- | --- |
| [`identity.yaml`](identity.yaml) | The credentials Secret (in `captf-system`) and the cluster-scoped `TerraformClusterIdentity` that names it. Admin-applied, once per management cluster | `NAMESPACE`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, `AZURE_IDENTITY_NAME` (`azure`) |
| [`cluster-kubeadm.yaml`](cluster-kubeadm.yaml) | A Cluster with a KubeadmControlPlane of three, a MachineDeployment of two and a MachinePool of two, plus MachineHealthChecks for workers and the control plane | `CLUSTER_NAME`, `KUBERNETES_VERSION`, `AZURE_SUBNET_ID`, `AZURE_SSH_PUBLIC_KEY`, `AZURE_IMAGE_ID`, and optional counts, CIDRs and `AZURE_WORKER_VM_SIZE` |

```sh
export NAMESPACE=team-a AZURE_TENANT_ID=... AZURE_SUBSCRIPTION_ID=... \
  AZURE_CLIENT_ID=... AZURE_CLIENT_SECRET=...
clusterctl generate yaml --from examples/identity.yaml | kubectl apply -f -

export CLUSTER_NAME=demo KUBERNETES_VERSION=v1.34.1
export AZURE_SUBNET_ID=/subscriptions/<id>/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes
export AZURE_SSH_PUBLIC_KEY="$(cat ~/.ssh/id_ed25519.pub)"
export AZURE_IMAGE_ID='/communityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/images/capi-ubun2-2404/versions/{semver}'
clusterctl generate yaml --from examples/cluster-kubeadm.yaml | kubectl apply -n "$NAMESPACE" -f -
```

Notes:

- The Nodes register under their VM names (`nodeRegistration.name:
  '{{ ds.meta_data["local_hostname"] }}'`), which cloud-provider-azure
  needs; install it and a CNI in the workload cluster.
- `{semver}` in `AZURE_IMAGE_ID` is filled by the modules with each
  Machine's version, so a version upgrade picks the matching CAPZ reference
  image. Quote it so the shell keeps the braces.
- The MachineHealthCheck timeouts exceed apply time plus one drift interval
  (30 minutes by default): 2700 seconds for workers, 3600 for the control
  plane (CONVENTIONS.md section 17).
- The manifests pin every image to a release, `v0.1.0-opentofu`: change the
  tag to the release you deploy (`vX.Y.Z-opentofu` or `vX.Y.Z-terraform`),
  or to a digest. The moving tags (`opentofu`, `terraform`,
  `edge-<runtime>`) are for trying things out, never for anything you keep.
