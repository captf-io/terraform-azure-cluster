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

# Public frontend address of the API load balancer (api_load_balancer_public).
# Standard SKU and static: the endpoint must never change once CAPI copied
# it (cluster.md "control_plane_endpoint (output)").
resource "azurerm_public_ip" "api_public_ip" {
  count = !local.user_endpoint && var.api_load_balancer_public ? 1 : 0

  allocation_method   = "Static"
  ip_version          = "IPv4"
  location            = azurerm_resource_group.cluster_resource_group[0].location
  name                = local.api_public_ip_name
  resource_group_name = azurerm_resource_group.cluster_resource_group[0].name
  sku                 = "Standard"
  sku_tier            = "Regional"
  tags                = local.tags
  # Zone-redundant where the region has zones.
  zones = length(local.region_zones) > 0 ? local.region_zones : null

  lifecycle {
    # zones forces replacement and is not computed: should Azure ever report
    # zones differently from what was sent, a plan would replace the address
    # and lose the endpoint (DESIGN.md decision 2).
    ignore_changes = [zones]
  }
}
