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

# Spreads control-plane machines over fault domains in a region without
# availability zones, where there are no failure domains to spread them
# over (DESIGN.md decision 6).
resource "azurerm_availability_set" "control_plane_availability_set" {
  count = local.zonal ? 0 : 1

  location = azurerm_resource_group.cluster_resource_group[0].location
  managed  = true
  name     = local.control_plane_availability_set_name
  # Every region supports two fault domains; some support three.
  platform_fault_domain_count  = 2
  platform_update_domain_count = 5
  resource_group_name          = azurerm_resource_group.cluster_resource_group[0].name
  tags                         = local.tags
}
