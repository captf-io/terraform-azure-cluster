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

# Finds the brought virtual network subscription-wide, by name and type: an
# empty list when it is gone, where a read by resource group fails with
# ResourceGroupNotFound and data.azurerm_virtual_network with NotFound. A
# destroy must not fail because the network went first. The listing also
# gives the region (locals_network.tf).
data "azurerm_resources" "node_virtual_network_listing" {
  name = local.node_subnets["control-plane"].virtual_network_name
  type = "Microsoft.Network/virtualNetworks"
}
