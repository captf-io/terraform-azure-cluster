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

# Contract outputs of the cluster role, v1alpha1, in contract order
# (https://captf.io/docs/module-author/contract/v1alpha1/cluster.html#outputs
# and common.html#outputs).

output "control_plane_endpoint" {
  description = "The API endpoint: the user's, or the load balancer frontend on the API server port (cluster.md \"control_plane_endpoint (output)\")."
  value       = local.api_endpoint
}

output "failure_domains" {
  description = "One failure domain per availability zone, all eligible for the control plane; empty in a region without zones (cluster.md \"failure_domains (output)\")."
  value       = [for z in local.zones : { name = z, control_plane = true, attributes = {} }]
}

output "exports" {
  description = "Values machine and pool modules need, schema captf.io/azure-cluster/v1 (cluster.md \"exports (output)\"; README \"Exports\")."
  value       = local.exports
}

output "health" {
  description = "Health of the API load balancer, or of the resource group with a user endpoint (common.md \"Outputs\")."
  value       = local.health_reading
}
