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

# Node identities: user-assigned managed identities the module creates, or
# existing ones, and the role assignments for the ones it creates
# (DESIGN.md decision 4).
locals {
  identity_id_pattern = "(?i)^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.ManagedIdentity/userAssignedIdentities/([^/]+)$"
  existing_identity_ids = {
    for role, id in { "control-plane" = var.control_plane_identity_id, worker = var.worker_identity_id } : role => id if id != null
  }
  existing_identity_parts = {
    for role, id in local.existing_identity_ids : role => try(regex(local.identity_id_pattern, id), ["", "", ""])
  }
  # The existing identities the listings found in their resource groups.
  found_identity_parts = {
    for role, p in local.existing_identity_parts : role => p
    if length([for r in data.azurerm_resources.existing_node_identity_listings[role].resources : r if lower(r.resource_group_name) == lower(p[1])]) > 0
  }
  missing_identity_roles = sort([for role in keys(local.existing_identity_parts) : role if !contains(keys(local.found_identity_parts), role)])
  created_identity_roles = toset([for role in local.node_roles : role if !contains(keys(local.existing_identity_ids), role)])

  # id, client_id and principal_id per role, wherever the identity comes from.
  node_identities = merge(
    {
      for role, i in azurerm_user_assigned_identity.node_identities : role => {
        id           = i.id
        client_id    = i.client_id
        principal_id = i.principal_id
      }
    },
    {
      for role, i in data.azurerm_user_assigned_identity.existing_node_identities : role => {
        id           = i.id
        client_id    = i.client_id
        principal_id = i.principal_id
      }
    },
  )

  # Role assignment scopes are compared case-sensitively by the provider, so
  # registry IDs are rebuilt with Azure's canonical segment names.
  container_registry_ids = [
    for p in [
      for id in var.container_registry_ids :
      try(regex("(?i)^/subscriptions/([^/]+)/resourceGroups/([^/]+)/providers/Microsoft\\.ContainerRegistry/registries/([^/]+)$", id), ["", "", ""])
    ] :
    "/subscriptions/${lower(p[0])}/resourceGroups/${p[1]}/providers/Microsoft.ContainerRegistry/registries/${p[2]}"
  ]

  # Keys are known at plan time (they come from variables); values may not be.
  # The control plane runs the cloud controller manager and the Azure Disk
  # CSI controller: Contributor on the cluster's own resource group, and
  # Network Contributor on the brought subnets for internal Service load
  # balancers. Workers get nothing by default.
  node_role_assignments = merge(
    {
      for k, a in {
        "control-plane/Contributor/resource-group" = {
          role                 = "control-plane"
          role_definition_name = "Contributor"
          scope                = azurerm_resource_group.cluster_resource_group[0].id
        }
      } : k => a if contains(local.created_identity_roles, "control-plane")
    },
    {
      for role, s in local.node_subnets : "control-plane/Network Contributor/subnet-${role}" => {
        role                 = "control-plane"
        role_definition_name = "Network Contributor"
        scope                = s.id
      }
      # One assignment when both roles share a subnet.
      if contains(local.created_identity_roles, "control-plane") && (role == "control-plane" || lower(s.id) != lower(local.node_subnets["control-plane"].id))
    },
    {
      for pair in setproduct(sort(local.created_identity_roles), local.container_registry_ids) : "${pair[0]}/AcrPull/${pair[1]}" => {
        role                 = pair[0]
        role_definition_name = "AcrPull"
        scope                = pair[1]
      }
    },
  )
}
