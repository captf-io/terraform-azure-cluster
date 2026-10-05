# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Unit tests of the cluster role with a mocked azurerm provider: nothing
# reaches Azure. Run with `make unit-test` (terraform test and tofu test).

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      client_id       = "0a8b3c1d-6e2f-4a7b-9c8d-1e2f3a4b5c6d"
      object_id       = "1b9c4d2e-7f3a-4b8c-8d9e-2f3a4b5c6d7e"
      subscription_id = "6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11"
      tenant_id       = "72f988bf-86f1-41af-91ab-2d7cd011db47"
    }
  }

  mock_data "azurerm_virtual_network" {
    defaults = {
      id       = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub"
      location = "westeurope"
      subnets  = ["nodes", "workers", "AzureBastionSubnet"]
    }
  }

  # The subscription-wide listings find the brought network. Runs with
  # existing identities override them to find those instead.
  mock_data "azurerm_resources" {
    defaults = {
      resources = [{
        id                  = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub"
        location            = "westeurope"
        name                = "hub"
        resource_group_name = "network"
        tags                = {}
        type                = "Microsoft.Network/virtualNetworks"
      }]
    }
  }

  mock_data "azurerm_location" {
    defaults = {
      zone_mappings = [
        { logical_zone = "1", physical_zone = "westeurope-az1" },
        { logical_zone = "2", physical_zone = "westeurope-az3" },
        { logical_zone = "3", physical_zone = "westeurope-az2" },
      ]
    }
  }

  mock_data "azurerm_user_assigned_identity" {
    defaults = {
      client_id    = "3c0d5e3f-8a4b-4c9d-9e0f-3a4b5c6d7e8f"
      principal_id = "4d1e6f4a-9b5c-4d0e-8f1a-4b5c6d7e8f9a"
    }
  }

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c"
    }
  }

  # IDs other resources take as arguments are pinned in ARM format: the
  # provider validates them even when mocked. Network security groups and
  # identities keep generated IDs, so reapply_is_stable can see a
  # replacement.
  mock_resource "azurerm_lb" {
    defaults = {
      id                 = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api"
      private_ip_address = "10.0.0.100"
    }
  }

  mock_resource "azurerm_lb_backend_address_pool" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api/backendAddressPools/control-plane"
    }
  }

  mock_resource "azurerm_lb_probe" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api/probes/api-server"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/publicIPAddresses/captf-team-a-demo-2a8d5f7c-api"
      ip_address = "203.0.113.10"
    }
  }

  mock_resource "azurerm_application_security_group" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/applicationSecurityGroups/captf-team-a-demo-2a8d5f7c-nodes-asg"
    }
  }

  mock_resource "azurerm_availability_set" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/availabilitySets/captf-team-a-demo-2a8d5f7c-control-plane"
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      client_id    = "5e2f7a5b-0c6d-4e1f-9a2b-5c6d7e8f9a0b"
      principal_id = "6f3a8b6c-1d7e-4f2a-8b3c-6d7e8f9a0b1c"
    }
  }
}

variables {
  captf_contract            = "v1alpha1"
  captf_cluster             = { name = "demo", namespace = "team-a" }
  captf_object              = { kind = "TerraformCluster", name = "demo", namespace = "team-a" }
  captf_tags                = { "captf.io/cluster" = "demo", "captf.io/namespace" = "team-a", "captf.io/kind" = "TerraformCluster", "captf.io/name" = "demo", "captf.io/managed-by" = "captf", "captf.io/template" = "" }
  control_plane_endpoint    = null
  kubernetes_version        = "v1.34.1"
  control_plane_initialized = false
  cluster_network           = { pods = ["192.168.0.0/16"], services = ["10.128.0.0/12"], service_domain = "cluster.local", api_server_port = 6443 }

  admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0wmN/Cr3JXqmLW7u+g9pTh+wyqDHpSQEIQczXkVx9q captf@example"
  subnet_id            = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes"
}

