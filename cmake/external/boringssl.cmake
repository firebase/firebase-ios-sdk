# Copyright 2018 Google
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

if(TARGET boringssl)
  return()
endif()

# This ExternalProject unpacks itself inside the gRPC source tree. CMake clears
# the SOURCE_DIR when unpacking so this must come after grpc despite the fact
# that grpc logically depends upon this.

# grpc v1.8.3 includes boringssl at be2ee342d3781ddb954f91f8a7e660c6f59e87e5
# (2017-02-03). Unfortunately, that boringssl includes a conflicting gtest
# target that makes it unsuitable for use via add_subdirectory.
#
# grpc v1.24.3 includes boringssl at b29b21a81b32ec273f118f589f46d56ad3332420
# (2018-05-22). While this no longer has the conflicting gtest target, it's
# still woefully out of date.
set(commit 9638f8fba961a593c064e3036bb580bdace29e8f)  # master@{2019-10-01}

ExternalProject_Add(
  boringssl
  DEPENDS
    grpc-download

  DOWNLOAD_DIR ${FIREBASE_DOWNLOAD_DIR}
  DOWNLOAD_NAME boringssl-${commit}.tar.gz
  URL https://github.com/google/boringssl/archive/${commit}.tar.gz
  URL_HASH SHA256=cfd843fda9fdf9ea92b1ae5f5d379ec7d7cb09d5c7d41197ee935a0e30aecb23

  PREFIX ${PROJECT_BINARY_DIR}
  SOURCE_DIR ${PROJECT_BINARY_DIR}/src/grpc/third_party/boringssl

  CONFIGURE_COMMAND ""
  BUILD_COMMAND     ""
  INSTALL_COMMAND   ""
  TEST_COMMAND      ""
)
