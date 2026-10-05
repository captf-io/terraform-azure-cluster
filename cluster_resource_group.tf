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

# The cluster's own resource group: least-privilege scope for the node
# identities, home of what the cloud controller manager creates, and the
# attribution boundary for resources Azure cannot tag (DESIGN.md decision 1).
resource "azurerm_resource_group" "cluster_resource_group" {
  # Always one. Counted because a single resource that vanished out of band
  # reads as unknown in a refresh-only run, while a counted one reads as an
  # empty tuple, which the outputs turn into null and a degraded health.
  count = 1

  location = local.location
  name     = local.resource_group_name
  tags     = local.tags

  lifecycle {
    # Checks that span variables (CONVENTIONS.md section 4). Terraform skips
    # them when it plans a destroy, so a network or identity deleted first
    # never blocks one.
    precondition {
      condition     = length(local.node_virtual_networks) > 0
      error_message = "The virtual network ${local.node_subnets["control-plane"].virtual_network_name} of subnet_id was not found in resource group ${local.node_subnets["control-plane"].virtual_network_group_name}."
    }
    precondition {
      condition     = length(local.node_virtual_networks) == 0 || alltrue([for s in values(local.node_subnets) : contains(local.virtual_network_subnets, lower(s.name))])
      error_message = "The virtual network ${local.node_subnets["control-plane"].virtual_network_name} has no subnet named ${join(" or ", distinct([for s in values(local.node_subnets) : s.name]))}: check subnet_id and worker_subnet_id."
    }
    precondition {
      condition     = length(local.missing_identity_roles) == 0
      error_message = "The existing identity of ${join(" and ", local.missing_identity_roles)} was not found: check control_plane_identity_id and worker_identity_id."
    }
    precondition {
      condition     = !local.rke2 || local.user_endpoint || local.api_port != local.rke2_supervisor_port
      error_message = "cluster_network.api_server_port cannot be 9345 with distribution rke2: the RKE2 supervisor listens on 9345 on the same endpoint."
    }
    precondition {
      condition     = !var.api_load_balancer_public || local.user_endpoint || length(var.api_allowed_cidrs) > 0
      error_message = "api_load_balancer_public needs api_allowed_cidrs: list the CIDRs that may reach the public API endpoint, including the management cluster's egress and the nodes' NAT gateway addresses."
    }
    precondition {
      condition     = !(var.api_load_balancer_public && var.api_load_balancer_private_ip != null)
      error_message = "api_load_balancer_private_ip applies to the internal load balancer only: unset it, or unset api_load_balancer_public."
    }
    precondition {
      condition     = local.node_subnets["control-plane"].virtual_network_key == local.node_subnets.worker.virtual_network_key
      error_message = "subnet_id and worker_subnet_id must be subnets of the same virtual network."
    }
    precondition {
      condition     = local.node_subnets["control-plane"].subscription_id == lower(data.azurerm_client_config.runner_client.subscription_id)
      error_message = "subnet_id is in subscription ${local.node_subnets["control-plane"].subscription_id}, but the identity works in ${data.azurerm_client_config.runner_client.subscription_id}: set ARM_SUBSCRIPTION_ID in the identity Secret to the network's subscription."
    }
    precondition {
      condition     = alltrue([for z in var.zones : contains(local.region_zones, z)])
      error_message = "zones lists ${join(", ", var.zones)}, but region ${local.location != null ? local.location : "(unknown)"} offers ${length(local.region_zones) > 0 ? join(", ", local.region_zones) : "no availability zones"}."
    }
  }
}
