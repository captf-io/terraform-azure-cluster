# Design: terraform-azure-cluster

Why this module looks the way it does. Each decision names the evidence it
rests on; anything not yet checked against a real subscription is listed
under "Unverified" and must be confirmed on the first reviewed apply.

Pins: `hashicorp/azurerm` 5.7.0. Runtimes: Terraform >= 1.5, OpenTofu >= 1.6.
Conventions: [CONVENTIONS.md](CONVENTIONS.md). Contract:
<https://captf.io/docs/module-author/contract/v1alpha1/>.

This is the `cluster` role. The decision and Unverified numbers are the same
in every terraform-azure-* repository, and the code cites them: a decision
that only concerns another role is a one-line stub that links to the repository
that owns it, and Unverified items of other roles are left out. The other roles:
[terraform-azure-machine](https://github.com/captf-io/terraform-azure-machine/blob/main/DESIGN.md) and
[terraform-azure-machinepool](https://github.com/captf-io/terraform-azure-machinepool/blob/main/DESIGN.md).

## Scope

- Bring-your-own network: the VNet, subnets and egress (NAT Gateway or
  firewall) exist before the cluster. The cluster role creates a resource
  group, network security groups, the API load balancer and node identities.
- The API load balancer is internal by default; public is opt-in with an
  explicit allowed-CIDR list.
- Node identities (user-assigned managed identities) are created by
  default; variables take existing ones.
- Variable names follow the family table of CONVENTIONS.md section 8:
  `api_load_balancer_public`, `api_allowed_cidrs`,
  `api_load_balancer_private_ip`, `distribution` (`kubeadm` or `rke2`) and
  `ssh_allowed_cidrs`; the first draft's `api_server_*` names and
  `rke2_supervisor` are gone.
- `admin_ssh_public_key` is required: Azure Linux VMs need an SSH key or a
  password even when nobody logs in, and the module does not invent one.

## Decisions

### 1. One resource group per cluster

Always created, never brought: it scopes the CCM and CSI role assignments
(Contributor on this group is least privilege only because the group holds
nothing else), it collects what the CCM creates for Services, and it is the
tag boundary for resources Azure does not let us tag. The name defaults to
`captf-<namespace>-<cluster>-<hash>` (CONVENTIONS.md section 6;
`resource_group_name` overrides it) and must be lowercase (section 5). It
has `count = 1`: a single resource that vanished out of band reads as
unknown in a refresh-only run, a counted one as an empty tuple, which the
outputs can turn into null.

`features.resource_group.prevent_deletion_if_contains_resources = true`:
cluster destroy fails loudly when the CCM left load balancers or persistent
disks behind, instead of deleting data. The runbook step is to remove them.

### 2. API load balancer and hairpin

- Standard Load Balancer, internal by default (frontend in the subnet,
  dynamic or a configured static IP); public uses a Standard static public
  IP. Both set zones explicitly (every zone of the region) and ignore later
  changes to them: `zones` is ForceNew without Computed on the public IP
  (`ZonesMultipleOptionalForceNew`, `network/public_ip_resource.go`), and a
  frontend zones change forces a new load balancer
  (`loadbalancer/lb_resource.go` CustomizeDiff, `d.ForceNew(...zones)`),
  so a reported difference would replace the endpoint. The internal
  frontend's `ignore_changes = [frontend_ip_configuration[0].zones]` covers
  that case, which the first draft left open.
- Rules: TCP endpoint port to the kube-apiserver backend port (and 9345 to
  9345 with `distribution = "rke2"`). The backend port equals the endpoint
  port (`cluster_network.api_server_port ?? 6443`) with kubeadm and is
  always 6443 with RKE2, which reads neither field (control-planes/rke2.md;
  CONVENTIONS.md section 12); the first draft used the endpoint port for
  RKE2 too, so its load balancer would never turn healthy on another port.
  An endpoint port of 9345 with RKE2 fails a precondition. Also
  `tcp_reset_enabled = true`, probes every 5 s. `disable_outbound_snat` is
  set for a public frontend only: an internal frontend has no outbound SNAT
  to disable.
- Probes: HTTPS `GET /readyz` on the API port for kubeadm (anonymous
  `/readyz` is allowed by default), so a listening but unready API server
  gets no traffic; TCP with `distribution = "rke2"`, where anonymous auth may be
  off, and TCP on 9345 (its readyz answers 403, which an Azure probe counts
  as down). Changed from "TCP probes" in the first draft; both forms are
  allowed by control-planes/checklist.md "Health checks".
- Control-plane machines join the backend pool with
  `azurerm_network_interface_backend_address_pool_association` in their own
  state, before the VM boots.
- An internal Standard Load Balancer does not hairpin: a backend's flow to
  its own frontend that is mapped back to itself fails. The machine role
  therefore wraps control-plane `custom_data` (cloud-config only) in a MIME
  multipart whose `text/cloud-boothook` installs a small service: while the
  local apiserver answers `/readyz`, it DNATs traffic for the frontend IP
  and port to the node's own address (the source address of its route to
  the frontend), which the apiserver advertises whatever its bind address;
  otherwise it removes the rule. The service is a transient systemd unit
  started with `systemd-run --no-block` (no daemon-reload; cloud-init's
  boothook runs before the boot transaction a blocking start would wait
  for). The first draft DNATed to `127.0.0.1`, which fails when the
  apiserver binds only its node address. While a node's
  own apiserver is down its probe is down too, so its join traffic goes to
  other backends; once healthy it reaches itself locally.
  `api_server_hairpin_workaround = false` turns the workaround off (Ignition users add the equivalent to their
  `preKubeadmCommands`, as CAPZ's private-cluster guide does).
- With RKE2 (`supervisor_port` in exports) the service also DNATs 9345 and
  counts a 401 or 403 from `/readyz` as up: RKE2 may run the apiserver
  without anonymous auth, and a 200-only check left the workaround inert
  (review finding). A precondition on the VM requires the exported address
  and ports to be an IPv4 address and port numbers, since they reach a root
  shell script (`external_cluster_exports` is user input).
- No `prevent_destroy`: it would block deleting the cluster too. CAPTF's
  destructive-plan guard stops only deletes and replacements, and azurerm
  5.7.0 changes a frontend's public IP, private address and subnet and the
  rule ports in place (adding or removing a frontend no longer forces a new
  load balancer; only zones do), so those changes would move the endpoint
  without any delete, which the first draft missed.
  `terraform_data.api_endpoint_guard` (the pattern of the OpenStack modules)
  records `api_load_balancer_public`, the port, the control-plane subnet and the
  private address the frontend actually got, with `ignore_changes` on its
  input, and a postcondition fails any later plan that changes them, naming
  the recorded and requested values. Making the current dynamic address
  static is allowed: it moves nothing. The endpoint-stability rule of
  cluster.md is thereby enforced, not just documented.

### 3. Network security groups

NSGs are attached at the NIC, not the bring-your-own subnet. No inline
`security_rule` blocks: the CCM adds Service rules to the worker NSG and
inline rules would fight it (`security_rule` is Optional+Computed in
azurerm 5.7.0, so CCM rules cause no drift). Application security groups
identify control plane and workers. Rules:

- both roles: SSH (22/tcp) allowed from `ssh_allowed_cidrs` (priority
  100) and denied from anywhere else (110), ahead of the intra-cluster
  allow, so the secure default "no SSH" holds against AllowVnetInBound and
  between nodes (review finding: the first draft let the network reach SSH
  on workers);
- both roles: everything between the ASGs (priority 120);
- control plane: the API ports from `VirtualNetwork` (130) in both modes (workers
  reach the apiserver directly through the `kubernetes` Service, and an
  internal LB keeps the client address), from `api_allowed_cidrs`
  (140) too (required when public; must include the NAT Gateway's IPs), and a
  final deny of `VirtualNetwork` inbound at 4096 that overrides Azure's
  AllowVnetInBound; AllowAzureLoadBalancerInBound stays for probes.
- workers: no final deny. cloud-provider-azure adds no NSG rule for an
  internal Service load balancer without source ranges and relies on
  AllowVnetInBound (`pkg/provider/loadbalancer/accesscontrol.go`,
  `IsAllowFromInternet` and `DenyAllExceptSourceRanges`: "By default, NSG
  allow traffic from the VNet"), so a deny there would cut internal
  LoadBalancer Services off from the network. The first draft denied the
  network on both roles.

Custom priorities stay within Azure's 100-4096 and below 500, where the
CCM's rules start.

### 4. Node identities

User-assigned managed identities for control plane and workers. Control
plane: Contributor on the cluster resource group (CCM, Azure Disk CSI) and
Network Contributor on each bring-your-own subnet. Workers: none by
default (AcrPull through a variable). Role assignments use
`principal_type = "ServicePrincipal"` and
`skip_service_principal_aad_check = true` to avoid replication lag.

### 5. provider_id

`azure:///subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Compute/virtualMachines/<name>`.
cloud-provider-azure v1.37.0 returns the ARM ID through
`ConvertResourceGroupNameToLower` (`pkg/provider/azure_wrap.go`), so the
module builds the ID from a lowercased subscription and resource group and
requires a lowercase resource group name. Re-checked on `release-1.34`:
`availabilitySet.GetInstanceIDByNodeName` (`azure_standard.go`) returns
`ConvertResourceGroupNameToLower(*machine.ID)` for the VM it finds by Node
name, so the Node must be named after the VM: the examples set
`nodeRegistration.name: '{{ ds.meta_data["local_hostname"] }}'`, and the
VM name and `computer_name` are both `machine_name` made valid (lowercase
`[a-z0-9-]`, at most 64; otherwise cut to 55 plus `-` and 8 hex of its
sha256). Scale set instances:
`.../virtualMachineScaleSets/<vmss>/virtualMachines/<instance-id>`
(`azure_vmss.go` `vmssVMProviderIDRE`).

### 6. Machine

- `azurerm_linux_virtual_machine`, `computer_name = name = machine_name`
  made valid, password authentication off, extension operations off,
  optional trusted launch (secure boot, vTPM), optional encryption at host,
  boot diagnostics, user-assigned identity.
- Trusted launch is off by default, a change from the first draft: CAPZ
  says its reference images do not support it ("Trusted launch supported
  OS images are not included in the list of `capi` reference images",
  CAPZ `docs/book/src/self-managed/trusted-launch-for-vms.md`), and the
  examples use them. Turn it on with an image built for it.
- `image_id` takes any ID `source_image_id` accepts; `{version}` and
  `{semver}` in it become the Machine's version (`v1.31.4`, `1.31.4`;
  CONVENTIONS.md section 8, which replaced the first draft's
  `{kubernetes_version}`), without any `+suffix`, so the
  CAPZ community gallery
  (`/communityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/images/capi-ubun2-2404/versions/<1.x.y>`,
  CAPZ `azure/defaults.go` and `azure/services/virtualmachineimages/images.go`)
  follows version upgrades with one setting. azurerm 5.7.0 parses
  community and shared gallery IDs case-sensitively
  (`compute/parse/community_gallery_image_version.go`: `communityGalleries`,
  `images`, `versions`); the validation enforces that form.
- Custom data, not `user_data`: user data is exposed through IMDS, custom
  data is not. Ignition goes in verbatim; gzipped Ignition fails a
  precondition (CONVENTIONS.md section 13). Spot on a control-plane machine
  fails a precondition (section 11). The boothooks are POSIX sh, and the
  MIME envelope (`templates/user_data.mime.tftpl`: no preamble, parts
  `captf-boothook.sh` and `bootstrap`) and the pool's node-labels fragment
  (`templates/node_labels.tftpl`) are the family's shared copies. cloud-config goes in a MIME
  multipart: a `text/cloud-boothook` part (below), then the bootstrap data
  as a base64 part that is never decoded, `text/plain` so cloud-init
  detects the type itself (which keeps CABPK's `## template: jinja` header
  working; a `text/cloud-config` part would skip the Jinja rendering of
  `{{ ds.meta_data.local_hostname }}`), or `application/x-gzip` when the
  base64 starts with `H4sI`, which cloud-init decompresses first
  (`cloudinit/user_data.py`, `TYPE_NEEDED`, `DECOMP_TYPES`). The base64 is
  wrapped at 76 characters (RFC 2045). Precondition: at most 87380 base64
  characters, the encoding of Azure's 65535-byte limit.
- The boothook writes `/etc/kubernetes/azure.json` only when it is absent
  (boothooks run on every boot; a file the bootstrap data writes must keep
  winning after a reboot), the cloud-provider-azure
  config, from the cluster's `exports.cloud_provider_config` plus the
  node's identity client ID (`useManagedIdentityExtension`, no secret), and
  on control-plane nodes starts the hairpin service. Without azure.json the
  CCM cannot start, Nodes keep their uninitialized taint and never get a
  provider ID, and no Machine gets its Node; the derived names (resource
  group, NSG, identity client IDs) are not something a user can easily
  write into a KubeadmConfig, so the module provides it. This is new
  relative to the first draft. Ignition users write it themselves.
- Without exports (externally managed cluster, no
  `external_cluster_exports`) every resource has count 0 and a
  precondition on the listing data source explains what to set: with the
  VM itself as the primary resource, the NIC's null `location` failed plan
  first with "Missing required argument".
- The azurerm VM resource has no power state. `data.azurerm_virtual_machine`
  has it but errors on a 404, which would fail every refresh and destroy
  once the VM is gone. So `data.azurerm_resources` (an empty list, not an
  error, when the VM is missing; it does not reference the VM resource, so
  its count is known at plan time) guards a counted
  `data.azurerm_virtual_machine`. On the first apply health is `pending`
  until the next refresh; ARM listings can lag minutes.
- Spot: `priority = "Spot"`, `eviction_policy = "Deallocate"`,
  `max_bid_price = -1`. Pools use `Delete` instead (decision 7).
- Zones from exports; with no `failure_domain` the zone is picked from the
  sha256 of `machine_name`. Regions without zones use an availability set
  for control-plane machines.

### 7. Machine pool

Concerns the machine pool role: see [terraform-azure-machinepool DESIGN.md](https://github.com/captf-io/terraform-azure-machinepool/blob/main/DESIGN.md#7-machine-pool).

### 8. Health

Cluster health is the load balancer's presence; a load balancer or resource group
gone is `terminated` (`LoadBalancerNotFound`, `ResourceGroupNotFound`),
as CONVENTIONS.md section 10 requires of a primary resource that is gone. A resource deleted out of band leaves the
state on refresh; every output reads such attributes through `try()` or
`one()`.

### 9. Tags

Azure tag names cannot contain `< > % & \ ? /`: `captf.io/cluster` →
`captf.io_cluster`. `additional_tags` may hold 44 tags (Azure's 50 minus
the six captf tags). Values up to 256 characters (longer: 247 plus `-` plus
8 hex of sha256). Not taggable: role assignments, security rules, load
balancer pools, probes and rules, NIC associations, and the OS disks and
NICs a scale set creates; the cluster resource group is the attribution
boundary for those.

### 10. Credentials

Identity Secret: `ARM_TENANT_ID`, `ARM_SUBSCRIPTION_ID`, `ARM_CLIENT_ID`,
`ARM_CLIENT_SECRET`, `ARM_USE_CLI=false` (no `az` CLI in the image), or
a client certificate: `ARM_CLIENT_CERTIFICATE` (base64) or
`ARM_CLIENT_CERTIFICATE_PATH` (a file under `/var/run/captf/credentials/`),
with `ARM_CLIENT_CERTIFICATE_PASSWORD`. The provider block sets
`resource_provider_registrations = "none"` (registration of Compute,
Network, ManagedIdentity, Authorization and Insights is a prerequisite) and
`subscription_id` from exports for machine and pool. The job's identity
needs Contributor on the subscription (to create resource groups; it also
covers joining the subnets, which must be in that subscription) and Role
Based Access Control Administrator with a condition limiting assignable
roles. Network Contributor on the network's group is only needed if
Contributor is narrowed.

### 11. Region and zones

The location is the brought virtual network's: NICs cannot use a subnet in
another region, so a `location` variable could only be wrong. The zones are
`data.azurerm_location.zone_mappings` (the logical zones this subscription
sees), optionally narrowed by `zones`. The exports key is `region`, as in
the CONVENTIONS.md section 12 skeleton (its value is the Azure location
name, such as `westeurope`); `cloud_provider_config.location` keeps
cloud-provider-azure's own key.

Brought dependencies must not block a destroy (review finding). The cluster
finds the network and existing identities with subscription-wide
`data.azurerm_resources` listings (filtered by resource group in HCL; a
listing scoped to a missing group fails with ResourceGroupNotFound) and
reads `azurerm_virtual_network`, `azurerm_location` and
`azurerm_user_assigned_identity` only for what they found; the region
comes from the listing. Their existence and the subnets are preconditions
on the resource group, which Terraform skips when it plans a destroy. The
machine and pool listings of their VM and scale set work the same way.
The resource group's name prefix is reduced to `[a-z0-9-]`, since identity
names allow no dots.

### 12. Tooling

Concerns how the module images are tested, not this repository: see [archived azure-modules DESIGN.md](https://github.com/captf-io/azure-modules/blob/main/DESIGN.md#12-tooling).

## Exports (`captf.io/azure-cluster/v1`)

The first draft's keys, with the NSG and ASG IDs spelled out, plus the
values the cloud provider config and the BYO cases need:

```hcl
{
  schema               = "captf.io/azure-cluster/v1"
  tenant_id            = "<tenant id>"
  subscription_id      = "<lowercase id>"
  region               = "<Azure location>"
  resource_group_name  = "<lowercase name>"
  resource_group_id    = "<id>"
  failure_domains      = { "1" = {}, "2" = {}, "3" = {} } # {} without zones
  virtual_network      = { id, name, resource_group_name }
  subnet_id            = "<id>"
  subnet_name          = "<name>"
  worker_subnet_id     = "<id>"
  worker_subnet_name   = "<name>"
  admin_username       = "captf"
  admin_ssh_public_key = "<public key>"
  control_plane        = { identity_id, identity_client_id, network_security_group_id, network_security_group_name, application_security_group_id, availability_set_id }
  worker               = { identity_id, identity_client_id, network_security_group_id, network_security_group_name, application_security_group_id }
  api                  = { host, port, backend_port, frontend_ip, backend_pool_id, hairpin_workaround, supervisor_port } # null for a user endpoint
  cloud_provider_config = { cloud, tenantId, subscriptionId, resourceGroup, location, vmType = "vmss", vnetName, vnetResourceGroup, subnetName, securityGroupName, securityGroupResourceGroup, loadBalancerSku, maximumLoadBalancerRuleCount, useManagedIdentityExtension, useInstanceMetadata }
}
```

## Unverified

**1.** Whether Azure reports zones on an internal frontend or public IP that
were created with them, differently from what was sent. ForceNew on a
zones change is verified (decision 2); `ignore_changes` makes the answer
harmless either way.

**2.** The minimal built-in role set for cloud-provider-azure and Azure Disk
CSI (Contributor on the group, Network Contributor on the subnets).

**5.** Public load balancer hairpin through SNAT; RKE2 needing the hairpin
workaround at all; the DNAT to the node's own address working with every
CNI's iptables rules.

**8.** ARM echoing a role assignment's subnet or registry scope with the casing
it was created with (azurerm compares scopes case-sensitively; a
different casing would replace the assignment on every plan).

**11.** A destroy of the cluster after its network was deleted: preconditions
are skipped in destroy plans, and the resource group's then-null
location must not fail the destroy's refresh.

**12.** RKE2's apiserver answering `/readyz` with 401 or 403 when anonymous
auth is off, and the hairpin's 9345 DNAT being needed at all.

The numbers are those of the other terraform-azure-* repositories; the gaps are
items of the other roles.

## Rejected alternatives

- Bring-your-own resource group (breaks least privilege and attribution).
- A deny of the virtual network on worker NSGs (breaks internal Service
  load balancers, decision 3).
- A generated or "sealed" SSH key (state secret, or trust in an unprovable
  claim).
