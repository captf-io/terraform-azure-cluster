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

# The bring-your-own network and the region's zones (DESIGN.md "Scope").
# ARM IDs are case-insensitive, so subnet IDs are parsed that way and
# rebuilt with Azure's canonical segment names.
locals {
  node_roles = ["control-plane", "worker"]

  subnet_id_pattern = "(?i)^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.Network/virtualNetworks/([^/]+)/subnets/([^/]+)$"
  # try(): a missing subnet_id already fails its validation; this keeps the
  # rest of the plan from adding a second, less useful error.
  node_subnet_parts = {
    for role, id in {
      "control-plane" = var.subnet_id
      worker          = var.worker_subnet_id != null ? var.worker_subnet_id : var.subnet_id
    } :
    role => try(regex(local.subnet_id_pattern, id), ["", "", "", ""])
  }
  node_subnets = {
    for role, p in local.node_subnet_parts : role => {
      id                         = "/subscriptions/${lower(p[0])}/resourceGroups/${p[1]}/providers/Microsoft.Network/virtualNetworks/${p[2]}/subnets/${p[3]}"
      name                       = p[3]
      subscription_id            = lower(p[0])
      virtual_network_name       = p[2]
      virtual_network_group_name = p[1]
      # Compares networks case-insensitively, as ARM does.
      virtual_network_key = lower(join("/", slice(p, 0, 3)))
    }
  }

  # The brought network as the subscription-wide listing found it, in the
  # subnets' resource group; empty when it is gone.
  node_virtual_networks = [
    for r in data.azurerm_resources.node_virtual_network_listing.resources : r
    if lower(r.resource_group_name) == lower(local.node_subnets["control-plane"].virtual_network_group_name)
  ]
  virtual_network_subnets = [for n in try(data.azurerm_virtual_network.node_virtual_network[0].subnets, []) : lower(n)]

  # The cluster lives in the virtual network's region: NICs cannot use a
  # subnet in another region. Null when the network is gone, which the
  # precondition on the resource group reports.
  location = try(local.node_virtual_networks[0].location, null)

  # Logical zones the subscription sees in the region; empty without zones.
  region_zones = sort(distinct([for m in try(data.azurerm_location.cluster_location[0].zone_mappings, []) : m.logical_zone]))
  zones        = length(var.zones) > 0 ? sort(var.zones) : local.region_zones
  zonal        = length(local.zones) > 0
}
