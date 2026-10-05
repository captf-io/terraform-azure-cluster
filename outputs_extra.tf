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

# Non-contract outputs, alphabetical. The controller never reads them; they
# help when inspecting a cluster's state.

output "api_load_balancer_id" {
  description = "ARM ID of the API load balancer; null with a user endpoint."
  value       = one(azurerm_lb.api_load_balancer[*].id)
}

output "resource_group_id" {
  description = "ARM ID of the cluster's resource group."
  value       = one(azurerm_resource_group.cluster_resource_group[*].id)
}