run "happy_path" {
  assert {
    condition     = output.control_plane_endpoint == { host = "10.0.0.100", port = 6443 }
    error_message = "control_plane_endpoint must be the internal frontend address on the API server port."
  }
  assert {
    condition = output.failure_domains == [
      { name = "1", control_plane = true, attributes = {} },
      { name = "2", control_plane = true, attributes = {} },
      { name = "3", control_plane = true, attributes = {} },
    ]
    error_message = "failure_domains must list every zone of the region, eligible for the control plane."
  }
  assert {
    condition     = output.health.state == "running" && output.health.healthy && output.health.message == null && length(output.health.reasons) == 0
    error_message = "A cluster with its load balancer is running and healthy."
  }
  assert {
    condition     = output.exports.schema == "captf.io/azure-cluster/v1" && output.exports.region == "westeurope"
    error_message = "exports must carry the schema and the virtual network's region."
  }
  assert {
    condition     = output.exports.api.frontend_ip == "10.0.0.100" && output.exports.api.backend_pool_id == azurerm_lb_backend_address_pool.api_backend_pool[0].id
    error_message = "exports.api must name the frontend address and the backend pool control-plane machines join."
  }
  assert {
    condition     = output.api_load_balancer_id == azurerm_lb.api_load_balancer[0].id
    error_message = "api_load_balancer_id must be the load balancer's ID."
  }
  assert {
    condition     = output.resource_group_id == "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c"
    error_message = "resource_group_id must be the resource group's ID."
  }
  assert {
    condition     = azurerm_resource_group.cluster_resource_group[0].name == "captf-team-a-demo-${substr(sha256("team-a/demo"), 0, 8)}" && azurerm_resource_group.cluster_resource_group[0].location == "westeurope"
    error_message = "The resource group is named captf-<namespace>-<cluster>-<hash> and lives in the network's region."
  }
  assert {
    condition     = azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].subnet_id == "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes"
    error_message = "The internal frontend must sit in the control-plane subnet."
  }
  assert {
    condition     = toset(azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].zones) == toset(["1", "2", "3"]) && azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].private_ip_address_allocation == "Dynamic"
    error_message = "The internal frontend must be zone-redundant and dynamic by default."
  }
  assert {
    condition     = azurerm_lb_rule.api_rules["api-server"].frontend_port == 6443 && azurerm_lb_rule.api_rules["api-server"].backend_port == 6443 && azurerm_lb_rule.api_rules["api-server"].tcp_reset_enabled && !azurerm_lb_rule.api_rules["api-server"].disable_outbound_snat
    error_message = "The API rule maps 6443 to 6443 with TCP reset."
  }
  assert {
    condition     = azurerm_lb_probe.api_probes["api-server"].protocol == "Https" && azurerm_lb_probe.api_probes["api-server"].request_path == "/readyz" && azurerm_lb_probe.api_probes["api-server"].interval_in_seconds == 5
    error_message = "The kubeadm API probe is HTTPS /readyz every 5 seconds."
  }
  assert {
    condition     = length(azurerm_public_ip.api_public_ip) == 0 && length(azurerm_availability_set.control_plane_availability_set) == 0
    error_message = "An internal endpoint in a zonal region needs neither a public IP nor an availability set."
  }
  assert {
    condition     = keys(azurerm_user_assigned_identity.node_identities) == ["control-plane", "worker"]
    error_message = "Both node identities are created by default."
  }
  assert {
    condition = keys(azurerm_role_assignment.node_role_assignments) == [
      "control-plane/Contributor/resource-group",
      "control-plane/Network Contributor/subnet-control-plane",
    ]
    error_message = "The control-plane identity gets Contributor on the group and Network Contributor on the shared subnet, once."
  }
  assert {
    condition     = azurerm_role_assignment.node_role_assignments["control-plane/Contributor/resource-group"].scope == azurerm_resource_group.cluster_resource_group[0].id && azurerm_role_assignment.node_role_assignments["control-plane/Contributor/resource-group"].principal_type == "ServicePrincipal"
    error_message = "Contributor is scoped to the cluster's resource group, for a service principal."
  }
  assert {
    condition = toset(keys(azurerm_network_security_rule.node_security_rules)) == toset([
      "control-plane/allow-cluster-inbound",
      "control-plane/allow-api-server-from-virtual-network",
      "control-plane/deny-virtual-network-inbound",
      "control-plane/deny-ssh-inbound",
      "worker/allow-cluster-inbound",
      "worker/deny-ssh-inbound",
    ])
    error_message = "The default rules: no SSH and intra-cluster for both roles; API from the network and a final deny for the control plane."
  }
  assert {
    condition     = azurerm_network_security_rule.node_security_rules["worker/deny-ssh-inbound"].priority < azurerm_network_security_rule.node_security_rules["worker/allow-cluster-inbound"].priority && azurerm_network_security_rule.node_security_rules["worker/deny-ssh-inbound"].destination_port_range == "22" && azurerm_network_security_rule.node_security_rules["worker/deny-ssh-inbound"].source_address_prefix == "*"
    error_message = "SSH is denied from anywhere, ahead of the intra-cluster allow."
  }
  assert {
    condition     = jsonencode(terraform_data.api_endpoint_guard[0].input) == jsonencode({ port = 6443, private_ip_address = "10.0.0.100", public = false, subnet_id = lower(var.subnet_id) })
    error_message = "The endpoint guard records what fixes the endpoint, with the address the frontend got."
  }
  assert {
    condition     = azurerm_network_security_rule.node_security_rules["control-plane/allow-api-server-from-virtual-network"].destination_port_ranges == toset(["6443"])
    error_message = "The API rule opens the API server port only."
  }
  assert {
    condition     = azurerm_network_security_rule.node_security_rules["control-plane/deny-virtual-network-inbound"].priority == 4096 && azurerm_network_security_rule.node_security_rules["control-plane/deny-virtual-network-inbound"].access == "Deny" && azurerm_network_security_rule.node_security_rules["control-plane/deny-virtual-network-inbound"].source_address_prefix == "VirtualNetwork"
    error_message = "The control plane's final deny of the virtual network has the lowest custom priority."
  }
}

