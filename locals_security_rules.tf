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

# Inbound rules of the node network security groups (DESIGN.md decision 3).
# SSH is denied on every node, before anything else, unless it comes from
# ssh_allowed_cidrs. Nodes talk freely to each other (identified by
# application security groups). Control-plane nodes take the API server ports from the virtual
# network and the allowed CIDRs, and nothing else from the virtual network.
# Workers keep Azure's default AllowVnetInBound, apart from the kubelet ports:
# cloud-provider-azure adds no rule for an internal Service load balancer and
# relies on it (pkg/provider/loadbalancer/accesscontrol.go). Priorities stay
# below 500, where the cloud controller manager's Service rules start.
locals {
  api_server_ports = concat([local.api_backend_port], local.rke2 ? [local.rke2_supervisor_port] : [])

  # Every rule has every attribute, so the map holds one object type.
  node_security_rules = merge(
    {
      for k, r in {
        for role in local.node_roles : "${role}/allow-ssh-from-allowed-cidrs" => {
          role                                  = role
          name                                  = "allow-ssh-from-allowed-cidrs"
          description                           = "SSH from ssh_allowed_cidrs."
          priority                              = 100
          access                                = "Allow"
          protocol                              = "Tcp"
          destination_port_range                = "22"
          destination_port_ranges               = null
          source_address_prefix                 = null
          source_address_prefixes               = var.ssh_allowed_cidrs
          source_application_security_group_ids = null
        }
      } : k => r if length(var.ssh_allowed_cidrs) > 0
    },
    {
      # Azure's default AllowVnetInBound would otherwise admit SSH from the
      # whole network, peerings and VPNs included; secure default: no SSH.
      for role in local.node_roles : "${role}/deny-ssh-inbound" => {
        role                                  = role
        name                                  = "deny-ssh-inbound"
        description                           = "SSH from anywhere else, other nodes included."
        priority                              = 110
        access                                = "Deny"
        protocol                              = "Tcp"
        destination_port_range                = "22"
        destination_port_ranges               = null
        source_address_prefix                 = "*"
        source_address_prefixes               = null
        source_application_security_group_ids = null
      }
    },
    {
      for role in local.node_roles : "${role}/allow-cluster-inbound" => {
        role                                  = role
        name                                  = "allow-cluster-inbound"
        description                           = "Any traffic between the cluster's nodes (CNI, kubelet, etcd)."
        priority                              = 120
        access                                = "Allow"
        protocol                              = "*"
        destination_port_range                = "*"
        destination_port_ranges               = null
        source_address_prefix                 = null
        source_address_prefixes               = null
        source_application_security_group_ids = [for r in local.node_roles : azurerm_application_security_group.node_application_security_groups[r].id]
      }
    },
    {
      # Workers reach the API server directly (the kubernetes Service), and
      # an internal load balancer keeps the client's source address.
      "control-plane/allow-api-server-from-virtual-network" = {
        role                                  = "control-plane"
        name                                  = "allow-api-server-from-virtual-network"
        description                           = "API server ports from the virtual network and networks peered or connected to it."
        priority                              = 130
        access                                = "Allow"
        protocol                              = "Tcp"
        destination_port_range                = null
        destination_port_ranges               = [for p in local.api_server_ports : tostring(p)]
        source_address_prefix                 = "VirtualNetwork"
        source_address_prefixes               = null
        source_application_security_group_ids = null
      }
    },
    {
      for k, r in {
        "control-plane/allow-api-server-from-allowed-cidrs" = {
          role                                  = "control-plane"
          name                                  = "allow-api-server-from-allowed-cidrs"
          description                           = "API server ports from api_allowed_cidrs."
          priority                              = 140
          access                                = "Allow"
          protocol                              = "Tcp"
          destination_port_range                = null
          destination_port_ranges               = [for p in local.api_server_ports : tostring(p)]
          source_address_prefix                 = null
          source_address_prefixes               = var.api_allowed_cidrs
          source_application_security_group_ids = null
        }
      } : k => r if length(var.api_allowed_cidrs) > 0
    },
    {
      # The kubelet API runs commands in containers and serves logs; only the
      # nodes (allow-cluster-inbound, above) have a reason to reach it. The
      # rest of the virtual network stays open on workers, see the header.
      "worker/deny-kubelet-from-virtual-network" = {
        role                                  = "worker"
        name                                  = "deny-kubelet-from-virtual-network"
        description                           = "Kubelet ports from the rest of the virtual network."
        priority                              = 150
        access                                = "Deny"
        protocol                              = "Tcp"
        destination_port_range                = null
        destination_port_ranges               = ["10250", "10255"]
        source_address_prefix                 = "VirtualNetwork"
        source_address_prefixes               = null
        source_application_security_group_ids = null
      }
    },
    {
      # Overrides Azure's default AllowVnetInBound (priority 65000);
      # AllowAzureLoadBalancerInBound (65001) still admits health probes.
      "control-plane/deny-virtual-network-inbound" = {
        role                                  = "control-plane"
        name                                  = "deny-virtual-network-inbound"
        description                           = "Anything else from the virtual network."
        priority                              = 4096
        access                                = "Deny"
        protocol                              = "*"
        destination_port_range                = "*"
        destination_port_ranges               = null
        source_address_prefix                 = "VirtualNetwork"
        source_address_prefixes               = null
        source_application_security_group_ids = null
      }
    },
  )
}
