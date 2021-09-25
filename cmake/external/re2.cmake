# Copyright 2021 Google LLC
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

include(ExternalProject)

if(TARGET RE2)
    return()
endif()

# Based on https://github.com/grpc/grpc/blob/v1.40.0/bazel/grpc_deps.bzl
# master@{2020-05-27}
set(commit aecba11114cf1fac5497aeb844b6966106de3eb6)

ExternalProject_Add(
  re2

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME re2-${commit}.tar.gz
  URL https://github.com/google/re2/archive/${commit}.tar.gz
  URL_HASH SHA256=9f385e146410a8150b6f4cb1a57eab7ec806ced48d427554b1e754877ff26c3e

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/re2

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
