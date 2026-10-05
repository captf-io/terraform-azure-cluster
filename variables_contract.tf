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

# Contract inputs of the cluster role, v1alpha1, in contract order and with
# the contract's types
# (https://captf.io/docs/module-author/contract/v1alpha1/cluster.html#inputs).

# Read only by its own validation.
# tflint-ignore: terraform_unused_declarations
variable "captf_contract" {
  description = "Contract version the controller generated the root module for (common.md \"Inputs\")."
  type        = string

  validation {
    condition     = var.captf_contract == "v1alpha1"
    error_message = "captf_contract must be \"v1alpha1\": this module implements contract v1alpha1 only."
  }
}

variable "captf_cluster" {
  description = "The owning CAPI Cluster: name and namespace (common.md \"Inputs\")."
  type = object({
    name      = string
    namespace = string
  })
}

# Names come from the Cluster; the TerraformCluster is in captf_tags.
# tflint-ignore: terraform_unused_declarations
variable "captf_object" {
  description = "The TerraformCluster being reconciled (common.md \"Inputs\")."
  type = object({
    kind      = string
    name      = string
    namespace = string
  })
}

# The controller never passes this to the cluster role; the default keeps
# `validate` happy (common.md "captf_cluster_outputs").
# tflint-ignore: terraform_unused_declarations
variable "captf_cluster_outputs" {
  description = "Not passed to the cluster role; declared with a null default as the contract skeleton does."
  type        = any
  default     = null
}

variable "captf_tags" {
  description = "Tags the controller sets on every object (common.md \"captf_tags\"); applied to every taggable resource through local.tags."
  type        = map(string)
}

variable "control_plane_endpoint" {
  description = "An endpoint the module does not own (cluster.md \"control_plane_endpoint (input)\"). Non-null: no API load balancer is created."
  type = object({
    host = string
    port = number
  })
  default = null
}

# Version-dependent cluster resources do not exist on Azure IaaS.
# tflint-ignore: terraform_unused_declarations
variable "kubernetes_version" {
  description = "Cluster.spec.topology.version, or null without ClusterClass (cluster.md \"kubernetes_version (input)\"). Unused."
  type        = string
  default     = null
}

# Nothing here needs a live workload API server.
# tflint-ignore: terraform_unused_declarations
variable "control_plane_initialized" {
  description = "Cluster.status.initialization.controlPlaneInitialized, latched (cluster.md \"control_plane_initialized (input)\"). Unused."
  type        = bool
}

variable "cluster_network" {
  description = "Cluster.spec.clusterNetwork (cluster.md \"cluster_network (input)\"). api_server_port sets the load balancer and network security group port (default 6443)."
  type = object({
    pods            = list(string)
    services        = list(string)
    service_domain  = string
    api_server_port = number
  })
  default = null
}