# Runs directly after happy_path, with the same variables. Earlier outputs
# reach it through variables because OpenTofu does not resolve run.<name>
# inside assertions. The security groups and identities keep mock-generated
# IDs, so a replacement would change them.
run "reapply_is_stable" {
  variables {
    previous_exports  = run.happy_path.exports
    previous_endpoint = run.happy_path.control_plane_endpoint
  }

  assert {
    condition = alltrue([
      output.exports.control_plane.network_security_group_id == var.previous_exports.control_plane.network_security_group_id,
      output.exports.worker.network_security_group_id == var.previous_exports.worker.network_security_group_id,
      output.exports.control_plane.identity_id == var.previous_exports.control_plane.identity_id,
      output.exports.worker.identity_id == var.previous_exports.worker.identity_id,
      output.exports.api.backend_pool_id == var.previous_exports.api.backend_pool_id,
      output.exports.resource_group_id == var.previous_exports.resource_group_id,
    ])
    error_message = "A second identical apply must keep every resource."
  }
  assert {
    condition     = output.control_plane_endpoint == var.previous_endpoint
    error_message = "The endpoint must not move on a reapply."
  }
}

run "tags_on_taggable_resources" {
  variables {
    additional_tags = { costCenter = "1234" }
  }

  assert {
    condition = alltrue([
      for t in concat(
        [azurerm_resource_group.cluster_resource_group[0].tags, azurerm_lb.api_load_balancer[0].tags],
        [for r in azurerm_network_security_group.node_security_groups : r.tags],
        [for r in azurerm_application_security_group.node_application_security_groups : r.tags],
        [for r in azurerm_user_assigned_identity.node_identities : r.tags],
      ) : t["captf.io_cluster"] == "demo" && t["captf.io_namespace"] == "team-a" && t["captf.io_kind"] == "TerraformCluster" && t["captf.io_managed-by"] == "captf" && t["costCenter"] == "1234"
    ])
    error_message = "Every taggable resource carries the mapped captf tags and the additional tags."
  }
}

