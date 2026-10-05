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

# Records what fixes the API endpoint when the load balancer is created and
# fails any later plan that would move it. azurerm 5.7.0 changes a
# frontend's public IP, private address and subnet and the rule ports in
# place, so CAPTF's destructive-plan guard (deletes and replacements only)
# would let such a move through, while CAPI never updates the Cluster's
# endpoint after the first copy (cluster.md "control_plane_endpoint (output)").
resource "terraform_data" "api_endpoint_guard" {
  count = local.user_endpoint ? 0 : 1

  # The private address the frontend actually got, not the variable: a
  # dynamic address made static at the same value does not move anything.
  input = merge(local.api_endpoint_identity, {
    private_ip_address = var.api_load_balancer_public ? null : azurerm_lb.api_load_balancer[0].private_ip_address
  })

  lifecycle {
    # The recorded value never follows the configuration. No prevent_destroy
    # instead: it would block deleting the cluster too.
    ignore_changes = [input]

    postcondition {
      condition = (
        self.input.public == local.api_endpoint_identity.public
        && self.input.port == local.api_endpoint_identity.port
        && self.input.subnet_id == local.api_endpoint_identity.subnet_id
        && (var.api_load_balancer_public || var.api_load_balancer_private_ip == null || var.api_load_balancer_private_ip == self.input.private_ip_address)
      )
      error_message = "The API endpoint of this cluster is fixed once its load balancer exists: api_load_balancer_public, api_load_balancer_private_ip, cluster_network.api_server_port and the control-plane subnet_id cannot change (recorded ${jsonencode(self.input)}, requested ${jsonencode(merge(local.api_endpoint_identity, { private_ip_address = var.api_load_balancer_private_ip }))}). Revert the change, or create a new cluster."
    }
  }
}
