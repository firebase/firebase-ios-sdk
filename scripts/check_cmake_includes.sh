#!/bin/bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script is a thin wrapper that just executes check_cmake_includes.py
# with arguments appropriate for Firebase. This script is executed directly by
# GitHub actions. This script is expected to be executed from the root directory
# of this Git repository.

# Enable unofficial "strict mode"
# See http://redsymbol.net/articles/unofficial-bash-strict-mode
set -euo pipefail

readonly args=(
  'scripts/check_cmake_includes.py'
  '--cmake_configure_file=Firestore/core/src/util/config_detected.h.in'
  '--required_include=Firestore/core/src/util/config.h'
  '--filename_include=*.cc'
  '--filename_include=*.mm'
  '--filename_include=*.h'
  '--quiet'
  'Firestore'
)

exec "${args[@]}"
