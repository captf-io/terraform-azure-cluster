<h1 align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="72" height="72" alt="CAPTF"></a>
  <br>
  terraform-azure-cluster
</h1>

<p align="center">The CAPTF cluster module for Microsoft Azure</p>

<p align="center">
  <a href="https://github.com/captf-io/terraform-azure-cluster/actions/workflows/ci.yml"><img
    src="https://img.shields.io/github/actions/workflow/status/captf-io/terraform-azure-cluster/ci.yml?branch=main&amp;label=build&amp;labelColor=161B3A&amp;style=flat-square"
    alt="build"></a>
  <a href="https://captf.io/docs/module-author/contract/index.html"><img
    src="https://img.shields.io/static/v1?label=contract&amp;message=v1alpha1&amp;color=A974FF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="contract v1alpha1"></a>
  <a href="https://captf.io/docs/"><img
    src="https://img.shields.io/static/v1?label=docs&amp;message=captf.io&amp;color=5B8CFF&amp;labelColor=161B3A&amp;style=flat-square"
    alt="docs captf.io"></a>
  <a href="https://github.com/captf-io/terraform-azure-cluster/blob/main/LICENSE.md"><img
    src="https://img.shields.io/static/v1?label=license&amp;message=Apache-2.0&amp;color=FFD84D&amp;labelColor=161B3A&amp;style=flat-square"
    alt="license Apache-2.0"></a>
</p>

