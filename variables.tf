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

# User variables of the cluster role, alphabetical. Set them through
# TerraformCluster spec.variables or spec.variablesFrom
# (https://captf.io/docs/user-guide/variables.html).

variable "additional_tags" {
  description = "Extra Azure tags on every taggable resource. The captf.io_* tags always win: keys that collide with them are rejected."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    # Azure tag names are case-insensitive, so the check is too.
    condition     = alltrue([for k in keys(var.additional_tags) : !can(regex("(?i)^captf\\.io[_/]", k))])
    error_message = "additional_tags must not use keys starting with captf.io_ or captf.io/: they are reserved for the captf_tags the controller sets."
  }
  validation {
    # https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources#limitations
    condition     = alltrue([for k, v in var.additional_tags : length(k) >= 1 && length(k) <= 512 && length(v) <= 256 && !can(regex("[<>%&\\\\?/]", k))])
    error_message = "additional_tags keys must be 1-512 characters without < > % & \\ ? /, and values at most 256 characters (Azure tag limits)."
  }
  validation {
    # Azure allows 50 tags per resource; the six captf tags take six.
    condition     = length(var.additional_tags) <= 44
    error_message = "additional_tags may hold at most 44 tags: Azure allows 50 per resource and the captf tags use 6."
  }
}

variable "admin_ssh_public_key" {
  description = "OpenSSH public key (ssh-rsa or ssh-ed25519) for the admin user of every node. Required: Azure Linux VMs need a key or a password, and the module invents neither. SSH stays closed unless ssh_allowed_cidrs opens it."
  type        = string
  default     = null

  validation {
    condition     = var.admin_ssh_public_key != null && can(regex("^(ssh-rsa|ssh-ed25519) AAAA[0-9A-Za-z+/]+={0,3}( [^\\r\\n]*)?$", var.admin_ssh_public_key))
    error_message = "admin_ssh_public_key must be set (spec.variables.admin_ssh_public_key) to one OpenSSH public key line, \"ssh-rsa AAAA...\" or \"ssh-ed25519 AAAA...\"."
  }
}

variable "api_allowed_cidrs" {
  description = "IPv4 CIDRs, besides the virtual network, allowed to reach the API server port. Required with api_load_balancer_public: it must include the management cluster's egress and the nodes' NAT gateway addresses."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for c in var.api_allowed_cidrs : can(cidrnetmask(c))])
    error_message = "api_allowed_cidrs must hold IPv4 CIDRs such as 203.0.113.0/24."
  }
}

variable "api_load_balancer_private_ip" {
  description = "Static private IPv4 address of the internal API load balancer frontend, in the control-plane subnet. Null takes a dynamic address, which is stable for the load balancer's life."
  type        = string
  default     = null

  validation {
    condition     = var.api_load_balancer_private_ip == null || can(regex("^((25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1?[0-9]?[0-9])$", var.api_load_balancer_private_ip))
    error_message = "api_load_balancer_private_ip must be an IPv4 address such as 10.0.0.10, or null."
  }
}

variable "api_load_balancer_public" {
  description = "Put the API load balancer on a public IP. Off by default: the endpoint stays inside the virtual network. Needs api_allowed_cidrs."
  type        = bool
  default     = false
  nullable    = false
}

variable "api_server_hairpin_workaround" {
  description = "Have control-plane nodes send their own API traffic for the load balancer frontend to their local API server while it is ready, because an Azure internal load balancer drops a backend's flow to its own frontend (DESIGN.md decision 2). Applies to cloud-config bootstrap data."
  type        = bool
  default     = true
  nullable    = false
}

variable "container_registry_ids" {
  description = "Azure Container Registry IDs the node identities this module creates may pull from (AcrPull)."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for id in var.container_registry_ids : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ContainerRegistry/registries/[^/]+$", id))])
    error_message = "container_registry_ids must hold registry IDs: /subscriptions/<id>/resourceGroups/<group>/providers/Microsoft.ContainerRegistry/registries/<name>."
  }
  validation {
    # Each ID keys a role assignment; ARM IDs are case-insensitive.
    condition     = length(distinct([for id in var.container_registry_ids : lower(id)])) == length(var.container_registry_ids)
    error_message = "container_registry_ids must not list a registry twice (IDs compare case-insensitively)."
  }
}

