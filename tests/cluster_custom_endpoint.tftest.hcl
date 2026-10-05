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

# Unit tests of an internal endpoint with a custom port and a static
# address, set at creation, in a file of its own: a test file has its own
# state, and the endpoint guard fixes both once the load balancer exists.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      client_id       = "0a8b3c1d-6e2f-4a7b-9c8d-1e2f3a4b5c6d"
      object_id       = "1b9c4d2e-7f3a-4b8c-8d9e-2f3a4b5c6d7e"
      subscription_id = "6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11"
      tenant_id       = "72f988bf-86f1-41af-91ab-2d7cd011db47"
    }
  }

  mock_data "azurerm_virtual_network" {
    defaults = {
      id       = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub"
      location = "westeurope"
      subnets  = ["nodes", "workers", "AzureBastionSubnet"]
    }
  }

  # The subscription-wide listings find the brought network. Runs with
  # existing identities override them to find those instead.
  mock_data "azurerm_resources" {
    defaults = {
      resources = [{
        id                  = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub"
        location            = "westeurope"
        name                = "hub"
        resource_group_name = "network"
        tags                = {}
        type                = "Microsoft.Network/virtualNetworks"
      }]
    }
  }

  mock_data "azurerm_location" {
    defaults = {
      zone_mappings = [
        { logical_zone = "1", physical_zone = "westeurope-az1" },
        { logical_zone = "2", physical_zone = "westeurope-az3" },
        { logical_zone = "3", physical_zone = "westeurope-az2" },
      ]
    }
  }

  mock_data "azurerm_user_assigned_identity" {
    defaults = {
      client_id    = "3c0d5e3f-8a4b-4c9d-9e0f-3a4b5c6d7e8f"
      principal_id = "4d1e6f4a-9b5c-4d0e-8f1a-4b5c6d7e8f9a"
    }
  }

  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c"
    }
  }

  # IDs other resources take as arguments are pinned in ARM format: the
  # provider validates them even when mocked. Network security groups and
  # identities keep generated IDs, so reapply_is_stable can see a
  # replacement.
  mock_resource "azurerm_lb" {
    defaults = {
      id                 = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api"
      private_ip_address = "10.0.0.100"
    }
  }

  mock_resource "azurerm_lb_backend_address_pool" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api/backendAddressPools/control-plane"
    }
  }

  mock_resource "azurerm_lb_probe" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api/probes/api-server"
    }
  }

  mock_resource "azurerm_public_ip" {
    defaults = {
      id         = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/publicIPAddresses/captf-team-a-demo-2a8d5f7c-api"
      ip_address = "203.0.113.10"
    }
  }

  mock_resource "azurerm_application_security_group" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/applicationSecurityGroups/captf-team-a-demo-2a8d5f7c-nodes-asg"
    }
  }

  mock_resource "azurerm_availability_set" {
    defaults = {
      id = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Compute/availabilitySets/captf-team-a-demo-2a8d5f7c-control-plane"
    }
  }

  mock_resource "azurerm_user_assigned_identity" {
    defaults = {
      client_id    = "5e2f7a5b-0c6d-4e1f-9a2b-5c6d7e8f9a0b"
      principal_id = "6f3a8b6c-1d7e-4f2a-8b3c-6d7e8f9a0b1c"
    }
  }
}

variables {
  captf_contract            = "v1alpha1"
  captf_cluster             = { name = "demo", namespace = "team-a" }
  captf_object              = { kind = "TerraformCluster", name = "demo", namespace = "team-a" }
  captf_tags                = { "captf.io/cluster" = "demo", "captf.io/namespace" = "team-a", "captf.io/kind" = "TerraformCluster", "captf.io/name" = "demo", "captf.io/managed-by" = "captf", "captf.io/template" = "" }
  control_plane_endpoint    = null
  kubernetes_version        = "v1.34.1"
  control_plane_initialized = false
  cluster_network           = { pods = ["192.168.0.0/16"], services = ["10.128.0.0/12"], service_domain = "cluster.local", api_server_port = 6443 }

  admin_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK0wmN/Cr3JXqmLW7u+g9pTh+wyqDHpSQEIQczXkVx9q captf@example"
  subnet_id            = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/network/providers/Microsoft.Network/virtualNetworks/hub/subnets/nodes"
}

run "api_server_port_override" {
  variables {
    cluster_network              = { pods = [], services = [], service_domain = null, api_server_port = 8443 }
    api_load_balancer_private_ip = "10.0.0.10"
  }

  override_resource {
    target = azurerm_lb.api_load_balancer
    values = {
      id                 = "/subscriptions/6f1c1e1a-3b7e-4a3c-9a39-5d2f1c0b8e11/resourceGroups/captf-team-a-demo-2a8d5f7c/providers/Microsoft.Network/loadBalancers/captf-team-a-demo-2a8d5f7c-api"
      private_ip_address = "10.0.0.10"
    }
  }

  assert {
    condition     = output.control_plane_endpoint == { host = "10.0.0.10", port = 8443 } && azurerm_lb_rule.api_rules["api-server"].frontend_port == 8443 && azurerm_lb_rule.api_rules["api-server"].backend_port == 8443 && azurerm_lb_probe.api_probes["api-server"].port == 8443
    error_message = "cluster_network.api_server_port sets the endpoint, rule and probe port."
  }
  assert {
    condition     = azurerm_network_security_rule.node_security_rules["control-plane/allow-api-server-from-virtual-network"].destination_port_ranges == toset(["8443"])
    error_message = "The security rule follows the API server port."
  }
  assert {
    condition     = azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].private_ip_address == "10.0.0.10" && azurerm_lb.api_load_balancer[0].frontend_ip_configuration[0].private_ip_address_allocation == "Static"
    error_message = "api_load_balancer_private_ip makes the internal frontend static."
  }
  assert {
    condition     = jsonencode(terraform_data.api_endpoint_guard[0].input) == jsonencode({ port = 8443, private_ip_address = "10.0.0.10", public = false, subnet_id = lower(var.subnet_id) })
    error_message = "The endpoint guard records the port and the static address."
  }
}

run "rejects_api_server_port_change_back" {
  command = plan

  # Back to the default port 6443, keeping the address.
  variables {
    api_load_balancer_private_ip = "10.0.0.10"
  }

  expect_failures = [terraform_data.api_endpoint_guard]
}

# RKE2 serves the kube-apiserver on 6443 whatever the endpoint port.
run "rke2_backend_port_is_6443" {
  command = plan

  variables {
    cluster_network              = { pods = [], services = [], service_domain = null, api_server_port = 8443 }
    api_load_balancer_private_ip = "10.0.0.10"
    distribution                 = "rke2"
  }

  assert {
    condition     = azurerm_lb_rule.api_rules["api-server"].frontend_port == 8443 && azurerm_lb_rule.api_rules["api-server"].backend_port == 6443 && azurerm_lb_probe.api_probes["api-server"].port == 6443
    error_message = "With RKE2 the endpoint port maps to the kube-apiserver's 6443."
  }
  assert {
    condition     = azurerm_network_security_rule.node_security_rules["control-plane/allow-api-server-from-virtual-network"].destination_port_ranges == toset(["6443", "9345"])
    error_message = "The security rule opens the backend ports."
  }
}