run "exports_shape" {
  assert {
    condition = toset(keys(output.exports)) == toset([
      "schema", "tenant_id", "subscription_id", "region", "resource_group_name", "resource_group_id",
      "failure_domains", "virtual_network", "subnet_id", "subnet_name", "worker_subnet_id", "worker_subnet_name",
      "admin_username", "admin_ssh_public_key", "control_plane", "worker", "api", "cloud_provider_config",
    ])
    error_message = "exports must have exactly the documented keys of captf.io/azure-cluster/v1."
  }
  assert {
    condition     = output.exports.subscription_id == "6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11" && output.exports.tenant_id == "72f988bf-86f1-41af-91ab-2d7cd011db47" && output.exports.resource_group_name == lower(azurerm_resource_group.cluster_resource_group[0].name)
    error_message = "exports carry the tenant, the subscription and the lowercase resource group."
  }
  assert {
    condition     = output.exports.failure_domains == { "1" = {}, "2" = {}, "3" = {} }
    error_message = "exports.failure_domains holds one entry per zone."
  }
  assert {
    condition     = output.exports.subnet_id == var.subnet_id && output.exports.worker_subnet_id == var.subnet_id && output.exports.worker_subnet_name == "nodes"
    error_message = "Workers share the control-plane subnet without worker_subnet_id."
  }
  assert {
    condition     = output.exports.admin_username == "captf" && output.exports.admin_ssh_public_key == var.admin_ssh_public_key
    error_message = "exports carry the admin user and key."
  }
  assert {
    condition     = toset(keys(output.exports.control_plane)) == toset(["identity_id", "identity_client_id", "network_security_group_id", "network_security_group_name", "application_security_group_id", "availability_set_id"]) && output.exports.control_plane.availability_set_id == null
    error_message = "exports.control_plane has its documented keys; no availability set in a zonal region."
  }
  assert {
    condition     = output.exports.control_plane.identity_client_id == "5e2f7a5b-0c6d-4e1f-9a2b-5c6d7e8f9a0b"
    error_message = "exports.control_plane carries the identity's client ID for the cloud provider config."
  }
  assert {
    condition     = toset(keys(output.exports.worker)) == toset(["identity_id", "identity_client_id", "network_security_group_id", "network_security_group_name", "application_security_group_id"])
    error_message = "exports.worker has its documented keys."
  }
  assert {
    condition     = jsonencode(output.exports.api) == jsonencode({ host = "10.0.0.100", port = 6443, backend_port = 6443, frontend_ip = "10.0.0.100", backend_pool_id = azurerm_lb_backend_address_pool.api_backend_pool[0].id, hairpin_workaround = true, supervisor_port = null })
    error_message = "exports.api has its documented shape."
  }
  assert {
    condition = output.exports.cloud_provider_config == {
      cloud                        = "AzurePublicCloud"
      tenantId                     = "72f988bf-86f1-41af-91ab-2d7cd011db47"
      subscriptionId               = "6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11"
      resourceGroup                = azurerm_resource_group.cluster_resource_group[0].name
      location                     = "westeurope"
      vmType                       = "vmss"
      vnetName                     = "hub"
      vnetResourceGroup            = "network"
      subnetName                   = "nodes"
      securityGroupName            = azurerm_network_security_group.node_security_groups["worker"].name
      securityGroupResourceGroup   = azurerm_resource_group.cluster_resource_group[0].name
      loadBalancerSku              = "Standard"
      maximumLoadBalancerRuleCount = 250
      useManagedIdentityExtension  = true
      useInstanceMetadata          = true
    }
    error_message = "exports.cloud_provider_config is the azure.json of cloud-provider-azure for managed identities."
  }
  assert {
    condition     = alltrue([for k, v in output.exports.control_plane : v == null || can(tostring(v))]) && alltrue([for k, v in output.exports.worker : can(tostring(v))])
    error_message = "exports nest only strings below the role objects."
  }
}

run "user_endpoint_skips_load_balancer" {
  variables {
    control_plane_endpoint = { host = "api.demo.example.com", port = 443 }
  }

  assert {
    condition     = output.control_plane_endpoint == { host = "api.demo.example.com", port = 443 }
    error_message = "A user endpoint is passed through."
  }
  assert {
    condition     = length(azurerm_lb.api_load_balancer) == 0 && length(azurerm_public_ip.api_public_ip) == 0 && length(azurerm_lb_backend_address_pool.api_backend_pool) == 0 && length(azurerm_lb_probe.api_probes) == 0 && length(azurerm_lb_rule.api_rules) == 0
    error_message = "A user endpoint creates no load balancer."
  }
  assert {
    condition     = output.exports.api == null && output.api_load_balancer_id == null
    error_message = "exports.api is null with a user endpoint."
  }
  assert {
    condition     = output.health.state == "running" && output.health.healthy
    error_message = "Health follows the resource group with a user endpoint."
  }
}


run "default_api_server_port" {
  variables {
    cluster_network = null
  }

  assert {
    condition     = output.control_plane_endpoint.port == 6443
    error_message = "Without cluster_network the API server port is 6443."
  }
}




