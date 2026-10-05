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

# Finds each existing node identity subscription-wide, by name and type: an
# empty list when it is gone, where data.azurerm_user_assigned_identity fails
# with NotFound and would block a destroy.
data "azurerm_resources" "existing_node_identity_listings" {
  for_each = local.existing_identity_parts

  name = each.value[2]
  type = "Microsoft.ManagedIdentity/userAssignedIdentities"
}
