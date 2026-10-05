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

# Health probes of the API listeners, every 5 seconds so a new control-plane
# node joins the rotation quickly (locals_api_server.tf).
resource "azurerm_lb_probe" "api_probes" {
  for_each = local.api_load_balancer_ports

  interval_in_seconds = 5
  loadbalancer_id     = one(azurerm_lb.api_load_balancer[*].id)
  name                = each.key
  port                = each.value.port
  protocol            = each.value.probe_protocol
  request_path        = each.value.probe_request_path
}
