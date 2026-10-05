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

# Tags on every taggable resource (CONVENTIONS.md section 7). Azure tag
# names cannot contain < > % & \ ? /, so captf.io/<key> becomes
# captf.io_<key> (https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources#limitations).
locals {
  # Values longer than Azure's 256 characters keep 247, then "-" and 8 hex
  # characters of their sha256, so they stay unique.
  captf_tags = {
    for k, v in var.captf_tags : replace(k, "/", "_") => length(v) <= 256 ? v : "${substr(v, 0, 247)}-${substr(sha256(v), 0, 8)}"
  }
  # cloud-provider-azure needs no tags on the resources this module creates.
  cloud_tags = {}
  tags       = merge(var.additional_tags, local.cloud_tags, local.captf_tags)
}
