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

# The API server endpoint: a Standard load balancer the module owns, or the
# endpoint the user supplied (cluster.md "control_plane_endpoint (input)";
# DESIGN.md decision 2).
locals {
  user_endpoint = var.control_plane_endpoint != null
  rke2          = var.distribution == "rke2"

  # What the endpoint's address and port follow (api_endpoint_guard.tf).
  api_endpoint_identity = {
    port      = local.api_port
    public    = var.api_load_balancer_public
    subnet_id = var.api_load_balancer_public ? null : lower(local.node_subnets["control-plane"].id)
  }

  # The endpoint (frontend) port is cluster_network.api_server_port ?? 6443
  # (cluster.md "cluster_network (input)"). The kube-apiserver backend port
  # equals it with kubeadm, whose bindPort the templates keep equal, and is
  # always 6443 with RKE2, which reads neither field
  # (control-planes/rke2.md; CONVENTIONS.md section 12).
  api_port             = try(coalesce(var.cluster_network.api_server_port, 6443), 6443)
  api_backend_port     = local.rke2 ? 6443 : local.api_port
  rke2_supervisor_port = 9345

  # Listeners of the API load balancer. kubeadm's API server answers
  # /readyz anonymously, so its probe sees readiness, not just a listening
  # socket; RKE2 may disable anonymous auth, and its supervisor answers 403,
  # so both use TCP there (control-planes/checklist.md "Health checks").
  api_load_balancer_ports = {
    for k, v in merge(
      {
        "api-server" = {
          frontend_port      = local.api_port
          port               = local.api_backend_port
          probe_protocol     = local.rke2 ? "Tcp" : "Https"
          probe_request_path = local.rke2 ? null : "/readyz"
        }
      },
      {
        for k, v in {
          "rke2-supervisor" = {
            frontend_port      = local.rke2_supervisor_port
            port               = local.rke2_supervisor_port
            probe_protocol     = "Tcp"
            probe_request_path = null
          }
        } : k => v if local.rke2
      },
    ) : k => v if !local.user_endpoint
  }

  # The frontend address: the public IP, or the internal frontend's private
  # address. one() is null while the resource does not exist.
  api_frontend_ip = local.user_endpoint ? null : (
    var.api_load_balancer_public ? one(azurerm_public_ip.api_public_ip[*].ip_address) : one(azurerm_lb.api_load_balancer[*].private_ip_address)
  )
  api_endpoint = local.user_endpoint ? var.control_plane_endpoint : (
    local.api_frontend_ip == null || local.api_frontend_ip == "" ? null : { host = local.api_frontend_ip, port = local.api_port }
  )
}
