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

# Role assignments of the node identities this module creates
# (locals_identities.tf; https://learn.microsoft.com/azure/role-based-access-control/built-in-roles).
resource "azurerm_role_assignment" "node_role_assignments" {
  for_each = local.node_role_assignments

  # A new identity takes a while to replicate in Entra ID; the principal type
  # and the skipped check let the assignment succeed meanwhile
  # (https://learn.microsoft.com/azure/role-based-access-control/troubleshooting#symptom---assigning-a-role-to-a-new-principal-sometimes-fails).
  principal_id                     = local.node_identities[each.value.role].principal_id
  principal_type                   = "ServicePrincipal"
  role_definition_name             = each.value.role_definition_name
  scope                            = each.value.scope
  skip_service_principal_aad_check = true
}
