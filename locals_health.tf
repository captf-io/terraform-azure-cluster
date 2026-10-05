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

# Cluster health from the cluster's own resources, never from backend
# members (CONVENTIONS.md section 10): the API load balancer and its
# frontend address, or the resource group when the endpoint is the user's.
# A resource deleted out of band leaves the state on refresh, so its
# attributes read as null.
locals {
  # Presence of the endpoint resources -> contract health ("health" in
  # common.md). A primary resource that is gone is terminated
  # (CONVENTIONS.md section 10).
  health_by_state = {
    available = { state = "running", healthy = true, message = null, reason = null }
    missing   = { state = "terminated", healthy = false, message = "API load balancer ${local.api_load_balancer_name} or its frontend address not found", reason = "LoadBalancerNotFound" }
    user      = { state = "running", healthy = true, message = null, reason = null }
    gone      = { state = "terminated", healthy = false, message = "resource group ${local.resource_group_name} not found", reason = "ResourceGroupNotFound" }
  }
  health_key = (
    one(azurerm_resource_group.cluster_resource_group[*].id) == null ? "gone" :
    local.user_endpoint ? "user" :
    local.api_endpoint != null && one(azurerm_lb.api_load_balancer[*].id) != null ? "available" : "missing"
  )
  health_reading = {
    state   = local.health_by_state[local.health_key].state
    healthy = local.health_by_state[local.health_key].healthy
    message = local.health_by_state[local.health_key].message
    reasons = local.health_by_state[local.health_key].reason == null ? [] : [local.health_by_state[local.health_key].reason]
  }
}
