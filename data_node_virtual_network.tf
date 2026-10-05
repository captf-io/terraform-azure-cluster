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

# The brought virtual network's subnets, read only when the listing found
# it (data_node_virtual_network_listing.tf). The precondition on the
# resource group requires both subnets.
data "azurerm_virtual_network" "node_virtual_network" {
  count = length(local.node_virtual_networks) > 0 ? 1 : 0

  name                = local.node_subnets["control-plane"].virtual_network_name
  resource_group_name = local.node_subnets["control-plane"].virtual_network_group_name
}
