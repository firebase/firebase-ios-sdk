#!/bin/bash

# Copyright 2024 Google LLC
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

# This script replaces mock response files for Vertex AI unit tests with a fresh
# clone of the shared repository of Vertex AI test data.

cd "$(dirname "$0")/../FirebaseVertexAI/Tests/Unit" || exit
rm -rf vertexai-sdk-test-data || exit
git clone --depth 1 https://github.com/FirebaseExtended/vertexai-sdk-test-data.git