> [!NOTE]
> **Pre-release.** CAPTF is `v1alpha1`: its API and its
> [module contract](https://captf.io/docs/module-author/contract/index.html)
> may still change between releases.

The CAPTF Azure cluster module is the Terraform/OpenTofu root module behind
`TerraformCluster`. It is the `cluster` role of the CAPTF Azure modules: the
cluster-wide substrate of a Kubernetes cluster on Azure virtual machines. It
implements the
[`v1alpha1` cluster role](https://captf.io/docs/module-author/contract/v1alpha1/cluster.html).
The images are built by
[module-images](https://github.com/captf-io/module-images) from this repository's releases and published as
`ghcr.io/captf-io/module-images/azure-cluster`.

The reasons behind every choice are in
[DESIGN.md](https://github.com/captf-io/terraform-azure-cluster/blob/main/DESIGN.md).

## Using it

CAPTF runs this module from the module image `ghcr.io/captf-io/module-images/azure-cluster`:
set the image on a `TerraformCluster`'s `spec.source.image`, and the controller
renders every input. The module is also published to the Terraform Registry as
`captf-io/cluster/azure` and can be called directly:

```hcl
module "cluster" {
  source  = "captf-io/cluster/azure"
  version = "~> 0.1"

  # The contract inputs the controller would render (captf_contract,
  # captf_cluster, captf_object, captf_tags, ...; see Inputs), and any
  # user variables.
}
```

Called directly, the module is a CAPTF root module first:

- it configures its own `provider "azurerm"` block, so the calling
  module cannot use `count`, `for_each` or `depends_on` on it, and the
  provider takes its credentials from the environment (see Identity
  Secret);
- its providers are pinned to exact versions (`versions.tf`), which the
  calling configuration has to accept;
- you set the `captf_*` inputs yourself.

## What it creates

Everything lives in one resource group per cluster, which the module
creates. The network is yours (see Prerequisites).

| Resource | Count | Purpose |
| --- | --- | --- |
| `azurerm_resource_group.cluster_resource_group` | 1 | The cluster's own group: scope of the node identities' rights, home of what cloud-provider-azure creates for Services, and attribution boundary for what Azure cannot tag |
| `azurerm_user_assigned_identity.node_identities` | 0-2 | Managed identities of control-plane and worker nodes, unless you bring them |
| `azurerm_role_assignment.node_role_assignments` | 0+ | Contributor on the group and Network Contributor on the node subnets for the control-plane identity; AcrPull on `container_registry_ids` for both |
| `azurerm_network_security_group.node_security_groups` | 2 | One per role, attached to each node's NIC |
| `azurerm_network_security_rule.node_security_rules` | 7-10 | SSH denied (or allowed from `ssh_allowed_cidrs`) on both roles; intra-cluster traffic; the API server ports; a final deny of the virtual network for the control plane; the kubelet ports denied from the rest of the virtual network on workers |
| `azurerm_application_security_group.node_application_security_groups` | 2 | Name control-plane and worker NICs in the rules |
| `azurerm_availability_set.control_plane_availability_set` | 0-1 | Control-plane fault domains in a region without availability zones |
| `azurerm_public_ip.api_public_ip` | 0-1 | Static Standard public IP of a public API endpoint (`api_load_balancer_public`) |
| `terraform_data.api_endpoint_guard` | 0-1 | Records what fixes the endpoint when the load balancer is created and fails any later plan that would move it |
| `azurerm_lb.api_load_balancer` | 0-1 | Standard load balancer of the API endpoint, internal by default |
| `azurerm_lb_backend_address_pool.api_backend_pool` | 0-1 | Control-plane machines join it from their own state |
| `azurerm_lb_probe.api_probes` | 0-2 | HTTPS `/readyz` (kubeadm) or TCP probe per listener, every 5 seconds |
| `azurerm_lb_rule.api_rules` | 0-2 | The endpoint port to the kube-apiserver, and 9345 with `distribution = "rke2"` |

It reads `azurerm_client_config` (tenant and subscription of the identity),
and `azurerm_resources` listings that find the virtual network (and its
region) and the identities you bring subscription-wide, without failing
when they are gone. Only what the listings found is read further:
`azurerm_virtual_network` (its subnets), `azurerm_location` (the region's
zones) and `azurerm_user_assigned_identity` (client IDs). A network or
identity deleted before the cluster therefore never blocks its destroy;
any other plan stops at a precondition naming it. With a
`control_plane_endpoint` input (an endpoint you own), it creates no load
balancer resources.

## Prerequisites

- **Network.** A virtual network with a subnet for the nodes (and
  optionally a second subnet for workers), in the subscription of the
  identity. Nodes have no public IPs: give the subnets egress, a NAT gateway
  or a firewall, to reach the image registries and Azure's endpoints. The
  management cluster must reach the control-plane subnet when the API
  endpoint is internal (the default).
- **Resource providers** registered in the subscription:
  `Microsoft.Compute`, `Microsoft.Network`, `Microsoft.ManagedIdentity`,
  `Microsoft.Authorization` and `Microsoft.Insights` (autoscale settings of
  the machine pools). The provider does not register them
  (`resource_provider_registrations = "none"`).
- **Permissions** of the identity's service principal: Contributor on the
  subscription (it creates the resource group, and covers joining the
  subnets, which must be in the same subscription; narrow it and the
  network's resource group needs Network Contributor); and Role Based
  Access Control Administrator on the subscription, best with a condition
  that limits it to assigning Contributor, Network Contributor and AcrPull
  (it grants the node identities). Identities you bring need Managed
  Identity Operator for the machine and pool roles to attach them.
- **Quotas.** Standard load balancers and, with `api_load_balancer_public`, one
  Standard public IP per cluster.

## Inputs

Contract inputs used: `captf_cluster` (names), `captf_tags` (tags),
`control_plane_endpoint` (a user endpoint skips the load balancer) and
`cluster_network.api_server_port` (the endpoint port, default 6443; also the
kube-apiserver backend port with kubeadm, while RKE2's is always 6443).
`captf_contract` is validated; `captf_object`, `captf_cluster_outputs`,
`kubernetes_version` and `control_plane_initialized` are declared and not
used.

User variables, set through `spec.variables` of the TerraformCluster:

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `additional_tags` | `map(string)` | `{}` | Extra Azure tags on every taggable resource. Keys starting with `captf.io_` or `captf.io/` are rejected; at most 44 |
| `admin_ssh_public_key` | `string` | `null` (required) | OpenSSH public key (`ssh-rsa` or `ssh-ed25519`) of the nodes' admin user. Azure Linux VMs need a key or a password; the module invents neither. SSH stays closed unless `ssh_allowed_cidrs` opens it |
| `api_allowed_cidrs` | `list(string)` | `[]` | IPv4 CIDRs, besides the virtual network, allowed to reach the API server ports. Required with `api_load_balancer_public`: include the management cluster's egress and the nodes' NAT gateway addresses |
| `api_load_balancer_private_ip` | `string` | `null` | Static private IPv4 address of the internal frontend, in the control-plane subnet. `null` takes a dynamic one, stable for the load balancer's life |
| `api_load_balancer_public` | `bool` | `false` | Put the API load balancer on a public IP |
| `api_server_hairpin_workaround` | `bool` | `true` | Control-plane nodes send their own API traffic for the frontend to their local API server while it is ready ("API server hairpin" below) |
| `container_registry_ids` | `list(string)` | `[]` | Container registry IDs the identities this module creates may pull from (AcrPull) |
| `control_plane_identity_id` | `string` | `null` | Existing user-assigned identity for control-plane nodes. It needs Contributor on the cluster's resource group and Network Contributor on the node subnets, which you grant |
| `distribution` | `string` | `"kubeadm"` | `kubeadm` or `rke2`. RKE2 adds the supervisor port 9345 to the load balancer and the control-plane security group, probes the API server with TCP, and fixes the kube-apiserver backend port at 6443 |
| `resource_group_name` | `string` | `null` | Name of the cluster's resource group, lowercase. `null` derives `captf-<namespace>-<cluster>-<hash>` |
| `ssh_allowed_cidrs` | `list(string)` | `[]` | IPv4 CIDRs allowed to reach SSH on every node (for example an Azure Bastion subnet). Empty: SSH is denied, between nodes too |
| `subnet_id` | `string` | `null` (required) | Subnet for control-plane nodes and the internal frontend, and for workers without `worker_subnet_id` |
| `worker_identity_id` | `string` | `null` | Existing user-assigned identity for worker nodes |
| `worker_subnet_id` | `string` | `null` | Subnet for worker nodes, in the same virtual network as `subnet_id` |
| `zones` | `list(string)` | `[]` | Availability zones to publish as failure domains. Empty uses every zone of the region |

Subnet, identity and registry IDs are matched case-insensitively and
rebuilt with Azure's canonical segment names. Give resource group and
resource names in the casing Azure shows (`az network vnet subnet show
--query id`): role assignment scopes are compared case-sensitively.

## Outputs

| Name | Value |
| --- | --- |
| `control_plane_endpoint` | The user endpoint, or `{host = <frontend address>, port = <API server port>}` |
| `failure_domains` | One entry per zone, `control_plane = true`, empty `attributes`; `[]` without zones |
| `exports` | See Exports |
| `health` | See Health |
| `api_load_balancer_id` | ARM ID of the API load balancer (not a contract output) |
| `resource_group_id` | ARM ID of the cluster's resource group (not a contract output) |

## Exports

`exports` is the object machine and pool modules receive as
`captf_cluster_outputs`, schema `captf.io/azure-cluster/v1`. Adding a key
keeps the schema; renaming or removing one bumps it to `v2`. For an
externally managed TerraformCluster, set the machine and pool variable
`external_cluster_exports` to an object of this shape.

```hcl
{
  schema               = "captf.io/azure-cluster/v1"
  tenant_id            = "<tenant ID>"
  subscription_id      = "<subscription ID, lowercase>"
  region               = "<Azure location, for example westeurope>"
  resource_group_name  = "<cluster resource group, lowercase>"
  resource_group_id    = "<its ARM ID>"
  failure_domains      = { "1" = {}, "2" = {}, "3" = {} } # {} without zones
  virtual_network      = { id, name, resource_group_name }
  subnet_id            = "<control-plane subnet ID>"
  subnet_name          = "<its name>"
  worker_subnet_id     = "<worker subnet ID>"
  worker_subnet_name   = "<its name>"
  admin_username       = "captf"
  admin_ssh_public_key = "<OpenSSH public key>"
  control_plane = {
    identity_id, identity_client_id,
    network_security_group_id, network_security_group_name,
    application_security_group_id,
    availability_set_id # null in a region with zones
  }
  worker = {
    identity_id, identity_client_id,
    network_security_group_id, network_security_group_name,
    application_security_group_id
  }
  # null with a user endpoint
  api = {
    host, port, backend_port, frontend_ip, backend_pool_id,
    hairpin_workaround, # bool
    supervisor_port     # 9345 with distribution rke2, else null
    # port is the endpoint port; backend_port the kube-apiserver's
    # (6443 with rke2)
  }
  # /etc/kubernetes/azure.json for cloud-provider-azure, without
  # userAssignedIdentityID, which each node adds for its identity
  cloud_provider_config = {
    cloud, tenantId, subscriptionId, resourceGroup, location, vmType,
    vnetName, vnetResourceGroup, subnetName, securityGroupName,
    securityGroupResourceGroup, loadBalancerSku,
    maximumLoadBalancerRuleCount, useManagedIdentityExtension,
    useInstanceMetadata
  }
}
```

Nothing in it is secret: the cloud provider authenticates with the nodes'
managed identities.

## Identity Secret

The identity Secret holds the azurerm provider's environment variables:
`ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `ARM_CLIENT_ID`, and
`ARM_CLIENT_SECRET` (or `ARM_CLIENT_CERTIFICATE_PATH` pointing at a file
under `/var/run/captf/credentials/` plus `ARM_CLIENT_CERTIFICATE_PASSWORD`).
Set `ARM_USE_CLI=false`: the images have no Azure CLI.
[`examples/identity.yaml`](https://github.com/captf-io/terraform-azure-cluster/blob/main/examples/identity.yaml) has one; the
permissions it needs are under Prerequisites. The cluster lands in
`ARM_SUBSCRIPTION_ID`, which must be the network's subscription.

## Tags

Every taggable resource gets `local.tags`: `additional_tags`, then the
`captf_tags` with `/` replaced by `_`, because Azure tag names cannot
contain `/` (`captf.io/cluster` becomes `captf.io_cluster`). The captf tags
win. Values longer than Azure's 256 characters keep 247, then `-` and 8 hex
characters of their sha256.

Not taggable in Azure: role assignments, security rules, and load balancer
backend pools, probes and rules. They live in the cluster's resource group,
which is tagged. `terraform_data.api_endpoint_guard` exists only in the
state.

## Health

Health comes from the cluster's own resources, never from the control-plane
nodes behind the load balancer:

| Reading | `state` | `healthy` | `reasons` |
| --- | --- | --- | --- |
| Load balancer and frontend address present (or the resource group, with a user endpoint) | `running` | `true` | `[]` |
| Load balancer or its frontend address gone | `terminated` | `false` | `LoadBalancerNotFound` |
| Resource group gone | `terminated` | `false` | `ResourceGroupNotFound` |

## API server hairpin

An Azure internal load balancer drops a backend's flow to its own frontend
when it maps the flow back to the same backend. kubeadm and the kubelet on
a control-plane node reach the API server through the endpoint, so the
machine module installs a small service on control-plane nodes (cloud-config
bootstrap data only): while the node's own API server answers `/readyz`, an
iptables rule sends the node's connections to the frontend to it directly;
otherwise the rule is gone and the load balancer takes the traffic to
another control-plane node. With `distribution = "rke2"` it covers port 9345
too and counts a 401 or 403 answer as up, as RKE2 may disable anonymous
auth. Turn it off with
`api_server_hairpin_workaround = false`; with Ignition, add the equivalent
to your bootstrap configuration.

## Limitations

- The network, its egress, DNS and peering are yours; the module creates
  none of them.
- Azure public cloud only: `cloud_provider_config.cloud` is
  `AzurePublicCloud`.
- The endpoint is an IP address; there is no DNS name.
- With `distribution = "rke2"` the endpoint port cannot be 9345, the
  supervisor's (a precondition).
- The endpoint is fixed once the load balancer exists: a plan that changes
  `api_load_balancer_public`, `api_load_balancer_private_ip` (other than making
  the current dynamic address static), `cluster_network.api_server_port` or
  the control-plane `subnet_id` fails with the recorded and requested
  values (`terraform_data.api_endpoint_guard`). azurerm would apply these
  in place, out of reach of CAPTF's destructive-plan guard, and CAPI never
  updates the endpoint. Revert the change, or create a new cluster.
- Destroy fails while cloud-provider-azure's load balancers, public IPs or
  disks are still in the resource group
  (`prevent_deletion_if_contains_resources`): delete the cluster's
  LoadBalancer Services and PersistentVolumes first, or remove what is left
  by hand.
- Control-plane nodes accept from the virtual network only the API server
  ports and intra-cluster traffic. Workers deny the kubelet ports (10250,
  10255) from the rest of the virtual network, but otherwise keep Azure's
  default AllowVnetInBound, because cloud-provider-azure relies on it for
  internal Service load balancers: NodePorts and Service ports on workers
  are reachable from the virtual network and networks peered or connected
  to it, so put a network policy or your own NSG rule in front of anything
  that must not be. SSH is denied on both unless
  `ssh_allowed_cidrs` allows it.

## Exceptions

`tfcapi-lint module --strict` passes without allowed warnings. The tests
cannot cover the `LoadBalancerNotFound` and `ResourceGroupNotFound` health
readings: a mock provider never drops a resource on refresh.

## Examples

[`examples/cluster-kubeadm.yaml`](https://github.com/captf-io/terraform-azure-cluster/blob/main/examples/cluster-kubeadm.yaml) creates a
kubeadm cluster with this role, a MachineDeployment and a MachinePool. The
smallest `spec.variables`:

```yaml
variables:
  subnet_id: /subscriptions/<id>/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes
  admin_ssh_public_key: ssh-ed25519 AAAA... ops@example.com
```

A public endpoint:

```yaml
variables:
  subnet_id: /subscriptions/<id>/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes
  admin_ssh_public_key: ssh-ed25519 AAAA... ops@example.com
  api_load_balancer_public: true
  api_allowed_cidrs: [198.51.100.0/24, 203.0.113.7/32]
```

## Developing

The host needs make, podman (or docker with `ENGINE=docker`), jq and Go;
every other tool runs in a digest-pinned container. `make verify` is the
gate. Targets (`make help` lists them):

- `fmt`: format the module with terraform fmt and tofu fmt, in place.
- `fmt-check`: fail on any file terraform fmt or tofu fmt would change.
- `validate`: init and validate on both runtimes and on their floors
  (Terraform 1.5.7, OpenTofu 1.6.3).
- `unit-test`: terraform test and tofu test with mocked providers.
- `tflint`: tflint with the terraform ruleset and the cloud ruleset, per
  `.tflint.hcl`.
- `tfcapi-lint`: `tfcapi-lint module --strict`, built from `PROVIDER_DIR`
  (the cluster-api-provider-terraform checkout; defaults to
  `../cluster-api-provider-terraform`, a sibling clone; the check is skipped
  when it is absent).
- `scan`: trivy config over the repository; ignores live in
  `.trivyignore.yaml`.
- `check-conventions`: `hack/check-layout.sh` and `hack/check-tags.sh`.
- `shellcheck`: shellcheck over `hack/` and every shell template, rendered
  with placeholders.
- `check-headers` / `fix-headers`: fail on, or add, a missing Apache-2.0
  license header.
- `verify`: everything above, in parallel groups.
- `clean`: remove `build/`.

This repository holds the code only; it builds no images. The module images
are built from its releases by [module-images](https://github.com/captf-io/module-images).

<br>
<p align="center">
  <img
    src="https://captf.io/assets/readme/divider.svg"
    width="100%" height="4" alt="">
</p>
<p align="center">
  <a href="https://captf.io/"><img
    src="https://captf.io/assets/readme/mark.svg"
    width="40" height="40" alt="CAPTF"></a>
  <br>
  <a href="https://captf.io/docs/"
    ><b>Documentation</b></a> ·
  <a href="https://captf.io/docs/getting-started/quick-start.html"
    ><b>Quick start</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/CONTRIBUTING.md"
    ><b>Contributing</b></a> ·
  <a href="https://github.com/captf-io/.github/blob/main/SECURITY.md"
    ><b>Security</b></a>
  <br>
  <sub>Built for
    <a href="https://cluster-api.sigs.k8s.io/">Cluster API</a>.
    <a href="https://github.com/captf-io/terraform-azure-cluster/blob/main/LICENSE.md"
    >Apache 2.0</a>.</sub>
</p>
