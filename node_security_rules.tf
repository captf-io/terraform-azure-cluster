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

# Inbound rules of the node network security groups (locals_security_rules.tf).
# Separate rule resources leave room for the rules the cloud controller
# manager adds.
resource "azurerm_network_security_rule" "node_security_rules" {
  for_each = local.node_security_rules

  access                                = each.value.access
  description                           = each.value.description
  destination_address_prefix            = "*"
  destination_port_range                = each.value.destination_port_range
  destination_port_ranges               = each.value.destination_port_ranges
  direction                             = "Inbound"
  name                                  = each.value.name
  network_security_group_name           = azurerm_network_security_group.node_security_groups[each.value.role].name
  priority                              = each.value.priority
  protocol                              = each.value.protocol
  resource_group_name                   = azurerm_resource_group.cluster_resource_group[0].name
  source_address_prefix                 = each.value.source_address_prefix
  source_address_prefixes               = each.value.source_address_prefixes
  source_application_security_group_ids = each.value.source_application_security_group_ids
  source_port_range                     = "*"
}
