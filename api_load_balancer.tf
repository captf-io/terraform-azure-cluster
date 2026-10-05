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

# The control-plane endpoint: a Standard load balancer, internal by default,
# in front of the control-plane NICs; api_endpoint_guard.tf keeps its
# endpoint from moving (DESIGN.md decision 2;
# https://captf.io/docs/module-author/contract/v1alpha1/cluster.html#control_plane_endpoint-output).
resource "azurerm_lb" "api_load_balancer" {
  count = local.user_endpoint ? 0 : 1

  location            = azurerm_resource_group.cluster_resource_group[0].location
  name                = local.api_load_balancer_name
  resource_group_name = azurerm_resource_group.cluster_resource_group[0].name
  sku                 = "Standard"
  sku_tier            = "Regional"
  tags                = local.tags

  frontend_ip_configuration {
    name                          = local.api_frontend_name
    private_ip_address            = var.api_load_balancer_public ? null : var.api_load_balancer_private_ip
    private_ip_address_allocation = var.api_load_balancer_public ? null : (var.api_load_balancer_private_ip != null ? "Static" : "Dynamic")
    public_ip_address_id          = var.api_load_balancer_public ? one(azurerm_public_ip.api_public_ip[*].id) : null
    subnet_id                     = var.api_load_balancer_public ? null : local.node_subnets["control-plane"].id
    # Zone-redundant internal frontend where the region has zones.
    zones = !var.api_load_balancer_public && length(local.region_zones) > 0 ? local.region_zones : null
  }

  lifecycle {
    # A frontend zones change replaces the whole load balancer in azurerm
    # 5.7.0 (lb_resource.go CustomizeDiff), and with it a dynamic endpoint
    # address; zones only matter at creation.
    ignore_changes = [frontend_ip_configuration[0].zones]
  }
}
