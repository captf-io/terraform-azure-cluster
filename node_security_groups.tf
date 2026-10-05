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

# Network security groups of the nodes, one per role, attached to each
# node's NIC rather than to the brought subnet. No inline rules: the cloud
# controller manager adds Service rules to the worker group (DESIGN.md
# decision 3).
resource "azurerm_network_security_group" "node_security_groups" {
  for_each = toset(local.node_roles)

  location            = azurerm_resource_group.cluster_resource_group[0].location
  name                = local.node_security_group_names[each.key]
  resource_group_name = azurerm_resource_group.cluster_resource_group[0].name
  tags                = local.tags
}
