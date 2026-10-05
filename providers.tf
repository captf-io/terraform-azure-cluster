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

# The azurerm provider for the cluster role. Credentials and the
# subscription come from the identity Secret's ARM_* environment variables
# (https://captf.io/docs/user-guide/identities.html; README "Identity Secret").
provider "azurerm" {
  # Registration needs subscription-wide write access the job identity does
  # not need otherwise; the README lists the resource providers to register
  # beforehand.
  resource_provider_registrations = "none"

  features {
    resource_group {
      # Destroy fails loudly when the cloud controller manager left load
      # balancers, public IPs or disks behind, instead of deleting them with
      # their data (DESIGN.md decision 1).
      prevent_deletion_if_contains_resources = true
    }
  }
}
