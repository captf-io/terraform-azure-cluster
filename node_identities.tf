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

# User-assigned managed identities of the nodes, one per role, unless an
# existing one is given. The cloud controller manager and the Azure Disk CSI
# driver authenticate as them (DESIGN.md decision 4).
resource "azurerm_user_assigned_identity" "node_identities" {
  for_each = local.created_identity_roles

  location            = azurerm_resource_group.cluster_resource_group[0].location
  name                = local.node_identity_names[each.key]
  resource_group_name = azurerm_resource_group.cluster_resource_group[0].name
  tags                = local.tags
}