run "rke2_supervisor_listener" {
  variables {
    distribution = "rke2"
  }

  assert {
    condition     = azurerm_lb_rule.api_rules["rke2-supervisor"].frontend_port == 9345 && azurerm_lb_rule.api_rules["rke2-supervisor"].backend_port == 9345 && azurerm_lb_probe.api_probes["rke2-supervisor"].protocol == "Tcp"
    error_message = "RKE2 adds a 9345 listener with a TCP probe on the same frontend."
  }
  assert {
    condition     = azurerm_lb_probe.api_probes["api-server"].protocol == "Tcp" && azurerm_lb_probe.api_probes["api-server"].request_path == null
    error_message = "RKE2 may disable anonymous auth, so its API probe is TCP."
  }
  assert {
    condition     = azurerm_network_security_rule.node_security_rules["control-plane/allow-api-server-from-virtual-network"].destination_port_ranges == toset(["6443", "9345"]) && output.exports.api.supervisor_port == 9345
    error_message = "RKE2 opens 9345 and exports the supervisor port."
  }
}

run "region_without_zones" {
  override_data {
    target = data.azurerm_location.cluster_location
    values = {
      zone_mappings = []
    }
  }

  assert {
    condition     = output.failure_domains == [] && output.exports.failure_domains == {}
    error_message = "A region without zones has no failure domains."
  }
  assert {
    condition     = length(azurerm_availability_set.control_plane_availability_set) == 1 && output.exports.control_plane.availability_set_id == azurerm_availability_set.control_plane_availability_set[0].id
    error_message = "A region without zones gets a control-plane availability set."
  }
  # The load balancer exists from the earlier runs: a zones change must not
  # touch its frontend, which ignore_changes guarantees.
  assert {
    condition     = toset(azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].zones) == toset(["1", "2", "3"])
    error_message = "Frontend zones only matter at creation; a later difference must not replace the load balancer."
  }
}

run "zones_subset" {
  variables {
    zones = ["3", "1"]
  }

  assert {
    condition     = [for d in output.failure_domains : d.name] == ["1", "3"]
    error_message = "zones restricts the failure domains, sorted."
  }
  assert {
    condition     = toset(azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].zones) == toset(["1", "2", "3"])
    error_message = "The frontend stays zone-redundant over every zone of the region."
  }
}

run "node_identity_byo" {
  variables {
    control_plane_identity_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/identities/providers/Microsoft.ManagedIdentity/userAssignedIdentities/demo-control-plane"
    worker_identity_id        = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/identities/providers/Microsoft.ManagedIdentity/userAssignedIdentities/demo-workers"
    container_registry_ids    = ["/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/acr/providers/Microsoft.ContainerRegistry/registries/demo"]
  }

  override_data {
    target = data.azurerm_resources.existing_node_identity_listings
    values = {
      resources = [{
        id                  = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/identities/providers/Microsoft.ManagedIdentity/userAssignedIdentities/demo-workers"
        location            = "westeurope"
        name                = "demo-workers"
        resource_group_name = "identities"
        tags                = {}
        type                = "Microsoft.ManagedIdentity/userAssignedIdentities"
      }]
    }
  }

  assert {
    condition     = length(azurerm_user_assigned_identity.node_identities) == 0 && length(azurerm_role_assignment.node_role_assignments) == 0
    error_message = "Existing identities are used as they are: no identity and no role assignment is created."
  }
  assert {
    condition     = data.azurerm_user_assigned_identity.existing_node_identities["control-plane"].name == "demo-control-plane" && data.azurerm_user_assigned_identity.existing_node_identities["control-plane"].resource_group_name == "identities" && data.azurerm_user_assigned_identity.existing_node_identities["worker"].name == "demo-workers"
    error_message = "Existing identities are read by name and group from their IDs."
  }
  assert {
    condition     = output.exports.control_plane.identity_client_id == "3c0d5e3f-8a4b-4c9d-9e0f-3a4b5c6d7e8f" && output.exports.worker.identity_id == data.azurerm_user_assigned_identity.existing_node_identities["worker"].id
    error_message = "exports name the existing identities."
  }
}

