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

# The exports object handed to machine and pool modules as
# captf_cluster_outputs (CONVENTIONS.md section 12; README "Exports").
# Adding a key keeps the schema; renaming or removing one bumps it to v2.
# try(): a resource deleted out of band leaves the state on refresh, and the
# refresh must not fail on it (CONVENTIONS.md section 9).
locals {
  exports_schema = "captf.io/azure-cluster/v1"

  # The region, from the resource group once the network is gone.
  exports_location = try(coalesce(local.location, one(azurerm_resource_group.cluster_resource_group[*].location)), null)

  # The admin user every node gets; SSH stays closed by the security rules.
  admin_username = "captf"

  # cloud-provider-azure configuration (/etc/kubernetes/azure.json) without
  # userAssignedIdentityID, which machines and pools add for their role.
  # Managed identities only: nothing in it is secret
  # (https://cloud-provider-azure.sigs.k8s.io/install/configs/).
  cloud_provider_config = {
    cloud                        = "AzurePublicCloud"
    tenantId                     = data.azurerm_client_config.runner_client.tenant_id
    subscriptionId               = lower(data.azurerm_client_config.runner_client.subscription_id)
    resourceGroup                = try(lower(azurerm_resource_group.cluster_resource_group[0].name), null)
    location                     = local.exports_location
    vmType                       = "vmss"
    vnetName                     = local.node_subnets.worker.virtual_network_name
    vnetResourceGroup            = local.node_subnets.worker.virtual_network_group_name
    subnetName                   = local.node_subnets.worker.name
    securityGroupName            = try(azurerm_network_security_group.node_security_groups["worker"].name, null)
    securityGroupResourceGroup   = one(azurerm_resource_group.cluster_resource_group[*].name)
    loadBalancerSku              = "Standard"
    maximumLoadBalancerRuleCount = 250
    useManagedIdentityExtension  = true
    useInstanceMetadata          = true
  }

  exports = {
    schema              = local.exports_schema
    tenant_id           = data.azurerm_client_config.runner_client.tenant_id
    subscription_id     = lower(data.azurerm_client_config.runner_client.subscription_id)
    region              = local.exports_location
    resource_group_name = try(lower(azurerm_resource_group.cluster_resource_group[0].name), null)
    resource_group_id   = one(azurerm_resource_group.cluster_resource_group[*].id)
    # Zone names; the attributes stay empty.
    failure_domains = { for z in local.zones : z => {} }
    virtual_network = {
      id                  = try(local.node_virtual_networks[0].id, null)
      name                = local.node_subnets["control-plane"].virtual_network_name
      resource_group_name = local.node_subnets["control-plane"].virtual_network_group_name
    }
    subnet_id            = local.node_subnets["control-plane"].id
    subnet_name          = local.node_subnets["control-plane"].name
    worker_subnet_id     = local.node_subnets.worker.id
    worker_subnet_name   = local.node_subnets.worker.name
    admin_username       = local.admin_username
    admin_ssh_public_key = var.admin_ssh_public_key
    control_plane = {
      identity_id                   = try(local.node_identities["control-plane"].id, null)
      identity_client_id            = try(local.node_identities["control-plane"].client_id, null)
      network_security_group_id     = try(azurerm_network_security_group.node_security_groups["control-plane"].id, null)
      network_security_group_name   = try(azurerm_network_security_group.node_security_groups["control-plane"].name, null)
      application_security_group_id = try(azurerm_application_security_group.node_application_security_groups["control-plane"].id, null)
      availability_set_id           = one(azurerm_availability_set.control_plane_availability_set[*].id)
    }
    worker = {
      identity_id                   = try(local.node_identities.worker.id, null)
      identity_client_id            = try(local.node_identities.worker.client_id, null)
      network_security_group_id     = try(azurerm_network_security_group.node_security_groups["worker"].id, null)
      network_security_group_name   = try(azurerm_network_security_group.node_security_groups["worker"].name, null)
      application_security_group_id = try(azurerm_application_security_group.node_application_security_groups["worker"].id, null)
    }
    # null when the endpoint is the user's: there is nothing to register with.
    api = local.user_endpoint ? null : {
      host               = try(local.api_endpoint.host, null)
      port               = local.api_port
      backend_port       = local.api_backend_port
      frontend_ip        = local.api_frontend_ip
      backend_pool_id    = one(azurerm_lb_backend_address_pool.api_backend_pool[*].id)
      hairpin_workaround = var.api_server_hairpin_workaround
      supervisor_port    = local.rke2 ? local.rke2_supervisor_port : null
    }
    cloud_provider_config = local.cloud_provider_config
  }
}
