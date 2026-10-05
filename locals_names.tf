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

# Names of every Azure resource, derived from the Cluster's namespace and
# name with a hash that keeps truncated names unique (CONVENTIONS.md
# section 6; https://learn.microsoft.com/azure/azure-resource-manager/management/resource-name-rules).
locals {
  cluster_key  = "${var.captf_cluster.namespace}/${var.captf_cluster.name}"
  cluster_hash = substr(sha256(local.cluster_key), 0, 8)
  # Load balancers, network security groups and availability sets allow 80
  # characters; 60 leaves room for the suffixes below. 60 - 9 leaves room
  # for "-" and the hash.
  name_max = 60
  # Lowercase [a-z0-9-] (CONVENTIONS.md section 6): identity names, for one,
  # allow no dots.
  name_prefix = "${trimsuffix(substr(replace(lower("captf-${var.captf_cluster.namespace}-${var.captf_cluster.name}"), "/[^a-z0-9-]/", "-"), 0, local.name_max - 9), "-")}-${local.cluster_hash}"

  # Lowercase either way: cloud-provider-azure lowercases the group in every
  # provider ID it writes (DESIGN.md decision 5).
  resource_group_name = var.resource_group_name != null ? var.resource_group_name : local.name_prefix

  # Every name below lives in the cluster's own resource group, so it only
  # has to be unique there; the prefix still tells clusters apart in
  # subscription-wide views.
  api_load_balancer_name              = "${local.name_prefix}-api"
  api_public_ip_name                  = "${local.name_prefix}-api"
  api_frontend_name                   = "api"
  api_backend_pool_name               = "control-plane"
  control_plane_availability_set_name = "${local.name_prefix}-control-plane"
  node_identity_names                 = { for role in local.node_roles : role => "${local.name_prefix}-${role}" }
  node_security_group_names           = { for role in local.node_roles : role => "${local.name_prefix}-${role}-nsg" }
  node_application_security_group_names = {
    for role in local.node_roles : role => "${local.name_prefix}-${role}-asg"
  }
}
