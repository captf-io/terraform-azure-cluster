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

# Application security groups that name the control-plane and worker NICs
# in the network security rules, whatever their addresses
# (https://learn.microsoft.com/azure/virtual-network/application-security-groups).
resource "azurerm_application_security_group" "node_application_security_groups" {
  for_each = toset(local.node_roles)

  location            = azurerm_resource_group.cluster_resource_group[0].location
  name                = local.node_application_security_group_names[each.key]
  resource_group_name = azurerm_resource_group.cluster_resource_group[0].name
  tags                = local.tags
}
