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

# Load-balancing rules of the API listeners: the endpoint port to the
# kube-apiserver port, and 9345 to 9345 with RKE2 (cluster.md
# "Control-plane provider requirements").
resource "azurerm_lb_rule" "api_rules" {
  for_each = local.api_load_balancer_ports

  backend_address_pool_ids = [one(azurerm_lb_backend_address_pool.api_backend_pool[*].id)]
  backend_port             = each.value.port
  # A public frontend must not become the control plane's outbound address:
  # egress is the brought NAT gateway or firewall.
  disable_outbound_snat          = var.api_load_balancer_public
  floating_ip_enabled            = false
  frontend_ip_configuration_name = local.api_frontend_name
  frontend_port                  = each.value.frontend_port
  idle_timeout_in_minutes        = 4
  load_distribution              = "Default"
  loadbalancer_id                = one(azurerm_lb.api_load_balancer[*].id)
  name                           = each.key
  probe_id                       = azurerm_lb_probe.api_probes[each.key].id
  protocol                       = "Tcp"
  # Idle connections get a reset instead of silently vanishing, so clients
  # reconnect at once.
  tcp_reset_enabled = true
}
