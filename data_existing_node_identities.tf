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

# Existing node identities (control_plane_identity_id, worker_identity_id):
# read for their client ID, which the cloud provider config names
# (DESIGN.md decision 4), and only when the listing found them.
data "azurerm_user_assigned_identity" "existing_node_identities" {
  for_each = local.found_identity_parts

  name                = each.value[2]
  resource_group_name = each.value[1]
}