variable "control_plane_identity_id" {
  description = "Existing user-assigned managed identity for control-plane nodes. Null creates one with Contributor on the cluster resource group and Network Contributor on the node subnets; an existing one needs the same grants."
  type        = string
  default     = null

  validation {
    condition     = var.control_plane_identity_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ManagedIdentity/userAssignedIdentities/[^/]+$", var.control_plane_identity_id))
    error_message = "control_plane_identity_id must be a user-assigned identity ID (/subscriptions/<id>/resourceGroups/<group>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<name>), or null."
  }
}

variable "distribution" {
  description = "Kubernetes distribution of the control plane: kubeadm, or rke2, which adds the supervisor port 9345 to the load balancer and the control-plane security group, probes the API server with TCP, and fixes the API server's backend port at 6443."
  type        = string
  default     = "kubeadm"
  nullable    = false

  validation {
    condition     = contains(["kubeadm", "rke2"], var.distribution)
    error_message = "distribution must be kubeadm or rke2."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group the module creates for the cluster. Null derives captf-<namespace>-<cluster>-<hash>. Lowercase, because the cloud controller manager lowercases it in provider IDs."
  type        = string
  default     = null

  validation {
    condition     = var.resource_group_name == null || can(regex("^[a-z0-9._()-]{0,89}[a-z0-9_()-]$", var.resource_group_name))
    error_message = "resource_group_name must be 1-90 lowercase letters, digits, . _ - ( ) and must not end with a period."
  }
}

variable "ssh_allowed_cidrs" {
  description = "IPv4 CIDRs allowed to reach SSH (port 22) on every node, for example an Azure Bastion subnet. Empty by default: SSH is denied, from other nodes too."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for c in var.ssh_allowed_cidrs : can(cidrnetmask(c))])
    error_message = "ssh_allowed_cidrs must hold IPv4 CIDRs such as 10.0.250.0/26."
  }
}

variable "subnet_id" {
  description = "Existing subnet for control-plane nodes and the internal API frontend, and for workers unless worker_subnet_id is set. Required: the network is brought by you, egress (NAT gateway or firewall) included."
  type        = string
  default     = null

  validation {
    condition     = var.subnet_id != null && can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.subnet_id))
    error_message = "subnet_id must be set (spec.variables.subnet_id) to a subnet ID: /subscriptions/<id>/resourceGroups/<group>/providers/Microsoft.Network/virtualNetworks/<network>/subnets/<subnet>."
  }
}

variable "worker_identity_id" {
  description = "Existing user-assigned managed identity for worker nodes. Null creates one without role assignments beyond AcrPull on container_registry_ids."
  type        = string
  default     = null

  validation {
    condition     = var.worker_identity_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.ManagedIdentity/userAssignedIdentities/[^/]+$", var.worker_identity_id))
    error_message = "worker_identity_id must be a user-assigned identity ID (/subscriptions/<id>/resourceGroups/<group>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<name>), or null."
  }
}

variable "worker_subnet_id" {
  description = "Existing subnet for worker nodes, in the same virtual network as subnet_id. Null uses subnet_id."
  type        = string
  default     = null

  validation {
    condition     = var.worker_subnet_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.worker_subnet_id))
    error_message = "worker_subnet_id must be a subnet ID (/subscriptions/<id>/resourceGroups/<group>/providers/Microsoft.Network/virtualNetworks/<network>/subnets/<subnet>), or null."
  }
}

variable "zones" {
  description = "Availability zones to publish as failure domains. Empty uses every zone the region offers; a region without zones has no failure domains and puts control-plane machines in an availability set."
  type        = list(string)
  default     = []
  nullable    = false

  validation {
    condition     = alltrue([for z in var.zones : can(regex("^[1-9][0-9]*$", z))]) && length(distinct(var.zones)) == length(var.zones)
    error_message = "zones must hold distinct logical zone numbers such as \"1\", \"2\", \"3\"."
  }
}