run "container_registry_pull" {
  variables {
    container_registry_ids = ["/SUBSCRIPTIONS/6F1C1E1A-3B7E-4A3C-9A39-5D2F1C0B8E11/resourcegroups/acr/providers/microsoft.containerregistry/registries/demo"]
  }

  assert {
    condition = toset(keys(azurerm_role_assignment.node_role_assignments)) == toset([
      "control-plane/Contributor/resource-group",
      "control-plane/Network Contributor/subnet-control-plane",
      "control-plane/AcrPull//subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/acr/providers/Microsoft.ContainerRegistry/registries/demo",
      "worker/AcrPull//subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/acr/providers/Microsoft.ContainerRegistry/registries/demo",
    ])
    error_message = "Both identities get AcrPull on each registry, with the ID in canonical form."
  }
}

run "separate_worker_subnet" {
  variables {
    worker_subnet_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourcegroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/workers"
  }

  assert {
    condition     = output.exports.worker_subnet_id == "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/workers" && output.exports.cloud_provider_config.subnetName == "workers"
    error_message = "The worker subnet ID is canonical and is the cloud provider's default subnet."
  }
  assert {
    condition     = contains(keys(azurerm_role_assignment.node_role_assignments), "control-plane/Network Contributor/subnet-worker")
    error_message = "The control-plane identity gets Network Contributor on the worker subnet too."
  }
}

run "rejects_subnets_in_different_networks" {
  command = plan

  variables {
    worker_subnet_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/spoke/subnets/workers"
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

run "rejects_foreign_subscription" {
  command = plan

  variables {
    subnet_id = "/subscriptions/0b5e0f9c-2d4a-4e8b-a1c3-7d9e1f2a3b4c/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes"
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

run "rejects_unknown_zone" {
  command = plan

  variables {
    zones = ["4"]
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

run "rejects_rke2_supervisor_port_collision" {
  command = plan

  variables {
    distribution    = "rke2"
    cluster_network = { pods = [], services = [], service_domain = null, api_server_port = 9345 }
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

run "rejects_private_ip_with_public" {
  command = plan

  variables {
    api_load_balancer_public     = true
    api_allowed_cidrs            = ["198.51.100.0/24"]
    api_load_balancer_private_ip = "10.0.0.10"
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

run "rejects_missing_subnet" {
  command = plan

  variables {
    subnet_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/missing"
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

# The network deleted while the cluster exists: the next plan stops at the
# precondition. A destroy skips preconditions and never reads the network.
run "rejects_missing_virtual_network" {
  command = plan

  override_data {
    target = data.azurerm_resources.node_virtual_network_listing
    values = { resources = [] }
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

run "missing_virtual_network_skips_reads" {
  command = plan

  override_data {
    target = data.azurerm_resources.node_virtual_network_listing
    values = { resources = [] }
  }

  expect_failures = [azurerm_resource_group.cluster_resource_group]

  assert {
    condition     = length(data.azurerm_virtual_network.node_virtual_network) == 0 && length(data.azurerm_location.cluster_location) == 0
    error_message = "Without the network, nothing that would fail on a missing network is read."
  }
}

run "rejects_missing_identity" {
  command = plan

  variables {
    worker_identity_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/identities/providers/Microsoft.ManagedIdentity/userAssignedIdentities/demo-workers"
  }

  # The default listing finds only the network, so the identity is missing.
  expect_failures = [azurerm_resource_group.cluster_resource_group]
}

run "ssh_allowed_cidrs" {
  variables {
    ssh_allowed_cidrs = ["10.0.250.0/26"]
  }

  assert {
    condition     = azurerm_network_security_rule.node_security_rules["worker/allow-ssh-from-allowed-cidrs"].source_address_prefixes == toset(["10.0.250.0/26"]) && azurerm_network_security_rule.node_security_rules["control-plane/allow-ssh-from-allowed-cidrs"].priority < azurerm_network_security_rule.node_security_rules["control-plane/deny-ssh-inbound"].priority
    error_message = "ssh_allowed_cidrs opens SSH ahead of the deny."
  }
}


# The endpoint is fixed once the load balancer exists: every input that
# would move it fails the plan (api_endpoint_guard.tf). azurerm would apply
# these changes in place, out of reach of CAPTF's destructive-plan guard.
run "rejects_api_server_port_change" {
  command = plan

  variables {
    cluster_network = { pods = [], services = [], service_domain = null, api_server_port = 8443 }
  }

  expect_failures = [terraform_data.api_endpoint_guard]
}

run "rejects_subnet_change" {
  command = plan

  variables {
    subnet_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/workers"
  }

  expect_failures = [terraform_data.api_endpoint_guard]
}

run "rejects_api_load_balancer_private_ip_change" {
  command = plan

  variables {
    api_load_balancer_private_ip = "10.0.0.10"
  }

  expect_failures = [terraform_data.api_endpoint_guard]
}

run "rejects_api_load_balancer_public_change" {
  command = plan

  variables {
    api_load_balancer_public = true
    api_allowed_cidrs        = ["198.51.100.0/24"]
  }

  expect_failures = [terraform_data.api_endpoint_guard]
}

# Making the dynamic address static at the same value moves nothing.
run "accepts_current_private_ip_as_static" {
  command = plan

  variables {
    api_load_balancer_private_ip = "10.0.0.100"
  }

  assert {
    condition     = azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].private_ip_address_allocation == "Static"
    error_message = "The frontend keeps its address and becomes static."
  }
}

run "dotted_cluster_name" {
  command = plan

  variables {
    captf_cluster = { name = "demo.eu", namespace = "team-a" }
  }

  assert {
    condition     = azurerm_user_assigned_identity.node_identities["worker"].name == "captf-team-a-demo-eu-${substr(sha256("team-a/demo.eu"), 0, 8)}-worker"
    error_message = "Names hold only lowercase letters, digits and hyphens."
  }
}

run "invalid_ssh_allowed_cidrs" {
  command = plan

  variables {
    ssh_allowed_cidrs = ["bastion"]
  }

  expect_failures = [var.ssh_allowed_cidrs]
}

run "invalid_distribution" {
  command = plan

  variables {
    distribution = "k3s"
  }

  expect_failures = [var.distribution]
}

run "invalid_captf_contract" {
  command = plan

  variables {
    captf_contract = "v1alpha2"
  }

  expect_failures = [var.captf_contract]
}

run "invalid_additional_tags_reserved_key" {
  command = plan

  variables {
    additional_tags = { "CAPTF.io_cluster" = "other" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_additional_tags_characters" {
  command = plan

  variables {
    additional_tags = { "team/owner" = "a" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_additional_tags_count" {
  command = plan

  variables {
    additional_tags = { for i in range(45) : "tag${i}" => "v" }
  }

  expect_failures = [var.additional_tags]
}

run "invalid_admin_ssh_public_key" {
  command = plan

  variables {
    admin_ssh_public_key = null
  }

  expect_failures = [var.admin_ssh_public_key]
}

run "invalid_api_allowed_cidrs" {
  command = plan

  variables {
    api_allowed_cidrs = ["0.0.0.0"]
  }

  expect_failures = [var.api_allowed_cidrs]
}

run "invalid_api_load_balancer_private_ip" {
  command = plan

  variables {
    api_load_balancer_private_ip = "10.0.0.256"
  }

  expect_failures = [var.api_load_balancer_private_ip]
}

run "invalid_container_registry_ids" {
  command = plan

  variables {
    container_registry_ids = ["demo.azurecr.io"]
  }

  expect_failures = [var.container_registry_ids]
}

run "invalid_container_registry_ids_duplicate" {
  command = plan

  variables {
    container_registry_ids = [
      "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/acr/providers/Microsoft.ContainerRegistry/registries/demo",
      "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourcegroups/acr/providers/Microsoft.ContainerRegistry/registries/demo",
    ]
  }

  expect_failures = [var.container_registry_ids]
}

run "invalid_control_plane_identity_id" {
  command = plan

  variables {
    control_plane_identity_id = "cp-identity"
  }

  expect_failures = [var.control_plane_identity_id]
}

run "invalid_resource_group_name" {
  command = plan

  variables {
    resource_group_name = "Demo-Cluster"
  }

  expect_failures = [var.resource_group_name]
}

run "invalid_subnet_id" {
  command = plan

  variables {
    subnet_id = null
  }

  expect_failures = [var.subnet_id]
}

run "invalid_worker_identity_id" {
  command = plan

  variables {
    worker_identity_id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/identities"
  }

  expect_failures = [var.worker_identity_id]
}

run "invalid_worker_subnet_id" {
  command = plan

  variables {
    worker_subnet_id = "workers"
  }

  expect_failures = [var.worker_subnet_id]
}

run "invalid_zones" {
  command = plan

  variables {
    zones = ["1", "1"]
  }

  expect_failures = [var.zones]
}
